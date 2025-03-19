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
 * @last modified on  : 03-19-2025
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
        String prompt = 'Conduct a factual, evidence-based analysis of the following resume. Act as an experienced recruiter specializing in Salesforce technologies. '
            + 'Identify ONLY skills, competencies, qualifications, and professional experience EXPLICITLY mentioned in the document. DO NOT INFER OR ASSUME ANY SKILLS THAT ARE NOT CLEARLY STATED.\n\n'
            + 'Pay special attention to:\n'
            + '1. Technical skills related to Salesforce that are EXPLICITLY mentioned (e.g., Apex, LWC, Visualforce, SOQL, Flow, etc.)\n'
            + '2. Programming and integration skills that are EXPLICITLY mentioned (REST/SOAP API, JavaScript, HTML/CSS, etc.)\n'
            + '3. Soft and interpersonal skills that are EXPLICITLY mentioned\n'
            + '4. Certificates and qualifications, especially related to Salesforce, that are EXPLICITLY mentioned\n'
            + '5. Level of professional experience that is EXPLICITLY mentioned\n'
            + '6. ONLY list skills that are EXPLICITLY stated - DO NOT infer or assume skills that are not directly mentioned\n\n'
            + 'Pay special attention to Salesforce certifications. Look for any mention of standard Salesforce certifications such as:\n'
            + '- Salesforce Administrator\n'
            + '- Advanced Administrator\n'
            + '- Platform App Builder\n'
            + '- Platform Developer I or II\n'
            + '- Sales Cloud Consultant\n'
            + '- Service Cloud Consultant\n'
            + '- Experience Cloud Consultant\n'
            + '- Marketing Cloud certifications\n'
            + '- CPQ Specialist\n'
            + '- Integration Architecture Designer\n'
            + '... and any other Salesforce certifications mentioned\n\n'
            + 'IMPORTANT: Carefully identify ALL certifications mentioned in the resume. List them ONLY in the "certifications" field of the response JSON. DO NOT place Salesforce certifications in the "missingSkills" field even if they appear in the job requirements. Certifications should only be treated as skills if they are explicitly mentioned as skills (not as certifications).\n\n'
            + 'Parse years of experience only if numeric values are explicitly mentioned (e.g., "5 years of Apex experience", "worked with Salesforce for 3 years"). Do not infer years of experience from employment periods unless explicitly stated.\n\n'
            + 'IMPORTANT: FOR DATA PRIVACY REASONS, DO NOT EXTRACT OR INCLUDE ANY PERSONAL INFORMATION such as names, email addresses, phone numbers, or specific company names. We are only interested in skills, experience levels, and certifications - not personal or identifying information.\n\n'
            + 'Extract the following information in JSON format:\n'
            + '1. yearsOfExperience (general professional experience in years if explicitly mentioned)\n'
            + '2. education (only degree level and field of study, NO school names or graduation years)\n'
            + '3. technicalSkills (list, ONLY include skills that are EXPLICITLY mentioned in the resume)\n'
            + '4. languages (list with proficiency level)\n'
            + '5. certifications (list, with special attention to Salesforce certifications - make sure ALL certifications are included here, not in missingSkills)\n'
            + '6. matchScore (percentage match score from 0 to 100, even without position data provide an estimated skill level score)\n';
            
        // Modify the prompt to emphasize matching skills based on position description
        if (context.hasPositionDetails()) {
            prompt += '7. matchedSkills (array of skills that are EXPLICITLY mentioned in BOTH the resume AND the position description. DO NOT include any skills that are not explicitly mentioned in the resume, even if they appear in the position description. For matchedSkills, prioritize ordering based on importance from the job description.)\n';
        } else {
            prompt += '7. matchedSkills (array of skills EXPLICITLY mentioned in the resume that are relevant to Salesforce development. DO NOT include assumed or inferred skills)\n';
        }
            
        prompt += '8. additionalSkills (array of supplementary skills that are EXPLICITLY mentioned in the resume)\n'
            + '9. analysisSummary (concise summary of candidate\'s profile, 2-3 sentences max, based ONLY on information explicitly stated in the resume, WITHOUT mentioning specific company names or personal details)\n'
            + '10. keyHighlights (bullet points of 3-5 most important strengths that are EXPLICITLY mentioned in the resume, DO NOT end with periods, DO NOT include company names or personal details)\n'
            + '11. potentialConcerns (areas where the candidate might lack experience based on information in the resume, DO NOT end with periods)\n';
            
        // Modify the prompt to emphasize missing skills based on position description
        if (context.hasPositionDetails()) {
            prompt += '12. missingSkills (ONLY include skills that are EXPLICITLY mentioned in the position description text but are NOT found in the resume. DO NOT list any skills that are not clearly mentioned in the position description. IMPORTANT: Do NOT include common Salesforce skills like Apex, LWC, Visualforce, SOQL, Flow, etc. unless they are EXPLICITLY mentioned in the position description. Do NOT include Salesforce certifications here - they should ONLY be listed in the certifications field)\n';
        } else {
            prompt += '12. missingSkills (this should be an empty array [] since there is no position description to compare against. DO NOT include any common Salesforce skills here if they are not from a position description)\n';
        }
            
        prompt += '13. recommendationLevel (string value, one of: "High", "Medium", "Low")\n\n'
            + 'Handle incomplete data gracefully. If certain information is missing from the resume, include null values or empty arrays for those fields in the JSON but do not make assumptions about the missing data.\n\n';
        
        // Add position information if available
        if (context.hasPositionDetails()) {
            prompt += 'Additionally, evaluate the candidate\'s fit for the position "' + context.positionName + '" based ONLY on the skills and experience EXPLICITLY mentioned in their resume, compared with the description and required skills below. '
                + 'When evaluating the match, read the position description carefully and only match with skills that are EXPLICITLY mentioned in the candidate\'s resume.\n\n'
                + 'Position description: ' + context.jobDescription + '\n\n'
                + 'Return the results in a single, valid JSON object with the sections described above. '
                + 'IMPORTANT: Be 100% factual and only include skills that are EXPLICITLY mentioned in the resume. Do not exaggerate, infer, or assume skills that are not clearly stated in the resume. '
                + 'If there are few or no Salesforce skills mentioned, that\'s okay - report accurately what is found. '
                + 'matchedSkills should ONLY include skills that appear in BOTH the position description AND are explicitly mentioned in the candidate resume. '
                + 'missingSkills should ONLY include skills mentioned in the position description that are not found in the resume. DO NOT list any "standard" or "expected" skills unless they are actually mentioned in the position description. '
                + 'Remember that Salesforce certifications should ONLY be listed in the certifications field, not in missingSkills field.\n\n';
        } else {
            prompt += 'Return the results in a single, valid JSON object with the sections described above. '
                + 'IMPORTANT: Be 100% factual and only include skills that are EXPLICITLY mentioned in the resume. Do not exaggerate, infer, or assume skills that are not clearly stated. '
                + 'For the missingSkills field, return an empty array since there is no position description to compare against. '
                + 'Remember to list ALL certifications in the certifications field, not in missingSkills field.\n\n';
        }
        
        // Add resume content
        prompt += 'Resume text:\n"""\n' + context.resumeText + '\n"""\n\n'
            + 'Validate JSON output before completion. If invalid, retry until you can produce a valid, well-formed JSON. REMEMBER, DO NOT INCLUDE ANY PERSONAL INFORMATION OR COMPANY NAMES IN YOUR RESPONSE.';
        
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
     * @description Ekstrahuje tekst z CV
     * @param cv Wersja zawartości dokumentu CV
     * @return Tekst CV
     */
    private static String extractTextFromCV(ContentVersion cv) {
        try {
            // Sprawdź format pliku
            String fileType = determineFileType(cv);
            System.debug(LoggingLevel.DEBUG, 'Typ pliku: ' + fileType);
            
            // Obsługa plików PDF
        if (fileType == PDF_TYPE) {
            return parsePDF(cv.VersionData);
            } 
            // Obsługa innych typów plików
            else if (fileType == TXT_TYPE) {
                return cv.VersionData.toString();
        } else {
                throw new CVAnalysisException('Nieobsługiwany format pliku: ' + fileType + '. Aplikacja obsługuje tylko pliki PDF i TXT.');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Błąd podczas ekstrakcji tekstu z CV: ' + e.getMessage());
            throw new CVAnalysisException('Błąd podczas ekstrakcji tekstu z CV: ' + e.getMessage());
        }
    }
    
    /**
     * @description Parsuje plik PDF i ekstrahuje tekst
     * @param pdfData Dane PDF w formacie Blob
     * @return Wyekstrahowany tekst
     */
    private static String parsePDF(Blob pdfData) {
        try {
            // Sprawdź, czy dane PDF nie są puste
            if (pdfData == null || pdfData.size() == 0) {
                Logger.error('Dane PDF są puste', null);
                throw new CVAnalysisException('Plik PDF jest pusty lub uszkodzony. Proszę sprawdzić plik i spróbować ponownie.');
            }
            
            Integer pdfSize = pdfData.size();
            Logger.info('CVAnalysisHelper', 'parsePDF', 'Rozmiar pliku PDF: ' + pdfSize + ' bajtów');
            
            // Sprawdź, czy plik nie jest zbyt mały (potencjalnie uszkodzony)
            if (pdfSize < 100) {
                Logger.warn('CVAnalysisHelper', 'parsePDF', 'Plik PDF jest bardzo mały (' + pdfSize + ' bajtów), może być uszkodzony lub pusty');
            }
            
            // Zapisz pierwsze kilka bajtów dla diagnostyki
            String pdfHeader = EncodingUtil.base64Encode(pdfData).substring(0, Math.min(20, pdfSize));
            Logger.info('CVAnalysisHelper', 'parsePDF', 'Nagłówek pliku PDF (Base64): ' + pdfHeader);
            
            // 1. Próba użycia serwisu PDF Extractor
            try {
                String extractedText = extractTextUsingPdfExtractor(pdfData);
                if (String.isNotBlank(extractedText)) {
                    Logger.info('CVAnalysisHelper', 'parsePDF', 'Pomyślnie wyekstrahowano tekst z PDF. Długość tekstu: ' + extractedText.length());
                    return extractedText;
                        } else {
                    Logger.warn('CVAnalysisHelper', 'parsePDF', 'PDF Extractor zwrócił pusty tekst');
                        }
                    } catch (Exception extEx) {
                        Logger.error('CVAnalysisHelper', 'parsePDF', 'Błąd podczas używania usługi PDF Extractor: ' + extEx.getMessage(), extEx);
                // Kontynuuj do alternatywnej metody
            }
                        
            // 2. Próba alternatywnej metody jako backup
                        try {
                            String alternativeText = extractTextAlternative(pdfData);
                            if (String.isNotBlank(alternativeText)) {
                                Logger.info('CVAnalysisHelper', 'parsePDF', 'Pomyślnie wyekstrahowano tekst z PDF używając alternatywnej metody. Długość tekstu: ' + alternativeText.length());
                                return alternativeText;
                            } else {
                                Logger.warn('CVAnalysisHelper', 'parsePDF', 'Alternatywna metoda ekstrakcji tekstu zwróciła pusty tekst');
                            }
                        } catch (Exception altEx) {
                            Logger.error('CVAnalysisHelper', 'parsePDF', 'Błąd podczas używania alternatywnej metody ekstrakcji tekstu: ' + altEx.getMessage(), altEx);
                throw new CVAnalysisException('Nie udało się wyekstrahować tekstu z pliku PDF. Sprawdź, czy plik zawiera tekst możliwy do odczytania.');
            }
            
            // Jeśli żadna metoda nie zadziałała
            throw new CVAnalysisException('Nie udało się wyekstrahować tekstu z pliku PDF używając żadnej z dostępnych metod. Sprawdź, czy plik zawiera tekst możliwy do odczytania.');
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
     * @description Sprawdza format pliku
     * @param cv Wersja zawartości dokumentu CV
     * @return Typ pliku
     */
    private static String determineFileType(ContentVersion cv) {
        if (cv.FileType == null) {
            throw new CVAnalysisException('Typ pliku nie został określony');
        }
        return cv.FileType.toUpperCase();
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