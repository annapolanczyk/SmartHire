public with sharing class CVAnalysisService {
    
    private static final String CACHE_PARTITION_NAME = 'local.SmartHireCache';
    private static final Integer CACHE_TTL = 86400; // 24 godziny
    
    public static Map<String, Object> analyzeCandidateResume(Id contentDocumentId, Id positionId, Boolean bypassCache) {
        // 1️⃣ SPRAWDŹ, CZY contentDocumentId JEST POPRAWNY
        if (contentDocumentId == null || String.isBlank(String.valueOf(contentDocumentId))) {
            System.debug(LoggingLevel.ERROR, '❌ ERROR: contentDocumentId is NULL or empty.');
            throw new AuraHandledException('contentDocumentId cannot be null or empty.');
        }

        // 2️⃣ GENERUJ KLUCZ CACHE - TYLKO LITERY I CYFRY
        // Usuwamy wszystkie znaki niealfanumeryczne i skracamy klucz do maksymalnie 40 znaków
        String cacheKey = String.valueOf(contentDocumentId).replaceAll('[^a-zA-Z0-9]', '');
        if (String.isNotBlank(cacheKey)) {
            cacheKey = 'CV' + cacheKey;
            if (cacheKey.length() > 40) { 
                cacheKey = cacheKey.substring(0, 40);
            }
            System.debug(LoggingLevel.INFO, '✅ Final Cache Key: ' + cacheKey);
        } else {
            cacheKey = 'CV' + String.valueOf(Datetime.now().getTime());
            System.debug(LoggingLevel.WARN, '⚠️ Using timestamp-based cache key: ' + cacheKey);
        }

        // 3️⃣ SPRAWDŹ CZY PLATFORM CACHE JEST DOSTĘPNY
        Cache.OrgPartition cachePart;
        try {
            cachePart = Cache.Org.getPartition(CACHE_PARTITION_NAME);
            if (cachePart == null) {
                System.debug(LoggingLevel.ERROR, '❌ Cache partition not found: ' + CACHE_PARTITION_NAME);
                bypassCache = true;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '❌ Error accessing cache: ' + e.getMessage());
            bypassCache = true;
        }

        // 4️⃣ PRÓBA ODCZYTU DANYCH Z CACHE
        if (!bypassCache && cachePart != null) {
            try {
                Object cachedObj = cachePart.get(cacheKey);
                if (cachedObj != null) {
                    Map<String, Object> cachedResults = (Map<String, Object>)cachedObj;
                    System.debug(LoggingLevel.INFO, '✅ Returning cached data for key: ' + cacheKey);
                    return cachedResults;
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, '❌ Error retrieving from cache: ' + e.getMessage());
                // Kontynuuj bez cache
            }
        }

        // 5️⃣ POBIERZ DANE CV
        ContentVersion cv = getContentVersion(contentDocumentId);
        if (cv == null) {
            throw new AuraHandledException('CV document not found');
        }

        // 6️⃣ KONWERSJA CV NA TEKST - IMPLEMENTACJA TYMCZASOWA DLA DEBUGOWANIA
        String resumeText;
        try {
            // Uproszczona wersja, która nie wymaga zewnętrznych usług (dla debugowania)
            resumeText = extractTextFromCV(cv);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '❌ Error converting document: ' + e.getMessage());
            throw new AuraHandledException('Error extracting text from document: ' + e.getMessage());
        }
        
        String jobDescription = '';
        List<String> requiredSkills = new List<String>();

        // 7️⃣ POBIERZ DANE STANOWISKA, JEŚLI PODANO ID
        if (positionId != null) {
            Position__c position = getPosition(positionId);
            if (position != null) {
                jobDescription = position.Description__c != null ? position.Description__c : '';
                if (String.isNotBlank(position.Required_Skills__c)) {
                    requiredSkills = parseSkills(position.Required_Skills__c);
                }
            }
        }

        // 8️⃣ ANALIZA CV PRZY UŻYCIU AI - TYMCZASOWE MOCKI
        Map<String, Object> analysisResults = mockAnalysisResults(resumeText, jobDescription, requiredSkills);

        // 9️⃣ ZAPIS DANYCH DO CACHE
        if (cachePart != null) {
            try {
                cachePart.put(cacheKey, analysisResults, CACHE_TTL);
                System.debug(LoggingLevel.INFO, '✅ Cache zapisany dla klucza: ' + cacheKey);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, '❌ Error saving to cache: ' + e.getMessage());
                // Kontynuuj bez zapisywania cache
            }
        }

        return analysisResults;
    }

    // Uproszczony ekstraktor tekstu dla debugowania
    private static String extractTextFromCV(ContentVersion cv) {
        if (cv.FileType == null) {
            return 'Sample CV content for ' + cv.Title;
        }
        
        // W fazie debugowania zwraca zaślepkę
        return 'Sample CV content for ' + cv.Title + ' (Format: ' + cv.FileType + ')';
    }
    
    // Tymczasowa implementacja dla fazy debugowania
    private static Map<String, Object> mockAnalysisResults(String resumeText, String jobDescription, List<String> requiredSkills) {
        Map<String, Object> results = new Map<String, Object>();
        
        // Podstawowe dane
        results.put('candidateName', 'Anna Polanczyk');
        results.put('candidateEmail', 'anna.polanczyk@example.com');
        results.put('candidatePhone', '+48 123 456 789');
        
        // Umiejętności
        List<Map<String, Object>> skills = new List<Map<String, Object>>();
        for (String skill : requiredSkills) {
            skills.add(new Map<String, Object>{
                'name' => skill,
                'found' => Math.random() > 0.3, // Losowo określa czy umiejętność znaleziona
                'confidence' => Math.random() * 100
            });
        }
        results.put('skills', skills);
        
        // Dodatkowe informacje
        results.put('experienceYears', 5);
        results.put('education', 'Master\'s Degree in Computer Science');
        results.put('matchScore', Math.random() * 100);
        
        return results;
    }

    private static ContentVersion getContentVersion(Id contentDocumentId) {
        try {
            List<ContentVersion> cvList = [
                SELECT VersionData, Title, FileType 
                FROM ContentVersion 
                WHERE ContentDocumentId = :contentDocumentId 
                  AND IsLatest = true 
                LIMIT 1
            ];
            return cvList.isEmpty() ? null : cvList[0];
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '❌ Error fetching ContentVersion: ' + e.getMessage());
            return null;
        }
    }

    private static Position__c getPosition(Id positionId) {
        try {
            List<Position__c> positionList = [
                SELECT Description__c, Required_Skills__c 
                FROM Position__c 
                WHERE Id = :positionId 
                LIMIT 1
            ];
            return positionList.isEmpty() ? null : positionList[0];
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '❌ Error fetching Position: ' + e.getMessage());
            return null;
        }
    }

    private static List<String> parseSkills(String skillsString) {
        if (String.isBlank(skillsString)) return new List<String>();
        
        List<String> skills = skillsString.split(',');
        for (Integer i = 0; i < skills.size(); i++) {
            skills[i] = skills[i].trim();
        }
        return skills;
    }

    // Oryginalne metody parsowania - tymczasowo nieużywane
    private static String convertToText(ContentVersion cv) {
        if (cv.FileType == null) {
            throw new AuraHandledException('File type is not specified');
        }
        
        if (cv.FileType.equalsIgnoreCase('PDF')) {
            return parsePDF(cv.VersionData);
        } else if (cv.FileType.equalsIgnoreCase('DOCX') || cv.FileType.equalsIgnoreCase('DOC')) {
            return parseWord(cv.VersionData);
        } else if (cv.FileType.equalsIgnoreCase('TXT')) {
            // Poprawna konwersja Blob do String z określonym kodowaniem
            return EncodingUtil.base64Decode(EncodingUtil.base64Encode(cv.VersionData)).toString();
        }
        throw new AuraHandledException('Unsupported file format: ' + cv.FileType);
    }

    private static String parsePDF(Blob pdfData) {
        try {
            // UWAGA: Ta metoda wymaga prawidłowego skonfigurowania Named Credential "PDF_Parser_Service"
            // Tymczasowo zwracamy zaślepkę zamiast rzeczywistego callout dla celów debugowania
            return 'Sample PDF content (parsePDF method)';
            
            /*
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:PDF_Parser_Service');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/pdf');
            req.setBodyAsBlob(pdfData);
            req.setTimeout(120000); // 2 minuty timeout
        
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200) {
                return res.getBody();
            }
            throw new AuraHandledException('Error parsing PDF: Status ' + res.getStatusCode() + ' - ' + res.getStatus());
            */
        } catch (Exception e) {
            throw new AuraHandledException('PDF parsing service error: ' + e.getMessage());
        }
    }

    private static String parseWord(Blob wordData) {
        try {
            // UWAGA: Ta metoda wymaga prawidłowego skonfigurowania Named Credential "DOCX_Parser_Service"
            // Tymczasowo zwracamy zaślepkę zamiast rzeczywistego callout dla celów debugowania
            return 'Sample DOCX content (parseWord method)';
            
            /*
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:DOCX_Parser_Service');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
            req.setBodyAsBlob(wordData);
            req.setTimeout(120000); // 2 minuty timeout
        
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200) {
                return res.getBody();
            }
            throw new AuraHandledException('Error parsing Word document: Status ' + res.getStatusCode() + ' - ' + res.getStatus());
            */
        } catch (Exception e) {
            throw new AuraHandledException('Word parsing service error: ' + e.getMessage());
        }
    }
}