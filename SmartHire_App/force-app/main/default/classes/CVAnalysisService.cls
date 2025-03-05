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
        // Sprawdzamy uprawnienia przed SOQL
        if (!Schema.SObjectType.ContentVersion.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access ContentVersion');
        }
        
        // Sprawdzamy dostęp do pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.ContentVersion.fields.getMap();
        for (String field : new List<String>{'VersionData', 'Title', 'FileType', 'ContentDocumentId', 'IsLatest'}) {
            if (!fieldMap.get(field).getDescribe().isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access ContentVersion.' + field);
            }
        }
            
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
        // Sprawdzamy uprawnienia przed SOQL
        if (!Schema.SObjectType.Position__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Position__c');
        }
        
        // Sprawdzamy dostęp do pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Position__c.fields.getMap();
        for (String field : new List<String>{'Description__c', 'Required_Skills__c'}) {
            if (!fieldMap.get(field).getDescribe().isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Position__c.' + field);
            }
        }
            
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
        String skillsStr = String.join(requiredSkills, ',');
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
        if (!Schema.SObjectType.ContentVersion.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access ContentVersion');
        }
        
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.ContentVersion.fields.getMap();
        for (String field : new List<String>{'VersionData', 'Title', 'FileType', 'ContentDocumentId'}) {
            if (!fieldMap.get(field).getDescribe().isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access ContentVersion.' + field);
            }
        }
    }
    
    /**
     * Walidacja uprawnień do Position__c
     */
    private static void validatePositionAccess() {
        if (!Schema.SObjectType.Position__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Position__c');
        }
        
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Position__c.fields.getMap();
        for (String field : new List<String>{'Description__c', 'Required_Skills__c'}) {
            if (!fieldMap.get(field).getDescribe().isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Position__c.' + field);
            }
        }
    }

    /**
     * Creates a task for the recruiter based on CV analysis results
     * @param applicationId Application Id
     * @param analysisResults Analysis results from OpenAI
     */
    public static void createRecruiterTaskFromAnalysis(Id applicationId, Map<String, Object> analysisResults) {
        try {
            // Validate permissions for Application__c
            if (!Schema.SObjectType.Application__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Application__c');
            }
            
            // Validate permissions for fields
            Map<String, Schema.SObjectField> appFieldMap = Schema.SObjectType.Application__c.fields.getMap();
            for (String field : new List<String>{'Candidate__c', 'Position__c', 'Assigned_Reviewer__c'}) {
                if (!appFieldMap.get(field).getDescribe().isAccessible()) {
                    throw new AuraHandledException('Insufficient permissions to access Application__c.' + field);
                }
            }
            
            // Validate permissions for Task
            if (!Schema.SObjectType.Task.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Task');
            }
            
            Map<String, Schema.SObjectField> taskFieldMap = Schema.SObjectType.Task.fields.getMap();
            for (String field : new List<String>{'Subject', 'Description', 'WhatId', 'OwnerId', 'Status', 'Priority', 'ActivityDate'}) {
                if (!taskFieldMap.get(field).getDescribe().isCreateable()) {
                    throw new AuraHandledException('Insufficient permissions to create Task.' + field);
                }
            }
            
            // Query application details
            Application__c app = [
                SELECT Id, Candidate__r.Name, Position__r.Name, Assigned_Reviewer__c
                FROM Application__c 
                WHERE Id = :applicationId
                LIMIT 1
            ];
            
            // Extract insights from AI analysis results
            String insights = '';
            if (analysisResults.containsKey('skills_match')) {
                insights += 'Matches ' + analysisResults.get('skills_match') + '% of required skills. ';
            }
            if (analysisResults.containsKey('experience_years')) {
                insights += 'Estimated experience: ' + analysisResults.get('experience_years') + ' years. ';
            }
            if (analysisResults.containsKey('recommendations')) {
                insights += '\n\nRecommendations: ' + analysisResults.get('recommendations');
            }
            
            // Create task for the recruiter
            Task t = new Task(
                Subject = 'Review CV Analysis: ' + app.Candidate__r.Name + ' for ' + app.Position__r.Name,
                Description = 'AI Analysis Results:\n\n' + insights,
                WhatId = applicationId,
                OwnerId = app.Assigned_Reviewer__c != null ? app.Assigned_Reviewer__c : UserInfo.getUserId(),
                Status = 'Not Started',
                Priority = 'High',
                ActivityDate = Date.today().addDays(2)
            );
            
            insert t;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating recruiter task: ' + e.getMessage());
        }
    }
}
