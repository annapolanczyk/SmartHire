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
 * @last modified on  : 03-12-2025
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
            String systemPrompt = 'Jesteś ekspertem HR analizującym CV kandydatów. Twoim zadaniem jest dokładna analiza CV i wyodrębnienie kluczowych informacji.';
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
            
            // Rzuć wyjątek, aby użytkownik wiedział, że wystąpił problem z API
            throw new AuraHandledException('Błąd podczas analizy CV przez AI: ' + e.getMessage() + 
                '. Sprawdź konfigurację API lub spróbuj ponownie później.');
        } catch (Exception e) {
            Logger.error('Error analyzing resume', e);
            throw new AuraHandledException('Error analyzing resume: ' + e.getMessage());
        }
    }
    
    /**
     * @description Waliduje uprawnienia dostępu do obiektu ContentVersion
     * @throws AuraHandledException jeśli użytkownik nie ma wymaganych uprawnień
     */
    private static void validateContentVersionAccess() {
        // Walidacja uprawnień CRUD
        if (!Schema.SObjectType.ContentVersion.isAccessible()) {
            throw new AuraHandledException('Brak uprawnień do odczytu obiektów ContentVersion');
        }
        
        // Walidacja uprawnień do pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.ContentVersion.fields.getMap();
        for (String field : new List<String>{'Id', 'VersionData', 'FileType'}) {
            if (!fieldMap.get(field).getDescribe().isAccessible()) {
                throw new AuraHandledException('Brak uprawnień do odczytu pola ContentVersion.' + field);
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
                context.jobDescription = String.isNotBlank(position.Description__c) ? position.Description__c : '';
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
        String prompt = 'Przeanalizuj poniższe CV i wyodrębnij następujące informacje w formacie JSON:\n'
            + '1. Dane osobowe (imię, nazwisko, email, telefon)\n'
            + '2. Wykształcenie (stopień, kierunek, uczelnia, rok ukończenia)\n'
            + '3. Doświadczenie zawodowe (lista stanowisk, firm, okresów zatrudnienia, obowiązków)\n'
            + '4. Umiejętności techniczne (lista)\n'
            + '5. Języki obce (lista z poziomem znajomości)\n'
            + '6. Certyfikaty (lista)\n\n';
        
        // Dodaj informacje o stanowisku jeśli są dostępne
        if (context.hasPositionDetails()) {
            prompt += 'Dodatkowo, oceń dopasowanie kandydata do stanowiska "' + context.positionName + '" na podstawie poniższego opisu i wymaganych umiejętności. '
                + 'Podaj procentowy wynik dopasowania (0-100%) oraz krótkie uzasadnienie.\n\n'
                + 'Opis stanowiska: ' + context.jobDescription + '\n\n'
                + 'Wymagane umiejętności: ' + String.join(context.requiredSkills, ', ') + '\n\n';
        }
        
        prompt += 'CV do analizy:\n' + context.resumeText;
        return prompt;
    }
    
    /**
     * @description Parsuje odpowiedź AI do formatu mapy
     * @param aiResponse Odpowiedź z API AI w formacie tekstowym
     * @return Sparsowana odpowiedź w formie mapy
     */
    private static Map<String, Object> parseAIResponse(String aiResponse) {
        try {
            // Próba bezpośredniego parsowania JSON
            Map<String, Object> parsedResponse = (Map<String, Object>) JSON.deserializeUntyped(aiResponse);
            return parsedResponse;
        } catch (Exception e) {
            Logger.error('Error parsing AI response as JSON', e);
            
            // Jeśli odpowiedź nie jest czystym JSON, próbujemy wyodrębnić JSON z tekstu
            String jsonPattern = '\\{[\\s\\S]*\\}';
            Pattern p = Pattern.compile(jsonPattern);
            Matcher m = p.matcher(aiResponse);
            
            if (m.find()) {
                String jsonStr = m.group(0);
                try {
                    Map<String, Object> extractedJson = (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
                    return extractedJson;
                } catch (Exception ex) {
                    Logger.error('Error parsing extracted JSON', ex);
                }
            }
            
            // Jeśli nie udało się sparsować JSON, zwracamy podstawową strukturę z oryginalną odpowiedzią
            Map<String, Object> fallbackResponse = new Map<String, Object>{
                'rawResponse' => aiResponse,
                'education' => 'Nie udało się wyodrębnić danych z CV',
                'matchScore' => 0
            };
            return fallbackResponse;
        }
    }
    
    /**
     * @description Ekstrahuje tekst z dokumentu CV
     * @param cv Wersja zawartości dokumentu CV
     * @return Wyekstrahowany tekst z dokumentu
     */
    private static String extractTextFromCV(ContentVersion cv) {
        if (cv.FileType == null) {
            throw new AuraHandledException('Typ pliku nie został określony');
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
                SELECT Id, Name, Description__c, Required_Skills__c 
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
     * @throws AuraHandledException jeśli użytkownik nie ma wymaganych uprawnień
     */
    private static void validatePositionAccess() {
        // Walidacja uprawnień CRUD
        if (!Schema.SObjectType.Position__c.isAccessible()) {
            throw new AuraHandledException('Brak uprawnień do odczytu obiektów Position__c');
        }
        
        // Walidacja uprawnień do pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Position__c.fields.getMap();
        for (String field : new List<String>{'Id', 'Name', 'Description__c', 'Required_Skills__c'}) {
            if (!fieldMap.get(field).getDescribe().isAccessible()) {
                throw new AuraHandledException('Brak uprawnień do odczytu pola Position__c.' + field);
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
            throw new AuraHandledException('Typ pliku nie został określony');
        }
        
        String fileType = cv.FileType.toUpperCase();
        
        if (fileType == PDF_TYPE) {
            return parsePDF(cv.VersionData);
        } else {
            throw new AuraHandledException('Nieobsługiwany format pliku: ' + cv.FileType + '. Aplikacja obsługuje tylko pliki PDF.');
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
            // Próba użycia Google Vision API do ekstrakcji tekstu
            String extractedText = extractTextUsingGoogleVision(pdfData, PDF_MIME_TYPE);
            
            // Jeśli Google Vision API zadziałało, zwróć wynik
            if (String.isNotBlank(extractedText)) {
                return extractedText;
            }
            
            // Jeśli Google Vision API nie zadziałało, zwróć informację o błędzie
            throw new AuraHandledException('Nie udało się przetworzyć pliku PDF. Usługa Google Vision API nie zwróciła tekstu. Sprawdź, czy plik PDF zawiera tekst możliwy do odczytania.');
        } catch (AuraHandledException e) {
            throw e; // Przekazujemy dalej wyjątki AuraHandledException
        } catch (Exception e) {
            Logger.error('Error parsing PDF', e);
            throw new AuraHandledException('Błąd podczas przetwarzania pliku PDF: ' + e.getMessage() + '. Sprawdź, czy plik PDF jest poprawny i zawiera tekst możliwy do odczytania.');
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
                return null;
            }
            
            // Przygotuj i wykonaj zapytanie do Google Vision API
            HttpResponse res = callGoogleVisionAPI(documentData, contentType);
            
            // Przetwórz odpowiedź
            return processVisionAPIResponse(res);
        } catch (Exception e) {
            Logger.error('Error using Google Vision API', e);
            return null;
        }
    }
    
    /**
     * @description Waliduje uprawnienia dostępu do obiektu Google_Vision_API_Settings__c
     * @throws AuraHandledException jeśli użytkownik nie ma wymaganych uprawnień
     */
    private static void validateGoogleVisionSettingsAccess() {
        // Walidacja uprawnień CRUD
        if (!Schema.SObjectType.Google_Vision_API_Settings__c.isAccessible()) {
            throw new AuraHandledException('Brak uprawnień do odczytu obiektów Google_Vision_API_Settings__c');
        }
        
        // Walidacja uprawnień do pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Google_Vision_API_Settings__c.fields.getMap();
        if (!fieldMap.get('Vision_API_Key__c').getDescribe().isAccessible()) {
            throw new AuraHandledException('Brak uprawnień do odczytu pola Google_Vision_API_Settings__c.Vision_API_Key__c');
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
            // Pobierz ustawienia Google Vision API
            Google_Vision_API_Settings__c settings = Google_Vision_API_Settings__c.getInstance();
            if (settings == null || String.isBlank(settings.Vision_API_Key__c)) {
                Logger.warn('Google Vision API settings not configured');
                throw new AuraHandledException('Brak skonfigurowanego klucza API dla Google Vision. Skontaktuj się z administratorem.');
            }
            
            // Przygotuj zapytanie do Google Vision API
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Vision/v1/images:annotate?key=' + settings.Vision_API_Key__c);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000); // Zwiększamy timeout do 120 sekund
            
            // Konwersja dokumentu do Base64
            String base64Data = EncodingUtil.base64Encode(documentData);
            
            // Przygotuj ciało zapytania zgodnie z dokumentacją Google Vision API
            Map<String, Object> requestBody = prepareVisionAPIRequestBody(contentType, base64Data);
            req.setBody(JSON.serialize(requestBody));
            
            // Wykonaj zapytanie
            Http http = new Http();
            HttpResponse res;
            
            try {
                res = http.send(req);
                
                // Logowanie dla celów diagnostycznych
                Logger.info('Google Vision API response status: ' + res.getStatusCode());
                Logger.info('Google Vision API response body: ' + res.getBody());
                
                return res;
            } catch (System.CalloutException e) {
                Logger.error('Błąd podczas wywołania Google Vision API: ' + e.getMessage(), e);
                throw new AuraHandledException('Błąd podczas wywołania Google Vision API. Sprawdź, czy Named Credential "Vision" jest poprawnie skonfigurowany. Szczegóły: ' + e.getMessage());
            }
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            Logger.error('Error calling Google Vision API: ' + e.getMessage(), e);
            throw new AuraHandledException('Błąd podczas wywołania Google Vision API: ' + e.getMessage());
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
        return new Map<String, Object>{
            'requests' => new List<Object>{
                new Map<String, Object>{
                    'image' => new Map<String, Object>{
                        'content' => base64Data
                    },
                    'features' => new List<Object>{
                        new Map<String, Object>{
                            'type' => 'DOCUMENT_TEXT_DETECTION',
                            'maxResults' => 1
                        }
                    }
                }
            }
        };
    }
    
    /**
     * @description Przetwarza odpowiedź z Google Vision API
     * @param res Odpowiedź HTTP z Google Vision API
     * @return Wyekstrahowany tekst lub null w przypadku niepowodzenia
     */
    private static String processVisionAPIResponse(HttpResponse res) {
        try {
            // Jeśli odpowiedź nie jest sukcesem, zwróć null
            if (res.getStatusCode() != 200) {
                Logger.error('Google Vision API error: ' + res.getStatusCode() + ' - ' + res.getBody());
                throw new AuraHandledException('Błąd odpowiedzi z Google Vision API. Kod statusu: ' + res.getStatusCode());
            }
            
            // Przetwórz odpowiedź
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            
            // Sprawdź, czy odpowiedź zawiera wyniki
            if (!responseMap.containsKey('responses') || ((List<Object>)responseMap.get('responses')).isEmpty()) {
                Logger.warn('Google Vision API response does not contain responses');
                throw new AuraHandledException('Odpowiedź z Google Vision API nie zawiera wyników.');
            }
            
            // Pobierz pierwszą odpowiedź
            Map<String, Object> firstResponse = (Map<String, Object>)((List<Object>)responseMap.get('responses'))[0];
            
            // Sprawdź, czy odpowiedź zawiera pełny tekst dokumentu
            if (firstResponse.containsKey('fullTextAnnotation')) {
                Map<String, Object> fullTextAnnotation = (Map<String, Object>)firstResponse.get('fullTextAnnotation');
                if (fullTextAnnotation.containsKey('text')) {
                    String extractedText = (String)fullTextAnnotation.get('text');
                    if (String.isNotBlank(extractedText)) {
                        Logger.info('Extracted text from fullTextAnnotation: ' + extractedText.substring(0, Math.min(100, extractedText.length())) + '...');
                        return extractedText;
                    }
                }
            }
            
            // Alternatywnie, sprawdź czy odpowiedź zawiera adnotacje tekstowe
            if (firstResponse.containsKey('textAnnotations') && !((List<Object>)firstResponse.get('textAnnotations')).isEmpty()) {
                Map<String, Object> firstTextAnnotation = (Map<String, Object>)((List<Object>)firstResponse.get('textAnnotations'))[0];
                if (firstTextAnnotation.containsKey('description')) {
                    String extractedText = (String)firstTextAnnotation.get('description');
                    if (String.isNotBlank(extractedText)) {
                        Logger.info('Extracted text from textAnnotations: ' + extractedText.substring(0, Math.min(100, extractedText.length())) + '...');
                        return extractedText;
                    }
                }
            }
            
            Logger.warn('Google Vision API response does not contain text');
            throw new AuraHandledException('Odpowiedź z Google Vision API nie zawiera tekstu. Sprawdź, czy plik PDF zawiera tekst możliwy do odczytania.');
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            Logger.error('Error processing Google Vision API response', e);
            throw new AuraHandledException('Błąd podczas przetwarzania odpowiedzi z Google Vision API: ' + e.getMessage());
        }
    }
    
    /**
     * @description Ta metoda została zmodyfikowana, aby zapobiec używaniu mockowanych danych
     * @throws AuraHandledException zawsze rzuca wyjątek, aby zapobiec używaniu mockowanych danych
     */
    private static String getMockPDFContent() {
        throw new AuraHandledException('Funkcja mockowania danych została wyłączona. Aplikacja obsługuje tylko rzeczywiste dane z plików PDF.');
    }
}
