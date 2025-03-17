/**
 * @description Klasa pomocnicza do analizy CV kandydatów. Zawiera metody do ekstrakcji tekstu z różnych formatów dokumentów
 * oraz analizy zawartości CV przy użyciu AI.
 * 
 * Uwaga: Klasa ma wysoką złożoność cyklomatyczną i poznawczą ze względu na złożoność obsługi różnych formatów dokumentów
 * oraz integracji z zewnętrznymi API. Złożoność jest akceptowalna, ponieważ klasa jest dobrze zmodularyzowana
 * i każda metoda ma jasno określoną odpowiedzialność.
 * 
 * @author ChangeMeIn@UserSettingsUnder.SFDoc
 * @group 
 * @last modified on  : 03-17-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class CVAnalysisHelper {
    
    // Stałe dla poziomów logowania
    private static final LoggingLevel DEBUG_LEVEL = LoggingLevel.DEBUG;
    private static final LoggingLevel ERROR_LEVEL = LoggingLevel.ERROR;
    private static final LoggingLevel WARN_LEVEL = LoggingLevel.WARN;
    
    // Stałe dla typów plików
    private static final String PDF_TYPE = 'PDF';
    private static final String DOCX_TYPE = 'DOCX';
    private static final String DOC_TYPE = 'DOC';
    private static final String TXT_TYPE = 'TXT';
    
    // Stałe dla typów MIME
    private static final String PDF_MIME_TYPE = 'application/pdf';
    private static final String DOCX_MIME_TYPE = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    
    /**
     * @description Analizuje CV kandydata przy użyciu AI
     * @param cv Wersja zawartości dokumentu CV
     * @param positionId Id stanowiska
     * @return Wyniki analizy CV w formie mapy
     */
    public static Map<String, Object> analyzeResume(ContentVersion cv, Id positionId) {
        try {
            // Walidacja uprawnień do ContentVersion
            validateContentVersionAccess();
            
        // Konwersja CV na tekst
        String resumeText = extractTextFromCV(cv);
            
            // Pobierz dane stanowiska i utwórz kontekst analizy
            AnalysisContext context = createAnalysisContext(resumeText, positionId);
            
            // Przygotuj prompt dla OpenAI
            String systemPrompt = 'Jesteś ekspertem HR analizującym CV kandydatów, ze szczególną specjalizacją w technologiach Salesforce. '
                + 'Twoim zadaniem jest dokładna analiza CV i wyodrębnienie kluczowych informacji, ze szczególnym uwzględnieniem umiejętności technicznych '
                + 'związanych z platformą Salesforce, takich jak Apex, LWC, Visualforce, SOQL, Flow, integracje API, itp.';
            String prompt = buildPrompt(context);
            
            // Wywołaj OpenAI API
            String aiResponse = OpenAIService.callOpenAI(prompt, systemPrompt);
            
            // Parsuj odpowiedź JSON
            Map<String, Object> results = parseAIResponse(aiResponse);
            
            // Dodaj informacje o stanowisku
            if (positionId != null) {
                results.put('positionId', positionId);
                results.put('positionName', context.positionName);
            }
            
            return results;
        } catch (OpenAIService.OpenAIException e) {
            // Logowanie błędu OpenAI
            Logger.error('Error calling OpenAI API', e);
            
            // Rzuć standardowy wyjątek zamiast AuraHandledException
            throw new CVAnalysisException('Błąd podczas analizy CV przez AI: ' + e.getMessage() + 
                '. Sprawdź konfigurację API lub spróbuj ponownie później.');
        } catch (Exception e) {
            Logger.error('Error analyzing resume', e);
            throw new CVAnalysisException('Error analyzing resume: ' + e.getMessage());
        }
    }
    
    /**
     * @description Waliduje uprawnienia dostępu do obiektu ContentVersion
     * @throws Exception jeśli użytkownik nie ma wymaganych uprawnień
     */
    private static void validateContentVersionAccess() {
        // Walidacja uprawnień CRUD
        if (!Schema.SObjectType.ContentVersion.isAccessible()) {
            throw new CVAnalysisException('Brak uprawnień do odczytu obiektów ContentVersion');
        }
        
        // Walidacja uprawnień do pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.ContentVersion.fields.getMap();
        for (String field : new List<String>{'Id', 'VersionData', 'FileType'}) {
            if (!fieldMap.get(field).getDescribe().isAccessible()) {
                throw new CVAnalysisException('Brak uprawnień do odczytu pola ContentVersion.' + field);
            }
        }
    }
    
    /**
     * @description Tworzy kontekst analizy na podstawie tekstu CV i ID stanowiska
     * @param resumeText Tekst CV do analizy
     * @param positionId ID stanowiska
     * @return Kontekst analizy
     */
    private static AnalysisContext createAnalysisContext(String resumeText, Id positionId) {
        AnalysisContext context = new AnalysisContext();
        context.resumeText = resumeText;
        context.jobDescription = '';
        context.requiredSkills = new List<String>();
        context.positionName = '';
        
        // Pobierz dane stanowiska jeśli podano ID
        if (positionId != null) {
            Position__c position = getPosition(positionId);
            if (position != null) {
                context.jobDescription = String.isNotBlank(position.Job_Description__c) ? position.Job_Description__c : '';
                context.positionName = position.Name;
                context.requiredSkills = String.isNotBlank(position.Required_Skills__c) 
                    ? parseSkills(position.Required_Skills__c) 
                    : new List<String>();
            }
        }
        
        return context;
    }
    
    /**
     * @description Klasa pomocnicza przechowująca kontekst analizy CV
     */
    private class AnalysisContext {
        /**
         * @description Tekst CV do analizy
         */
        public String resumeText;
        
        /**
         * @description Opis stanowiska
         */
        public String jobDescription;
        
        /**
         * @description Lista wymaganych umiejętności
         */
        public List<String> requiredSkills;
        
        /**
         * @description Nazwa stanowiska
         */
        public String positionName;
        
        /**
         * @description Sprawdza, czy kontekst zawiera dane o stanowisku
         * @return True jeśli kontekst zawiera dane o stanowisku, false w przeciwnym razie
         */
        public Boolean hasPositionDetails() {
            return String.isNotBlank(jobDescription) && requiredSkills != null && !requiredSkills.isEmpty();
        }
    }
    
    /**
     * @description Buduje prompt dla API OpenAI
     * @param context Kontekst analizy zawierający dane CV i stanowiska
     * @return Prompt dla API OpenAI
     */
    private static String buildPrompt(AnalysisContext context) {
        String prompt = 'Conduct an advanced semantic analysis of the following resume. Act as an experienced recruiter specializing in Salesforce technologies. '
            + 'Identify in detail all skills, competencies, qualifications, and professional experience mentioned in the document.\n\n'
            + 'Pay special attention to:\n'
            + '1. Technical skills related to Salesforce (Apex, LWC, Visualforce, SOQL, Flow, etc.)\n'
            + '2. Programming and integration skills (REST/SOAP API, JavaScript, HTML/CSS, etc.)\n'
            + '3. Soft and interpersonal skills\n'
            + '4. Certificates and qualifications, especially related to Salesforce\n'
            + '5. Level of professional experience\n'
            + '6. Indirect skills that are not explicitly mentioned but can be inferred from context\n\n'
            + 'Extract the following information in JSON format:\n'
            + '1. personalData (name, surname, email, phone)\n'
            + '2. education (degree, field, university, graduation year)\n'
            + '3. workExperience (list of positions, companies, employment periods, responsibilities)\n'
            + '4. technicalSkills (list, pay special attention to Salesforce technologies)\n'
            + '5. languages (list with proficiency level)\n'
            + '6. certifications (list)\n\n';
        
        // Add position information if available
        if (context.hasPositionDetails()) {
            prompt += 'Additionally, evaluate the candidate\'s fit for the position "' + context.positionName + '" based on the description and required skills below. '
                + 'Provide a percentage match score (0-100%) and detailed justification, listing specific skills that match the requirements.\n\n'
                + 'Position description: ' + context.jobDescription + '\n\n'
                + 'Required skills: ' + String.join(context.requiredSkills, ', ') + '\n\n'
                + 'Include the following sections in your response:\n'
                + '1. "matchedSkills" (array of skills that match the required skills)\n'
                + '2. "additionalSkills" (array of skills that are not directly required but may be valuable)\n'
                + '3. "matchScore" (percentage match score from 0 to 100)\n'
                + '4. "matchJustification" (detailed explanation of the match score)\n'
                + '5. "recommendations" (suggestions for the recruiter)\n\n';
        }
        
        prompt += 'Resume text to analyze:\n\n' + context.resumeText;
        
        return prompt;
    }
    
    /**
     * @description Parsuje odpowiedź AI do formatu mapy
     * @param aiResponse Odpowiedź z API AI w formacie tekstowym
     * @return Sparsowana odpowiedź w formie mapy
     */
    private static Map<String, Object> parseAIResponse(String aiResponse) {
        try {
            // Logowanie oryginalnej odpowiedzi dla celów diagnostycznych
            System.debug(LoggingLevel.INFO, 'Oryginalna odpowiedź z OpenAI (pierwsze 200 znaków): ' + 
                (aiResponse != null && aiResponse.length() > 200 ? aiResponse.substring(0, 200) + '...' : aiResponse));
            
            // Czyszczenie odpowiedzi przed parsowaniem
            String cleanedResponse = cleanJsonResponse(aiResponse);
            
            // Próba bezpośredniego parsowania JSON
            try {
                Map<String, Object> parsedResponse = (Map<String, Object>) JSON.deserializeUntyped(cleanedResponse);
                System.debug(LoggingLevel.INFO, 'Pomyślnie sparsowano odpowiedź jako JSON');
                return parsedResponse;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error parsing cleaned AI response as JSON: ' + e.getMessage());
                
                // Jeśli odpowiedź nie jest czystym JSON, próbujemy wyodrębnić JSON z tekstu
                String jsonPattern = '\\{[\\s\\S]*\\}';
                Pattern p = Pattern.compile(jsonPattern);
                Matcher m = p.matcher(cleanedResponse);
                
                if (m.find()) {
                    String jsonStr = m.group(0);
                    try {
                        Map<String, Object> extractedJson = (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
                        System.debug(LoggingLevel.INFO, 'Pomyślnie wyodrębniono i sparsowano JSON z odpowiedzi');
                        return extractedJson;
                    } catch (Exception ex) {
                        System.debug(LoggingLevel.ERROR, 'Error parsing extracted JSON: ' + ex.getMessage());
                    }
                }
            }
            
            // Jeśli nie udało się sparsować JSON, próbujemy ręcznie wyodrębnić kluczowe informacje
            Map<String, Object> manuallyExtractedData = extractDataManually(aiResponse);
            if (!manuallyExtractedData.isEmpty()) {
                System.debug(LoggingLevel.INFO, 'Pomyślnie wyodrębniono dane ręcznie');
                return manuallyExtractedData;
            }
            
            // Jeśli wszystkie metody zawiodły, zwracamy podstawową strukturę z oryginalną odpowiedzią
            Map<String, Object> fallbackResponse = new Map<String, Object>{
                'rawResponse' => aiResponse,
                'education' => 'Nie udało się wyodrębnić danych z CV',
                'matchScore' => 0,
                'skills' => new List<String>(),
                'matchedSkills' => new List<String>(),
                'missingSkills' => new List<String>()
            };
            return fallbackResponse;
        } catch (Exception e) {
            Logger.error('Unexpected error in parseAIResponse', e);
            
            // Zwracamy podstawową strukturę w przypadku nieoczekiwanego błędu
            Map<String, Object> errorResponse = new Map<String, Object>{
                'error' => 'Wystąpił nieoczekiwany błąd podczas przetwarzania odpowiedzi: ' + e.getMessage(),
                'education' => 'Nie udało się wyodrębnić danych z CV',
                'matchScore' => 0,
                'skills' => new List<String>(),
                'matchedSkills' => new List<String>(),
                'missingSkills' => new List<String>()
            };
            return errorResponse;
        }
    }
    
    /**
     * @description Czyści odpowiedź JSON z nieprawidłowych znaków i formatowania
     * @param jsonResponse Odpowiedź JSON do wyczyszczenia
     * @return Wyczyszczona odpowiedź JSON
     */
    private static String cleanJsonResponse(String jsonResponse) {
        if (String.isBlank(jsonResponse)) {
            return '{}';
        }
        
        // Usuwanie znaczników kodu markdown
        String cleaned = jsonResponse.replaceAll('```json', '').replaceAll('```', '');
        
        // Usuwanie znaków specjalnych na początku i końcu
        cleaned = cleaned.trim();
        if (cleaned.startsWith('`')) {
            cleaned = cleaned.substring(1);
        }
        if (cleaned.endsWith('`')) {
            cleaned = cleaned.substring(0, cleaned.length() - 1);
        }
        
        // Upewniamy się, że odpowiedź zaczyna się od { i kończy na }
        if (!cleaned.startsWith('{')) {
            Integer startIdx = cleaned.indexOf('{');
            if (startIdx >= 0) {
                cleaned = cleaned.substring(startIdx);
            } else {
                return '{}';
            }
        }
        
        if (!cleaned.endsWith('}')) {
            Integer endIdx = cleaned.lastIndexOf('}');
            if (endIdx >= 0) {
                cleaned = cleaned.substring(0, endIdx + 1);
            } else {
                return '{}';
            }
        }
        
        return cleaned;
    }
    
    /**
     * @description Ręcznie wyodrębnia dane z odpowiedzi tekstowej, gdy parsowanie JSON zawodzi
     * @param response Odpowiedź tekstowa
     * @return Mapa z wyodrębnionymi danymi
     */
    private static Map<String, Object> extractDataManually(String response) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            // Próba wyodrębnienia matchedSkills
            List<String> matchedSkills = new List<String>();
            Pattern matchedPattern = Pattern.compile('"matchedSkills"\\s*:\\s*\\[([^\\]]+)\\]');
            Matcher matchedMatcher = matchedPattern.matcher(response);
            if (matchedMatcher.find()) {
                String matchedStr = matchedMatcher.group(1);
                for (String skill : matchedStr.split(',')) {
                    skill = skill.replaceAll('"', '').trim();
                    if (String.isNotBlank(skill)) {
                        matchedSkills.add(skill);
                    }
                }
                result.put('matchedSkills', matchedSkills);
            }
            
            // Próba wyodrębnienia missingSkills
            List<String> missingSkills = new List<String>();
            Pattern missingPattern = Pattern.compile('"missingSkills"\\s*:\\s*\\[([^\\]]+)\\]');
            Matcher missingMatcher = missingPattern.matcher(response);
            if (missingMatcher.find()) {
                String missingStr = missingMatcher.group(1);
                for (String skill : missingStr.split(',')) {
                    skill = skill.replaceAll('"', '').trim();
                    if (String.isNotBlank(skill)) {
                        missingSkills.add(skill);
                    }
                }
                result.put('missingSkills', missingSkills);
            }
            
            // Próba wyodrębnienia matchScore
            Pattern scorePattern = Pattern.compile('"matchScore"\\s*:\\s*(\\d+)');
            Matcher scoreMatcher = scorePattern.matcher(response);
            if (scoreMatcher.find()) {
                String scoreStr = scoreMatcher.group(1);
                try {
                    Integer score = Integer.valueOf(scoreStr);
                    result.put('matchScore', score);
                } catch (Exception e) {
                    result.put('matchScore', 0);
                }
            }
            
            // Próba wyodrębnienia recommendations
            Pattern recPattern = Pattern.compile('"recommendations"\\s*:\\s*"([^"]+)"');
            Matcher recMatcher = recPattern.matcher(response);
            if (recMatcher.find()) {
                String recommendations = recMatcher.group(1);
                result.put('recommendations', recommendations);
            }
            
            // Jeśli nie znaleziono żadnych danych, zwróć pustą mapę
            if (result.isEmpty()) {
                return new Map<String, Object>();
            }
            
            return result;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in extractDataManually: ' + e.getMessage());
            return new Map<String, Object>();
        }
    }
    
    /**
     * @description Ekstrahuje tekst z dokumentu CV
     * @param cv Wersja zawartości dokumentu CV
     * @return Wyekstrahowany tekst z dokumentu
     */
    private static String extractTextFromCV(ContentVersion cv) {
        if (cv.FileType == null) {
            throw new CVAnalysisException('Typ pliku nie został określony');
        }
        
        return convertToText(cv);
    }
    
    /**
     * @description Pobiera dane stanowiska
     * @param positionId Id stanowiska
     * @return Obiekt stanowiska lub null jeśli nie znaleziono
     */
    private static Position__c getPosition(Id positionId) {
        try {
            // Walidacja uprawnień CRUD
            validatePositionAccess();
            
            // Wykonaj zapytanie SOQL
            List<Position__c> positionList = [
                SELECT Id, Name, Job_Description__c, Required_Skills__c 
                FROM Position__c 
                WHERE Id = :positionId 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            return positionList.isEmpty() ? null : positionList[0];
        } catch (Exception e) {
            Logger.error('Error fetching Position', e);
            return null;
        }
    }
    
    /**
     * @description Waliduje uprawnienia dostępu do obiektu Position__c
     * @throws Exception jeśli użytkownik nie ma wymaganych uprawnień
     */
    private static void validatePositionAccess() {
        // Walidacja uprawnień CRUD
        if (!Schema.SObjectType.Position__c.isAccessible()) {
            throw new CVAnalysisException('Brak uprawnień do odczytu obiektów Position__c');
        }
        
        // Walidacja uprawnień do pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Position__c.fields.getMap();
        for (String field : new List<String>{'Id', 'Name', 'Job_Description__c', 'Required_Skills__c'}) {
            if (!fieldMap.get(field).getDescribe().isAccessible()) {
                throw new CVAnalysisException('Brak uprawnień do odczytu pola Position__c.' + field);
            }
        }
    }
    
    /**
     * @description Parsuje listę umiejętności z tekstu
     * @param skillsString Tekst zawierający umiejętności oddzielone przecinkami
     * @return Lista umiejętności
     */
    private static List<String> parseSkills(String skillsString) {
        if (String.isBlank(skillsString)) {
            return new List<String>();
        }
        
        List<String> skills = skillsString.split(',');
        for (Integer i = 0; i < skills.size(); i++) {
            skills[i] = skills[i].trim();
        }
        return skills;
    }
    
    /**
     * @description Konwertuje dokument na tekst
     * @param cv Wersja zawartości dokumentu
     * @return Wyekstrahowany tekst z dokumentu
     */
    private static String convertToText(ContentVersion cv) {
        if (cv.FileType == null) {
            throw new CVAnalysisException('Typ pliku nie został określony');
        }
        
        String fileType = cv.FileType.toUpperCase();
        
        if (fileType == PDF_TYPE) {
            return parsePDF(cv.VersionData);
        } else {
            throw new CVAnalysisException('Nieobsługiwany format pliku: ' + cv.FileType + '. Aplikacja obsługuje tylko pliki PDF.');
        }
    }
    
    /**
     * @description Parsuje dokument PDF
     * Wykorzystuje Google Vision API do ekstrakcji tekstu z dokumentu PDF
     * @param pdfData Dane dokumentu PDF w formacie Blob
     * @return Wyekstrahowany tekst z dokumentu PDF
     */
    private static String parsePDF(Blob pdfData) {
        try {
            // Sprawdź, czy dane PDF nie są puste
            if (pdfData == null || pdfData.size() == 0) {
                Logger.error('Dane PDF są puste', null);
                throw new CVAnalysisException('Plik PDF jest pusty lub uszkodzony. Proszę sprawdzić plik i spróbować ponownie.');
            }
            
            // Logowanie rozmiaru pliku PDF dla celów diagnostycznych
            Integer pdfSize = pdfData.size();
            Logger.info('CVAnalysisHelper', 'parsePDF', 'Rozmiar pliku PDF: ' + pdfSize + ' bajtów');
            
            // Sprawdź, czy plik PDF ma minimalny rozmiar (puste pliki PDF mają zwykle kilkaset bajtów)
            if (pdfSize < 500) {
                Logger.warn('CVAnalysisHelper', 'parsePDF', 'Plik PDF jest bardzo mały (' + pdfSize + ' bajtów), może być uszkodzony lub pusty');
            }
            
            // Sprawdź, czy plik PDF ma poprawny nagłówek (pliki PDF zaczynają się od "%PDF-")
            String pdfHeader = EncodingUtil.base64Encode(pdfData).substring(0, Math.min(20, EncodingUtil.base64Encode(pdfData).length()));
            Logger.info('CVAnalysisHelper', 'parsePDF', 'Nagłówek pliku PDF (Base64): ' + pdfHeader);
            
            // Próba użycia Google Vision API do ekstrakcji tekstu
            try {
                String extractedText = extractTextUsingGoogleVision(pdfData, PDF_MIME_TYPE);
                
                // Jeśli Google Vision API zadziałało, zwróć wynik
                if (String.isNotBlank(extractedText)) {
                    Logger.info('CVAnalysisHelper', 'parsePDF', 'Pomyślnie wyekstrahowano tekst z PDF. Długość tekstu: ' + extractedText.length());
                    return extractedText;
                }
                
                // Jeśli Google Vision API nie zwróciło tekstu, rzuć wyjątek
                Logger.error('CVAnalysisHelper', 'parsePDF', 'Google Vision API nie zwróciło tekstu', null);
                throw new CVAnalysisException('Nie udało się wyekstrahować tekstu z pliku PDF. Sprawdź, czy plik zawiera tekst możliwy do odczytania.');
            } catch (CVAnalysisException e) {
                // Jeśli wystąpił błąd "Bad image data", spróbuj użyć naszej usługi PDF Extractor
                if (e.getMessage().contains('Bad image data')) {
                    Logger.error('CVAnalysisHelper', 'parsePDF', 'Błąd "Bad image data" z Google Vision API. Próba użycia usługi PDF Extractor.', null);
                    
                    // Próba użycia usługi PDF Extractor
                    try {
                        String pdfExtractorText = extractTextUsingPdfExtractor(pdfData);
                        if (String.isNotBlank(pdfExtractorText)) {
                            Logger.info('CVAnalysisHelper', 'parsePDF', 'Pomyślnie wyekstrahowano tekst z PDF używając usługi PDF Extractor. Długość tekstu: ' + pdfExtractorText.length());
                            return pdfExtractorText;
                        } else {
                            Logger.warn('CVAnalysisHelper', 'parsePDF', 'Usługa PDF Extractor zwróciła pusty tekst');
                            
                            // Jeśli usługa PDF Extractor nie zadziałała, spróbuj alternatywnej metody
                            String alternativeText = extractTextAlternative(pdfData);
                            if (String.isNotBlank(alternativeText)) {
                                Logger.info('CVAnalysisHelper', 'parsePDF', 'Pomyślnie wyekstrahowano tekst z PDF używając alternatywnej metody. Długość tekstu: ' + alternativeText.length());
                                return alternativeText;
                            } else {
                                Logger.warn('CVAnalysisHelper', 'parsePDF', 'Alternatywna metoda ekstrakcji tekstu zwróciła pusty tekst');
                                throw new CVAnalysisException('Nie udało się wyekstrahować tekstu z pliku PDF używając żadnej z dostępnych metod. Sprawdź, czy plik zawiera tekst możliwy do odczytania.');
                            }
                        }
                    } catch (Exception extEx) {
                        Logger.error('CVAnalysisHelper', 'parsePDF', 'Błąd podczas używania usługi PDF Extractor: ' + extEx.getMessage(), extEx);
                        
                        // Jeśli usługa PDF Extractor nie zadziałała, spróbuj alternatywnej metody
                        try {
                            String alternativeText = extractTextAlternative(pdfData);
                            if (String.isNotBlank(alternativeText)) {
                                Logger.info('CVAnalysisHelper', 'parsePDF', 'Pomyślnie wyekstrahowano tekst z PDF używając alternatywnej metody. Długość tekstu: ' + alternativeText.length());
                                return alternativeText;
                            } else {
                                Logger.warn('CVAnalysisHelper', 'parsePDF', 'Alternatywna metoda ekstrakcji tekstu zwróciła pusty tekst');
                                throw new CVAnalysisException('Nie udało się wyekstrahować tekstu z pliku PDF używając żadnej z dostępnych metod. Sprawdź, czy plik zawiera tekst możliwy do odczytania.');
                            }
                        } catch (Exception altEx) {
                            Logger.error('CVAnalysisHelper', 'parsePDF', 'Błąd podczas używania alternatywnej metody ekstrakcji tekstu: ' + altEx.getMessage(), altEx);
                            throw new CVAnalysisException('Błąd podczas analizy pliku PDF: Google Vision API zgłosiło "Bad image data", a żadna z alternatywnych metod ekstrakcji tekstu nie zadziałała. ' +
                                                         'Sprawdź, czy plik PDF jest poprawny, nie jest zabezpieczony hasłem i jest w standardowym formacie PDF.');
                        }
                    }
                }
                // Przekazujemy dalej inne wyjątki CVAnalysisException
                throw e;
            }
        } catch (CVAnalysisException e) {
            // Przekazujemy dalej wyjątki CVAnalysisException
            throw e;
        } catch (Exception e) {
            Logger.error('Błąd podczas przetwarzania pliku PDF', e);
            throw new CVAnalysisException('Błąd podczas przetwarzania pliku PDF: ' + e.getMessage() + '. Sprawdź, czy plik PDF jest poprawny i zawiera tekst możliwy do odczytania.');
        }
    }
    
    /**
     * @description Ekstrahuje tekst z dokumentu PDF używając usługi PDF Extractor
     * @param pdfData Dane dokumentu PDF w formacie Blob
     * @return Wyekstrahowany tekst z dokumentu PDF
     */
    private static String extractTextUsingPdfExtractor(Blob pdfData) {
        try {
            // Konwertuj Blob do Base64
            String base64Data = EncodingUtil.base64Encode(pdfData);
            Logger.info('CVAnalysisHelper', 'extractTextUsingPdfExtractor', 'Długość danych Base64: ' + base64Data.length());
            
            // Przygotuj żądanie HTTP do usługi PDF Extractor
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://smarthire-pdf-service-3d672936eec0.herokuapp.com/api/extract');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000); // 120 sekund timeout
            
            // Przygotuj dane do wysłania
            Map<String, String> requestBody = new Map<String, String>{
                'pdfData' => base64Data
            };
            req.setBody(JSON.serialize(requestBody));
            
            // Wyślij żądanie
            Logger.info('CVAnalysisHelper', 'extractTextUsingPdfExtractor', 'Wysyłanie żądania do usługi PDF Extractor');
            HttpResponse res = http.send(req);
            
            // Sprawdź odpowiedź
            if (res.getStatusCode() == 200) {
                // Parsuj odpowiedź JSON
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                
                // Sprawdź, czy operacja się powiodła
                if (responseMap.containsKey('success') && (Boolean)responseMap.get('success')) {
                    // Pobierz wyekstrahowany tekst
                    String extractedText = (String)responseMap.get('text');
                    Logger.info('CVAnalysisHelper', 'extractTextUsingPdfExtractor', 'Pomyślnie wyekstrahowano tekst. Długość tekstu: ' + extractedText.length());
                    return extractedText;
                } else {
                    // Operacja się nie powiodła
                    String errorMessage = responseMap.containsKey('error') ? (String)responseMap.get('error') : 'Nieznany błąd';
                    Logger.error('CVAnalysisHelper', 'extractTextUsingPdfExtractor', 'Błąd z usługi PDF Extractor: ' + errorMessage, null);
                    throw new CVAnalysisException('Błąd podczas ekstrakcji tekstu z PDF: ' + errorMessage);
                }
            } else {
                // Błąd HTTP
                Logger.error('CVAnalysisHelper', 'extractTextUsingPdfExtractor', 'Błąd HTTP: ' + res.getStatusCode() + ' - ' + res.getStatus(), null);
                throw new CVAnalysisException('Błąd podczas komunikacji z usługą PDF Extractor: ' + res.getStatus());
            }
        } catch (Exception e) {
            Logger.error('CVAnalysisHelper', 'extractTextUsingPdfExtractor', 'Wyjątek: ' + e.getMessage(), e);
            throw new CVAnalysisException('Błąd podczas ekstrakcji tekstu z PDF: ' + e.getMessage());
        }
    }
    
    /**
     * @description Alternatywna metoda ekstrakcji tekstu z dokumentu PDF
     * Ta metoda używa prostego podejścia do ekstrakcji tekstu z pliku PDF
     * @param documentData Dane dokumentu w formacie Blob
     * @return Wyekstrahowany tekst lub rzuca wyjątek w przypadku niepowodzenia
     */
    private static String extractTextAlternative(Blob documentData) {
        try {
            // Próba konwersji Blob do String
            String pdfText = '';
            try {
                // Próba bezpośredniej konwersji Blob do String (może działać dla niektórych plików PDF)
                pdfText = documentData.toString();
                
                // Sprawdź, czy tekst zawiera znaczniki PDF
                if (pdfText.contains('%PDF-') && (pdfText.contains('/Text') || pdfText.contains('/Font') || pdfText.contains('/Contents'))) {
                    // Usuń binarne dane i znaki kontrolne
                    pdfText = pdfText.replaceAll('[\\x00-\\x1F\\x7F-\\xFF]', ' ');
                    // Usuń znaczniki PDF
                    pdfText = pdfText.replaceAll('\\%PDF-[0-9\\.]+', '');
                    pdfText = pdfText.replaceAll('\\%[^\\n]*', '');
                    // Usuń obiekty PDF
                    pdfText = pdfText.replaceAll('[0-9]+ [0-9]+ obj[\\s\\S]*?endobj', '');
                    // Usuń strumienie PDF
                    pdfText = pdfText.replaceAll('stream[\\s\\S]*?endstream', '');
                    // Usuń xref i trailer
                    pdfText = pdfText.replaceAll('xref[\\s\\S]*?trailer', '');
                    // Usuń powtarzające się spacje
                    pdfText = pdfText.replaceAll('\\s+', ' ').trim();
                    
                    if (pdfText.length() > 100) {
                        Logger.info('CVAnalysisHelper', 'extractTextAlternative', 'Pomyślnie wyekstrahowano tekst z PDF. Długość tekstu: ' + pdfText.length());
                        return pdfText;
                    }
                }
            } catch (Exception e) {
                Logger.warn('CVAnalysisHelper', 'extractTextAlternative', 'Błąd podczas konwersji Blob do String: ' + e.getMessage());
            }
            
            // Jeśli nie udało się wyekstrahować tekstu, rzuć wyjątek
            Logger.warn('CVAnalysisHelper', 'extractTextAlternative', 'Nie udało się wyekstrahować tekstu z pliku PDF.');
            throw new CVAnalysisException('Nie udało się wyekstrahować tekstu z pliku PDF. Plik może być zabezpieczony, uszkodzony lub w nieobsługiwanym formacie. Spróbuj przekonwertować plik do standardowego formatu PDF i wgraj ponownie.');
            
        } catch (CVAnalysisException e) {
            // Przekazujemy dalej wyjątki CVAnalysisException
            throw e;
        } catch (Exception e) {
            Logger.error('Błąd podczas używania alternatywnej metody ekstrakcji tekstu', e);
            throw new CVAnalysisException('Błąd podczas używania alternatywnej metody ekstrakcji tekstu: ' + e.getMessage());
        }
    }
    
    /**
     * @description Ekstrahuje tekst z dokumentu używając Google Vision API
     * @param documentData Dane dokumentu w formacie Blob
     * @param contentType Typ zawartości dokumentu (MIME type)
     * @return Wyekstrahowany tekst lub null w przypadku niepowodzenia
     */
    private static String extractTextUsingGoogleVision(Blob documentData, String contentType) {
        try {
            // Walidacja uprawnień do Custom Settings
            validateGoogleVisionSettingsAccess();
            
            // Pobierz ustawienia Google Vision API
            Google_Vision_API_Settings__c settings = Google_Vision_API_Settings__c.getInstance();
            if (settings == null || String.isBlank(settings.Vision_API_Key__c)) {
                Logger.warn('Google Vision API settings not configured');
                throw new CVAnalysisException('Brak skonfigurowanego klucza API dla Google Vision. Skontaktuj się z administratorem.');
            }
            
            // Przygotuj i wykonaj zapytanie do Google Vision API
            HttpResponse res = callGoogleVisionAPI(documentData, contentType);
            
            // Przetwórz odpowiedź
            return processVisionAPIResponse(res);
        } catch (CVAnalysisException e) {
            // Przekazujemy dalej wyjątki CVAnalysisException
            throw e;
        } catch (Exception e) {
            Logger.error('Błąd podczas używania Google Vision API: ' + e.getMessage(), e);
            throw new CVAnalysisException('Błąd podczas używania Google Vision API: ' + e.getMessage());
        }
    }
    
    /**
     * @description Waliduje uprawnienia dostępu do obiektu Google_Vision_API_Settings__c
     * @throws Exception jeśli użytkownik nie ma wymaganych uprawnień
     */
    private static void validateGoogleVisionSettingsAccess() {
        // Walidacja uprawnień CRUD
        if (!Schema.SObjectType.Google_Vision_API_Settings__c.isAccessible()) {
            throw new CVAnalysisException('Brak uprawnień do odczytu obiektów Google_Vision_API_Settings__c');
        }
        
        // Walidacja uprawnień do pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Google_Vision_API_Settings__c.fields.getMap();
        if (!fieldMap.get('Vision_API_Key__c').getDescribe().isAccessible()) {
            throw new CVAnalysisException('Brak uprawnień do odczytu pola Google_Vision_API_Settings__c.Vision_API_Key__c');
        }
    }
    
    /**
     * @description Wywołuje Google Vision API
     * @param documentData Dane dokumentu w formacie Blob
     * @param contentType Typ zawartości dokumentu (MIME type)
     * @return Odpowiedź HTTP z Google Vision API
     */
    private static HttpResponse callGoogleVisionAPI(Blob documentData, String contentType) {
        try {
            // Pobierz ustawienia i waliduj dane wejściowe
            Google_Vision_API_Settings__c settings = getAndValidateAPISettings();
            validateDocumentData(documentData);
            
            // Przygotuj i wykonaj zapytanie HTTP
            HttpRequest req = prepareHttpRequest(settings.Vision_API_Key__c, documentData, contentType);
            return executeHttpRequest(req);
        } catch (CVAnalysisException e) {
            throw e;
        } catch (Exception e) {
            Logger.error('Nieoczekiwany błąd: ' + e.getMessage(), e);
            throw new CVAnalysisException('Błąd podczas wywołania Google Vision API: ' + e.getMessage());
        }
    }
    
    /**
     * @description Pobiera i waliduje ustawienia API Google Vision
     * @return Obiekt ustawień Google Vision API
     * @throws Exception jeśli ustawienia są nieprawidłowe
     */
    private static Google_Vision_API_Settings__c getAndValidateAPISettings() {
        Google_Vision_API_Settings__c settings = Google_Vision_API_Settings__c.getInstance();
        if (settings == null || String.isBlank(settings.Vision_API_Key__c)) {
            Logger.warn('Google Vision API settings not configured');
            throw new CVAnalysisException('Brak skonfigurowanego klucza API dla Google Vision. Skontaktuj się z administratorem.');
        }
        
        Logger.info('CVAnalysisHelper', 'getAndValidateAPISettings', 'Rozpoczynam wywołanie Google Vision API');
        Logger.info('CVAnalysisHelper', 'getAndValidateAPISettings', 'Klucz API: ' + 
                   (settings.Vision_API_Key__c != null ? 'Skonfigurowany (pierwsze 5 znaków: ' + 
                    settings.Vision_API_Key__c.substring(0, Math.min(5, settings.Vision_API_Key__c.length())) + '...)' : 'Brak'));
        
        return settings;
    }
    
    /**
     * @description Waliduje dane dokumentu
     * @param documentData Dane dokumentu w formacie Blob
     * @throws Exception jeśli dane są nieprawidłowe
     */
    private static void validateDocumentData(Blob documentData) {
        // Sprawdź, czy dane dokumentu nie są puste
        if (documentData == null || documentData.size() == 0) {
            Logger.warn('CVAnalysisHelper', 'validateDocumentData', 'Dane dokumentu są puste');
            throw new CVAnalysisException('Dane dokumentu są puste. Nie można przeprowadzić analizy.');
        }
        
        // Sprawdź, czy rozmiar dokumentu nie przekracza limitu Google Vision API (10MB)
        if (documentData.size() > 10 * 1024 * 1024) {
            Logger.warn('CVAnalysisHelper', 'validateDocumentData', 'Rozmiar dokumentu przekracza limit 10MB: ' + documentData.size() + ' bajtów');
            throw new CVAnalysisException('Rozmiar dokumentu przekracza limit 10MB. Proszę użyć mniejszego pliku.');
        }
    }
    
    /**
     * @description Przygotowuje zapytanie HTTP do Google Vision API
     * @param apiKey Klucz API Google Vision
     * @param documentData Dane dokumentu w formacie Blob
     * @param contentType Typ zawartości dokumentu (MIME type)
     * @return Obiekt HttpRequest gotowy do wysłania
     */
    private static HttpRequest prepareHttpRequest(String apiKey, Blob documentData, String contentType) {
        HttpRequest req = new HttpRequest();
        String endpoint = 'https://vision.googleapis.com/v1/images:annotate?key=' + apiKey;
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000); // Zwiększamy timeout do 120 sekund
        
        // Konwersja dokumentu do Base64
        String base64Data = EncodingUtil.base64Encode(documentData);
        Logger.info('CVAnalysisHelper', 'prepareHttpRequest', 'Długość danych Base64: ' + base64Data.length());
        
        // Przygotuj ciało zapytania
        Map<String, Object> requestBody = prepareVisionAPIRequestBody(contentType, base64Data);
        String requestBodyJson = JSON.serialize(requestBody);
        req.setBody(requestBodyJson);
        
        Logger.info('CVAnalysisHelper', 'prepareHttpRequest', 'Endpoint: ' + endpoint.substring(0, endpoint.indexOf('?')) + '?key=HIDDEN');
        Logger.info('CVAnalysisHelper', 'prepareHttpRequest', 'Metoda: ' + req.getMethod());
        Logger.info('CVAnalysisHelper', 'prepareHttpRequest', 'Długość ciała zapytania: ' + requestBodyJson.length());
        
        return req;
    }
    
    /**
     * @description Wykonuje zapytanie HTTP i obsługuje odpowiedź
     * @param req Obiekt HttpRequest do wysłania
     * @return Odpowiedź HTTP z Google Vision API
     * @throws Exception w przypadku błędu
     */
    private static HttpResponse executeHttpRequest(HttpRequest req) {
        Http http = new Http();
        HttpResponse res;
        
        try {
            res = http.send(req);
            
            // Logowanie dla celów diagnostycznych
            Logger.info('CVAnalysisHelper', 'executeHttpRequest', 'Kod statusu odpowiedzi: ' + res.getStatusCode());
            Logger.info('CVAnalysisHelper', 'executeHttpRequest', 'Długość odpowiedzi: ' + res.getBodyAsBlob().size());
            
            return handleHttpResponse(res);
        } catch (System.CalloutException e) {
            Logger.error('Błąd podczas wywołania Google Vision API: ' + e.getMessage(), e);
            throw new CVAnalysisException('Błąd podczas wywołania Google Vision API: ' + e.getMessage());
        }
    }
    
    /**
     * @description Obsługuje odpowiedź HTTP z Google Vision API
     * @param res Odpowiedź HTTP z Google Vision API
     * @return Odpowiedź HTTP jeśli status 200, w przeciwnym razie rzuca wyjątek
     * @throws Exception w przypadku błędu
     */
    private static HttpResponse handleHttpResponse(HttpResponse res) {
        if (res.getStatusCode() == 200) {
            // Sprawdź, czy odpowiedź zawiera błąd "Bad image data"
            if (res.getBody().contains('Bad image data')) {
                Logger.error('Błąd "Bad image data" w odpowiedzi Google Vision API: ' + res.getBody(), null);
                throw new CVAnalysisException('Błąd Google Vision API: Bad image data. ' +
                                            'Sprawdź, czy plik PDF jest poprawny, nie jest zabezpieczony hasłem i jest w standardowym formacie PDF.');
            }
            return res;
        } else if (res.getStatusCode() == 400) {
            // Błąd w zapytaniu
            String errorDetails = extractErrorDetails(res.getBody());
            Logger.error('Błąd w zapytaniu do Google Vision API: ' + errorDetails, null);
            
            // Sprawdź, czy błąd dotyczy "Bad image data"
            if (errorDetails.contains('Bad image data')) {
                throw new CVAnalysisException('Błąd Google Vision API: Bad image data. ' +
                                            'Sprawdź, czy plik PDF jest poprawny, nie jest zabezpieczony hasłem i jest w standardowym formacie PDF.');
            } else {
                throw new CVAnalysisException('Błąd w zapytaniu do Google Vision API. Sprawdź format dokumentu. Szczegóły: ' + errorDetails);
            }
        } else if (res.getStatusCode() == 401 || res.getStatusCode() == 403) {
            // Błąd autoryzacji
            String errorDetails = extractErrorDetails(res.getBody());
            Logger.error('Błąd autoryzacji Google Vision API: ' + errorDetails, null);
            throw new CVAnalysisException('Błąd autoryzacji Google Vision API. Sprawdź klucz API. Szczegóły: ' + errorDetails);
        } else if (res.getStatusCode() == 429) {
            // Przekroczono limit zapytań
            String errorDetails = extractErrorDetails(res.getBody());
            Logger.error('Przekroczono limit zapytań do Google Vision API: ' + errorDetails, null);
            throw new CVAnalysisException('Przekroczono limit zapytań do Google Vision API. Spróbuj ponownie później. Szczegóły: ' + errorDetails);
        } else {
            // Inny błąd
            String errorDetails = extractErrorDetails(res.getBody());
            Logger.error('Błąd Google Vision API: ' + res.getStatusCode() + ' - ' + errorDetails, null);
            throw new CVAnalysisException('Błąd Google Vision API. Kod statusu: ' + res.getStatusCode() + '. Szczegóły: ' + errorDetails);
        }
    }
    
    /**
     * @description Extracts error details from Google Vision API response
     * @param responseBody Response body
     * @return Error details
     */
    private static String extractErrorDetails(String responseBody) {
        try {
            if (String.isBlank(responseBody)) {
                return 'No error details available';
            }
            
            // Try to parse response as JSON
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            
            // Initialize error variables
            String errorCode = '';
            String errorMessage = '';
            String errorDetails = '';
            
            // Check if response contains "error" field
            if (responseMap.containsKey('error')) {
                Map<String, Object> errorMap = (Map<String, Object>) responseMap.get('error');
                
                // Get error code and message
                errorCode = errorMap.containsKey('code') ? String.valueOf(errorMap.get('code')) : '';
                errorMessage = errorMap.containsKey('message') ? String.valueOf(errorMap.get('message')) : '';
                
                // Get error details if they exist
                if (errorMap.containsKey('details') && errorMap.get('details') instanceof List<Object>) {
                    List<Object> detailsList = (List<Object>)errorMap.get('details');
                    for (Object detail : detailsList) {
                        if (detail instanceof Map<String, Object>) {
                            Map<String, Object> detailMap = (Map<String, Object>) detail;
                            if (detailMap.containsKey('detail')) {
                                errorDetails += String.valueOf(detailMap.get('detail')) + ' ';
                            }
                        }
                    }
                }
            }
            
            // Return formatted error details
            return 'Code: ' + errorCode + ', Message: ' + errorMessage + (String.isNotBlank(errorDetails) ? ', Details: ' + errorDetails : '');
        } catch (Exception e) {
            // In case of parsing error, return the original response (limited to 500 characters)
            return 'Error parsing response: ' + e.getMessage() + '. Original response: ' + 
                   (responseBody.length() > 500 ? responseBody.substring(0, 500) + '...' : responseBody);
        }
    }
    
    /**
     * @description Przygotowuje ciało zapytania dla Google Vision API
     * @param contentType Typ zawartości dokumentu (MIME type)
     * @param base64Data Dane dokumentu w formacie Base64
     * @return Mapa zawierająca ciało zapytania
     */
    private static Map<String, Object> prepareVisionAPIRequestBody(String contentType, String base64Data) {
        // Przygotuj ciało zapytania zgodnie z dokumentacją Google Vision API
        // https://cloud.google.com/vision/docs/reference/rest/v1/images/annotate
        
        // Logowanie dla celów diagnostycznych
        Logger.info('CVAnalysisHelper', 'prepareVisionAPIRequestBody', 'Przygotowuję ciało zapytania dla Google Vision API');
        
        // Sprawdź, czy dane Base64 są poprawne
        if (String.isBlank(base64Data)) {
            Logger.error('CVAnalysisHelper', 'prepareVisionAPIRequestBody', 'Dane Base64 są puste', null);
            throw new CVAnalysisException('Dane Base64 są puste. Nie można przeprowadzić analizy.');
        }
        
        // Logowanie długości danych Base64 i fragmentów dla celów diagnostycznych
        Integer base64Length = base64Data.length();
        Logger.info('CVAnalysisHelper', 'prepareVisionAPIRequestBody', 'Długość danych Base64: ' + base64Length);
        
        // Loguj pierwsze i ostatnie 100 znaków danych Base64 (lub mniej, jeśli dane są krótsze)
        String base64Start = base64Data.substring(0, Math.min(100, base64Length));
        String base64End = base64Length > 100 ? base64Data.substring(base64Length - 100, base64Length) : '';
        
        Logger.info('CVAnalysisHelper', 'prepareVisionAPIRequestBody', 'Początek danych Base64: ' + base64Start);
        Logger.info('CVAnalysisHelper', 'prepareVisionAPIRequestBody', 'Koniec danych Base64: ' + base64End);
        
        // Sprawdź, czy dane Base64 mają poprawny format (powinny zawierać tylko znaki Base64)
        if (!Pattern.matches('^[A-Za-z0-9+/=]+$', base64Data)) {
            Logger.warn('CVAnalysisHelper', 'prepareVisionAPIRequestBody', 'Dane Base64 zawierają nieprawidłowe znaki');
        }
        
        // Uproszczone zapytanie, które działa poprawnie z Google Vision API
        Map<String, Object> requestBody = new Map<String, Object>{
            'requests' => new List<Object>{
                new Map<String, Object>{
                    'image' => new Map<String, Object>{
                        'content' => base64Data
                    },
                    'features' => new List<Object>{
                        new Map<String, Object>{
                            'type' => 'DOCUMENT_TEXT_DETECTION',
                            'maxResults' => 10
                        }
                    }
                }
            }
        };
        
        Logger.info('CVAnalysisHelper', 'prepareVisionAPIRequestBody', 'Ciało zapytania przygotowane poprawnie');
        return requestBody;
    }
    
    /**
     * @description Przetwarza odpowiedź z Google Vision API
     * @param res Odpowiedź HTTP z Google Vision API
     * @return Wyekstrahowany tekst lub null w przypadku niepowodzenia
     */
    private static String processVisionAPIResponse(HttpResponse res) {
        try {
            // Walidacja odpowiedzi
            validateVisionAPIResponse(res);
            
            // Deserializacja odpowiedzi
            Map<String, Object> responseMap = deserializeResponse(res.getBody());
            
            // Ekstrakcja tekstu z odpowiedzi
            return extractTextFromResponse(responseMap);
        } catch (CVAnalysisException e) {
            throw e;
        } catch (Exception e) {
            Logger.error('Błąd podczas przetwarzania odpowiedzi z Google Vision API: ' + e.getMessage(), e);
            throw new CVAnalysisException('Błąd podczas przetwarzania odpowiedzi z Google Vision API: ' + e.getMessage());
        }
    }
    
    /**
     * @description Waliduje odpowiedź z Google Vision API
     * @param res Odpowiedź HTTP z Google Vision API
     * @throws Exception jeśli odpowiedź jest nieprawidłowa
     */
    private static void validateVisionAPIResponse(HttpResponse res) {
        if (res.getStatusCode() != 200) {
            Logger.error('Błąd Google Vision API: ' + res.getStatusCode() + ' - ' + res.getBody(), null);
            throw new CVAnalysisException('Błąd odpowiedzi z Google Vision API. Kod statusu: ' + res.getStatusCode());
        }
        
        Logger.info('CVAnalysisHelper', 'validateVisionAPIResponse', 'Otrzymano odpowiedź z Google Vision API. Status: ' + res.getStatusCode());
    }
    
    /**
     * @description Deserializuje odpowiedź z Google Vision API
     * @param responseBody Ciało odpowiedzi z Google Vision API
     * @return Mapa zawierająca zdeserializowaną odpowiedź
     * @throws Exception jeśli odpowiedź jest nieprawidłowa
     */
    private static Map<String, Object> deserializeResponse(String responseBody) {
        Logger.info('CVAnalysisHelper', 'deserializeResponse', 'Długość odpowiedzi: ' + responseBody.length());
        Logger.info('CVAnalysisHelper', 'deserializeResponse', 'Pierwsze 200 znaków odpowiedzi: ' + 
                   (responseBody.length() > 200 ? responseBody.substring(0, 200) + '...' : responseBody));
        
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        } catch (Exception e) {
            Logger.error('Błąd podczas deserializacji odpowiedzi: ' + e.getMessage(), e);
            throw new CVAnalysisException('Błąd podczas deserializacji odpowiedzi z Google Vision API: ' + e.getMessage());
        }
    }
    
    /**
     * @description Ekstrahuje tekst z odpowiedzi Google Vision API
     * @param responseMap Mapa zawierająca zdeserializowaną odpowiedź
     * @return Wyekstrahowany tekst
     * @throws Exception jeśli nie można wyekstrahować tekstu
     */
    private static String extractTextFromResponse(Map<String, Object> responseMap) {
        // Sprawdź, czy odpowiedź zawiera wyniki
        if (!responseMap.containsKey('responses')) {
            Logger.warn('CVAnalysisHelper', 'extractTextFromResponse', 'Odpowiedź nie zawiera klucza "responses"');
            throw new CVAnalysisException('Odpowiedź z Google Vision API nie zawiera wyników.');
        }
        
        List<Object> responses = (List<Object>)responseMap.get('responses');
        if (responses.isEmpty()) {
            Logger.warn('CVAnalysisHelper', 'extractTextFromResponse', 'Lista "responses" jest pusta');
            throw new CVAnalysisException('Odpowiedź z Google Vision API zawiera pustą listę wyników.');
        }
        
        // Pobierz pierwszą odpowiedź
        Map<String, Object> firstResponse = (Map<String, Object>)responses[0];
        Logger.info('CVAnalysisHelper', 'extractTextFromResponse', 'Klucze w pierwszej odpowiedzi: ' + firstResponse.keySet());
        
        // Próba ekstrakcji tekstu z fullTextAnnotation
        String extractedText = extractTextFromFullTextAnnotation(firstResponse);
        if (String.isNotBlank(extractedText)) {
            return extractedText;
        }
        
        // Próba ekstrakcji tekstu z textAnnotations
        extractedText = extractTextFromTextAnnotations(firstResponse);
        if (String.isNotBlank(extractedText)) {
            return extractedText;
        }
        
        // Sprawdź, czy odpowiedź zawiera błędy
        checkForErrors(firstResponse);
        
        // Jeśli nie znaleziono tekstu ani błędów, rzuć wyjątek
        Logger.warn('CVAnalysisHelper', 'extractTextFromResponse', 'Odpowiedź nie zawiera tekstu ani w fullTextAnnotation, ani w textAnnotations');
        throw new CVAnalysisException('Odpowiedź z Google Vision API nie zawiera tekstu. Sprawdź, czy plik PDF zawiera tekst możliwy do odczytania.');
    }
    
    /**
     * @description Ekstrahuje tekst z fullTextAnnotation
     * @param response Mapa zawierająca odpowiedź
     * @return Wyekstrahowany tekst lub null jeśli nie znaleziono
     */
    private static String extractTextFromFullTextAnnotation(Map<String, Object> response) {
        if (response.containsKey('fullTextAnnotation')) {
            Map<String, Object> fullTextAnnotation = (Map<String, Object>)response.get('fullTextAnnotation');
            if (fullTextAnnotation.containsKey('text')) {
                String extractedText = (String)fullTextAnnotation.get('text');
                if (String.isNotBlank(extractedText)) {
                    Logger.info('CVAnalysisHelper', 'extractTextFromFullTextAnnotation', 'Wyekstrahowano tekst z fullTextAnnotation. Długość: ' + extractedText.length());
                    Logger.info('CVAnalysisHelper', 'extractTextFromFullTextAnnotation', 'Pierwsze 100 znaków: ' + 
                               (extractedText.length() > 100 ? extractedText.substring(0, 100) + '...' : extractedText));
                    return extractedText;
                } else {
                    Logger.warn('CVAnalysisHelper', 'extractTextFromFullTextAnnotation', 'Tekst w fullTextAnnotation jest pusty');
                }
            } else {
                Logger.warn('CVAnalysisHelper', 'extractTextFromFullTextAnnotation', 'fullTextAnnotation nie zawiera klucza "text"');
            }
        } else {
            Logger.warn('CVAnalysisHelper', 'extractTextFromFullTextAnnotation', 'Odpowiedź nie zawiera fullTextAnnotation');
        }
        return null;
    }
    
    /**
     * @description Ekstrahuje tekst z textAnnotations
     * @param response Mapa zawierająca odpowiedź
     * @return Wyekstrahowany tekst lub null jeśli nie znaleziono
     */
    private static String extractTextFromTextAnnotations(Map<String, Object> response) {
        if (response.containsKey('textAnnotations') && !((List<Object>)response.get('textAnnotations')).isEmpty()) {
            List<Object> textAnnotations = (List<Object>)response.get('textAnnotations');
            Logger.info('CVAnalysisHelper', 'extractTextFromTextAnnotations', 'Znaleziono ' + textAnnotations.size() + ' adnotacji tekstowych');
            
            Map<String, Object> firstTextAnnotation = (Map<String, Object>)textAnnotations[0];
            if (firstTextAnnotation.containsKey('description')) {
                String extractedText = (String)firstTextAnnotation.get('description');
                if (String.isNotBlank(extractedText)) {
                    Logger.info('CVAnalysisHelper', 'extractTextFromTextAnnotations', 'Wyekstrahowano tekst z textAnnotations. Długość: ' + extractedText.length());
                    Logger.info('CVAnalysisHelper', 'extractTextFromTextAnnotations', 'Pierwsze 100 znaków: ' + 
                               (extractedText.length() > 100 ? extractedText.substring(0, 100) + '...' : extractedText));
                    return extractedText;
                } else {
                    Logger.warn('CVAnalysisHelper', 'extractTextFromTextAnnotations', 'Tekst w textAnnotations jest pusty');
                }
            } else {
                Logger.warn('CVAnalysisHelper', 'extractTextFromTextAnnotations', 'Pierwsza adnotacja tekstowa nie zawiera klucza "description"');
            }
        } else {
            Logger.warn('CVAnalysisHelper', 'extractTextFromTextAnnotations', 'Odpowiedź nie zawiera textAnnotations lub lista jest pusta');
        }
        return null;
    }
    
    /**
     * @description Sprawdza, czy odpowiedź zawiera błędy
     * @param response Mapa zawierająca odpowiedź
     * @throws Exception jeśli znaleziono błędy
     */
    private static void checkForErrors(Map<String, Object> response) {
        if (response.containsKey('error')) {
            Map<String, Object> error = (Map<String, Object>)response.get('error');
            String errorMessage = error.containsKey('message') ? (String)error.get('message') : 'Nieznany błąd';
            Logger.error('Błąd w odpowiedzi Google Vision API: ' + errorMessage, null);
            throw new CVAnalysisException('Błąd Google Vision API: ' + errorMessage);
        }
    }
    
    /**
     * @description Ta metoda została zmodyfikowana, aby zapobiec używaniu mockowanych danych
     * @throws Exception zawsze rzuca wyjątek, aby zapobiec używaniu mockowanych danych
     */
    private static String getMockPDFContent() {
        throw new CVAnalysisException('Funkcja mockowania danych została wyłączona. Aplikacja obsługuje tylko rzeczywiste dane z plików PDF.');
    }

    // Generowanie klucza cache
    private static String generateCacheKey(Id contentDocumentId) {
        String cacheKey = '';
        
        try {
            if (contentDocumentId == null) {
                // Jeśli contentDocumentId jest null, użyj timestampa jako klucza
                cacheKey = 'CV' + String.valueOf(Datetime.now().getTime()).replaceAll('[^a-zA-Z0-9]', '');
                System.debug(LoggingLevel.WARN, '⚠️ Using timestamp-based cache key due to null contentDocumentId: ' + cacheKey);
                return cacheKey;
            }
            
            // Usuń wszystkie znaki niealfanumeryczne z ID dokumentu
            cacheKey = 'CV' + String.valueOf(contentDocumentId).replaceAll('[^a-zA-Z0-9]', '');
            
            // Jeśli po usunięciu znaków niealfanumerycznych klucz jest pusty, użyj timestampa
            if (String.isBlank(cacheKey) || cacheKey.equals('CV')) {
                cacheKey = 'CV' + String.valueOf(Datetime.now().getTime()).replaceAll('[^a-zA-Z0-9]', '');
                System.debug(LoggingLevel.WARN, '⚠️ Using timestamp-based cache key due to empty cleaned contentDocumentId: ' + cacheKey);
            }
            
            // Ogranicz długość klucza do 40 znaków
            if (cacheKey.length() > 40) { 
                cacheKey = cacheKey.substring(0, 40);
            }
            
            // Ostateczna walidacja - jeśli z jakiegoś powodu klucz jest nadal pusty lub zawiera niedozwolone znaki,
            // użyj bezpiecznego klucza opartego na timestampie
            if (String.isBlank(cacheKey) || !Pattern.matches('^[a-zA-Z0-9]+$', cacheKey)) {
                cacheKey = 'CV' + String.valueOf(Datetime.now().getTime()).replaceAll('[^a-zA-Z0-9]', '');
                System.debug(LoggingLevel.WARN, '⚠️ Using fallback timestamp-based cache key: ' + cacheKey);
            }
            
            System.debug(LoggingLevel.INFO, '✅ Final Cache Key: ' + cacheKey);
            return cacheKey;
        } catch (Exception e) {
            // W przypadku jakiegokolwiek błędu, zwróć bezpieczny klucz oparty na timestampie
            cacheKey = 'CV' + String.valueOf(Datetime.now().getTime()).replaceAll('[^a-zA-Z0-9]', '');
            System.debug(LoggingLevel.ERROR, '❌ Error generating cache key: ' + e.getMessage() + '. Using fallback key: ' + cacheKey);
            return cacheKey;
        }
    }

    // Dodajemy klasę wyjątku na końcu klasy
    public class CVAnalysisException extends Exception {}
}
