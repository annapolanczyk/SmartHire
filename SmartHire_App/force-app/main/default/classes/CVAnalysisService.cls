/**
 * Moduł analizy CV z wykorzystaniem AI i przetwarzania języka naturalnego (NLP)
 * 
 * Funkcjonalności:
 * 1. Ekstrakcja strukturyzowanych danych z CV (doświadczenie, umiejętności, wykształcenie)
 * 2. Ocena dopasowania do stanowiska na podstawie wymagań
 * 3. Wykrywanie kluczowych słów i technologii
 * 4. Rekomendacje dla rekruterów
 */
public with sharing class CVAnalysisService {
    
    /**
     * Analizuje CV kandydata i zwraca strukturyzowane dane
     * @param contentDocumentId ID dokumentu CV w ContentDocument
     * @param positionId Opcjonalne ID stanowiska dla dopasowania
     * @param bypassCache True, aby pominąć bufor i wykonać nową analizę
     * @return Mapa zawierająca wyniki analizy
     */
    public static Map<String, Object> analyzeCandidateResume(Id contentDocumentId, Id positionId, Boolean bypassCache) {
        try {
            // Budowanie klucza cache
            String cacheKey = 'CV_Analysis_' + contentDocumentId;
            if (positionId != null) {
                cacheKey += '_' + positionId;
            }
            
            // Buforowanie wyników analizy
            Cache.OrgPartition orgPart = Cache.Org.getPartition('local.SmartHireCache');
            if (!bypassCache) {
                Map<String, Object> cachedResults = (Map<String, Object>) orgPart.get(cacheKey);
                if (cachedResults != null) {
                    return cachedResults;
                }
            }
    
            // Walidacja uprawnień CRUD i FLS przed wykonaniem zapytań SOQL
            validateContentVersionAccess();
            
            ContentVersion cv = getContentVersion(contentDocumentId);
            if (cv == null) {
                throw new AuraHandledException('CV document not found');
            }
    
            // Konwersja dokumentu na tekst
            String resumeText = convertToText(cv);
            String jobDescription = '';
            List<String> requiredSkills = new List<String>();
    
            // Pobranie danych stanowiska, jeśli podano ID
            if (positionId != null) {
                validatePositionAccess();
                
                Position__c position = getPosition(positionId);
                if (position != null) {
                    jobDescription = position.Description__c;
                    if (String.isNotBlank(position.Required_Skills__c)) {
                        requiredSkills = parseSkills(position.Required_Skills__c);
                    }
                }
            }
    
            // Walidacja limitów przed wywołaniem API
            checkLimits(resumeText);
    
            // Analiza AI przy użyciu OpenAI (wywołanie callout, Named Credential)
            Map<String, Object> analysisResults = analyzeResumeWithOpenAI(resumeText, jobDescription, requiredSkills);
    
            // Przetwarzanie wyników analizy
            Map<String, Object> processedResults = processAnalysisResults(analysisResults);
    
            // Buforowanie wyników na 24h (86400 sekund)
            orgPart.put(cacheKey, processedResults, 86400);
            return processedResults;
    
        } catch (Exception e) {
            throw new AuraHandledException('Error analyzing CV: ' + e.getMessage());
        }
    }
    
    /**
     * Pobiera rekord ContentVersion na podstawie ContentDocumentId
     */
    private static ContentVersion getContentVersion(Id contentDocumentId) {
        List<ContentVersion> cvList = [
            SELECT VersionData, Title, FileType 
            FROM ContentVersion 
            WHERE ContentDocumentId = :contentDocumentId 
              AND IsLatest = true 
            LIMIT 1
        ];
        if (!cvList.isEmpty()) {
            return cvList[0];
        }
        return null;
    }
    
    /**
     * Pobiera rekord Position__c na podstawie positionId
     */
    private static Position__c getPosition(Id positionId) {
        List<Position__c> positionList = [
            SELECT Description__c, Required_Skills__c 
            FROM Position__c 
            WHERE Id = :positionId 
            LIMIT 1
        ];
        if (!positionList.isEmpty()) {
            return positionList[0];
        }
        return null;
    }
    
    /**
     * Rozdziela i przycina umiejętności na podstawie tekstu
     */
    private static List<String> parseSkills(String skillsString) {
        List<String> skills = skillsString.split(',');
        for (Integer i = 0; i < skills.size(); i++) {
            skills[i] = skills[i].trim();
        }
        return skills;
    }
    
    /**
     * Konwertuje plik CV na tekst w zależności od formatu
     */
    private static String convertToText(ContentVersion cv) {
        if (cv.FileType.equalsIgnoreCase('PDF')) {
            return parsePDF(cv.VersionData);
        } else if (cv.FileType.equalsIgnoreCase('DOCX') || cv.FileType.equalsIgnoreCase('DOC')) {
            return parseWord(cv.VersionData);
        } else if (cv.FileType.equalsIgnoreCase('TXT')) {
            return cv.VersionData.toString();
        }
        throw new AuraHandledException('Unsupported file format: ' + cv.FileType);
    }
    
    /**
     * Parsowanie pliku PDF przy użyciu callout (korzysta z Named Credential)
     */
    private static String parsePDF(Blob pdfData) {
        checkCalloutPermission();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:PDF_Parser_Service');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/pdf');
        req.setBodyAsBlob(pdfData);
    
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 200) {
            return res.getBody();
        }
        throw new AuraHandledException('Error parsing PDF: ' + res.getStatusCode());
    }
    
    /**
     * Parsowanie pliku Word przy użyciu callout (korzysta z Named Credential)
     */
    private static String parseWord(Blob wordData) {
        checkCalloutPermission();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:DOCX_Parser_Service');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
        req.setBodyAsBlob(wordData);
    
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 200) {
            return res.getBody();
        }
        throw new AuraHandledException('Error parsing Word document: ' + res.getStatusCode());
    }
    
    /**
     * Analiza CV przy użyciu OpenAI – wykorzystuje callout (użycie Named Credential)
     */
    private static Map<String, Object> analyzeResumeWithOpenAI(String resumeText, String jobDescription, List<String> requiredSkills) {
        checkCalloutPermission();
        String systemPrompt = 'Jesteś ekspertem HR, analizujesz CV i wyodrębniasz dane w JSON.';
        String skillsStr = requiredSkills.join(',');
        Map<String, Object> request = new Map<String, Object>{
            'prompt' => systemPrompt + '\nCV: ' + resumeText + '\nOpis: ' + jobDescription + '\nUmiejętności: ' + skillsStr,
            'max_tokens' => 2000
        };
    
        // Placeholder: tutaj należy wykonać callout do API OpenAI z użyciem odpowiedniego Named Credential
        return new Map<String, Object>{ 'skills' => requiredSkills, 'summary' => 'Analiza AI' };
    }
    
    /**
     * Przetwarza wyniki analizy (opcjonalna logika przetwarzania)
     */
    private static Map<String, Object> processAnalysisResults(Map<String, Object> analysisResults) {
        return analysisResults;
    }
    
    /**
     * Walidacja długości tekstu CV
     */
    private static void checkLimits(String resumeText) {
        Integer maxLength = 100000;
        if (resumeText.length() > maxLength) {
            throw new AuraHandledException('CV przekracza dozwoloną długość.');
        }
    }
    
    /**
     * Sprawdzenie uprawnień do wykonywania calloutów.
     * Zastąp logikę własną, np. używając FeatureManagement lub innych mechanizmów kontroli.
     */
    private static void checkCalloutPermission() {
        Boolean calloutAllowed = true;
        if (!calloutAllowed) {
            throw new SecurityException('Insufficient permissions to perform callouts');
        }
    }
    
    /**
     * Walidacja uprawnień do ContentVersion
     */
    private static void validateContentVersionAccess() {
        if (!Schema.sObjectType.ContentVersion.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access ContentVersion');
        }
        
        Map<String, Schema.SObjectField> fieldMap = Schema.sObjectType.ContentVersion.fields.getMap();
        if (!fieldMap.get('VersionData').getDescribe().isAccessible() ||
            !fieldMap.get('Title').getDescribe().isAccessible() ||
            !fieldMap.get('FileType').getDescribe().isAccessible() ||
            !fieldMap.get('ContentDocumentId').getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access required ContentVersion fields');
        }
    }
    
    /**
     * Walidacja uprawnień do Position__c
     */
    private static void validatePositionAccess() {
        if (!Schema.sObjectType.Position__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Position__c');
        }
        
        Map<String, Schema.SObjectField> fieldMap = Schema.sObjectType.Position__c.fields.getMap();
        if (!fieldMap.get('Description__c').getDescribe().isAccessible() ||
            !fieldMap.get('Required_Skills__c').getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access required Position__c fields');
        }
    }
}
