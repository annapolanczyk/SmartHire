/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 03-12-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class CVAnalysisService {
    
    private static final String CACHE_PARTITION_NAME = 'local.SmartHireCache';
    private static final Integer CACHE_TTL = 86400; // 24 godziny
    
    public static Map<String, Object> analyzeCandidateResume(Id contentDocumentId, Id positionId, Boolean bypassCache) {
        // Walidacja parametrów
        if (contentDocumentId == null || String.isBlank(String.valueOf(contentDocumentId))) {
            System.debug(LoggingLevel.ERROR, '❌ ERROR: contentDocumentId is NULL or empty.');
            throw new AuraHandledException('contentDocumentId cannot be null or empty.');
        }

        // Generowanie klucza cache
        String cacheKey = generateCacheKey(contentDocumentId);
        
        // Próba odczytu z cache
        Map<String, Object> cachedResults = getCachedResults(cacheKey, bypassCache);
        if (cachedResults != null) {
            return cachedResults;
        }

        // Pobierz dane CV i stanowiska
        ContentVersion cv = getContentVersion(contentDocumentId);
        if (cv == null) {
            throw new AuraHandledException('CV document not found');
        }
        
        // Analiza CV
        Map<String, Object> analysisResults = CVAnalysisHelper.analyzeResume(cv, positionId);
        
        // Zapisz wyniki do cache
        saveToCache(cacheKey, analysisResults);

        return analysisResults;
    }
    
    // Generuje klucz cache dla dokumentu CV
    private static String generateCacheKey(Id contentDocumentId) {
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
        return cacheKey;
    }
    
    // Pobiera wyniki z cache
    private static Map<String, Object> getCachedResults(String cacheKey, Boolean bypassCache) {
        if (bypassCache) {
            return null;
        }
        
        Cache.OrgPartition cachePart;
        try {
            cachePart = Cache.Org.getPartition(CACHE_PARTITION_NAME);
            if (cachePart == null) {
                System.debug(LoggingLevel.ERROR, '❌ Cache partition not found: ' + CACHE_PARTITION_NAME);
                return null;
            }
            
            Object cachedObj = cachePart.get(cacheKey);
            if (cachedObj != null) {
                Map<String, Object> cachedResults = (Map<String, Object>)cachedObj;
                System.debug(LoggingLevel.INFO, '✅ Returning cached data for key: ' + cacheKey);
                return cachedResults;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '❌ Error retrieving from cache: ' + e.getMessage());
        }
        return null;
    }
    
    // Zapisuje wyniki do cache
    private static void saveToCache(String cacheKey, Map<String, Object> analysisResults) {
        try {
            Cache.OrgPartition cachePart = Cache.Org.getPartition(CACHE_PARTITION_NAME);
            if (cachePart != null) {
                cachePart.put(cacheKey, analysisResults, CACHE_TTL);
                System.debug(LoggingLevel.INFO, '✅ Cache zapisany dla klucza: ' + cacheKey);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '❌ Error saving to cache: ' + e.getMessage());
        }
    }

    // Pobiera wersję zawartości dokumentu
    private static ContentVersion getContentVersion(Id contentDocumentId) {
        try {
            // Walidacja uprawnień CRUD
            if (!Schema.SObjectType.ContentVersion.isAccessible()) {
                throw new AuraHandledException('Brak uprawnień do odczytu obiektów ContentVersion');
            }
            
            List<ContentVersion> cvList = [
                SELECT VersionData, Title, FileType 
                FROM ContentVersion 
                WHERE ContentDocumentId = :contentDocumentId 
                  AND IsLatest = true 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            return cvList.isEmpty() ? null : cvList[0];
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '❌ Error fetching ContentVersion: ' + e.getMessage());
            return null;
        }
    }

    /**
     * Tworzy zadanie dla rekrutera na podstawie wyników analizy CV
     * @param applicationId - Id aplikacji/zgłoszenia kandydata
     * @param analysisResults - Wyniki analizy CV z AI
     */
    public static void createRecruiterTaskFromAnalysis(Id applicationId, Map<String, Object> analysisResults) {
        if (applicationId == null || analysisResults == null) {
            System.debug(LoggingLevel.ERROR, '❌ ERROR: Nieprawidłowe parametry dla zadania rekrutera');
            return;
        }
        
        try {
            // Pobierz dane o aplikacji
            Job_Application__c application = getApplicationForTask(applicationId);
            if (application == null) {
                return;
            }
            
            // Przygotuj dane zadania
            TaskParams params = new TaskParams();
            params.relatedRecordId = applicationId;
            params.subject = 'Przegląd CV: ' + application.Candidate__r.Name;
            params.priority = determineTaskPriority(analysisResults);
            params.description = buildTaskDescription(application, analysisResults);
            
            // Utwórz zadanie
            createTask(params);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '❌ ERROR: Nie udało się utworzyć zadania rekrutera: ' + e.getMessage());
        }
    }

    /**
     * Klasa pomocnicza do przechowywania parametrów zadania
     */
    private class TaskParams {
        public Id relatedRecordId;
        public String subject;
        public String description;
        public String priority;
    }

    /**
     * Pobiera dane aplikacji dla zadania
     */
    private static Job_Application__c getApplicationForTask(Id applicationId) {
        try {
            // Walidacja uprawnień CRUD
            if (!Schema.SObjectType.Job_Application__c.isAccessible()) {
                throw new AuraHandledException('Brak uprawnień do odczytu obiektów Job_Application__c');
            }
            
            return [
                SELECT Id, Name, Candidate__c, Position__c, Candidate__r.Name, Position__r.Name 
                FROM Job_Application__c 
                WHERE Id = :applicationId 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '❌ ERROR: Nie udało się pobrać danych aplikacji: ' + e.getMessage());
            return null;
        }
    }

    /**
     * Określa priorytet zadania na podstawie wyniku dopasowania
     */
    private static String determineTaskPriority(Map<String, Object> analysisResults) {
        String taskPriority = 'Normal';
        if (analysisResults.containsKey('matchScore')) {
            Object scoreObj = analysisResults.get('matchScore');
            Decimal matchScore = scoreObj instanceof Decimal ? (Decimal)scoreObj : 0;
            if (matchScore > 80) {
                taskPriority = 'High';
            } else if (matchScore < 40) {
                taskPriority = 'Low';
            }
        }
        return taskPriority;
    }

    /**
     * Buduje opis zadania na podstawie wyników analizy
     */
    private static String buildTaskDescription(Job_Application__c application, Map<String, Object> analysisResults) {
        String taskDescription = 'Automatyczna analiza CV kandydata ' + application.Candidate__r.Name + 
                                ' dla stanowiska ' + application.Position__r.Name + '.\n\n';
        
        // Dodaj informacje o umiejętnościach
        taskDescription += buildSkillsSection(analysisResults);
        
        // Dodaj informacje o doświadczeniu
        if (analysisResults.containsKey('experienceYears')) {
            taskDescription += 'Lata doświadczenia: ' + analysisResults.get('experienceYears') + '\n';
        }
        
        // Dodaj informacje o wykształceniu
        if (analysisResults.containsKey('education')) {
            taskDescription += 'Wykształcenie: ' + analysisResults.get('education') + '\n';
        }
        
        return taskDescription;
    }

    /**
     * Buduje sekcję umiejętności dla opisu zadania
     */
    private static String buildSkillsSection(Map<String, Object> analysisResults) {
        // Jeśli nie ma umiejętności, zwróć pusty string
        if (!analysisResults.containsKey('skills')) {
            return '';
        }
        
        Object skillsObj = analysisResults.get('skills');
        if (!(skillsObj instanceof List<Object>)) {
            return '';
        }
        
        List<Object> skills = (List<Object>)skillsObj;
        if (skills.isEmpty()) {
            return '';
        }
        
        // Buduj sekcję umiejętności
        String skillsSection = 'Kluczowe umiejętności:\n';
        
        // Przetwórz każdą umiejętność
        for (Object skillObj : skills) {
            String skillLine = formatSkillLine(skillObj);
            if (String.isNotBlank(skillLine)) {
                skillsSection += skillLine;
            }
        }
        
        return skillsSection + '\n';
    }
    
    /**
     * Formatuje linię dla pojedynczej umiejętności
     * @param skillObj Obiekt reprezentujący umiejętność
     * @return Sformatowana linia tekstu dla umiejętności
     */
    private static String formatSkillLine(Object skillObj) {
        if (!(skillObj instanceof Map<String, Object>)) {
            return '';
        }
        
        Map<String, Object> skill = (Map<String, Object>)skillObj;
        if (!skill.containsKey('name')) {
            return '';
        }
        
        Boolean found = skill.get('found') == true;
        String foundIcon = found ? '✅' : '❌';
        return '- ' + foundIcon + ' ' + skill.get('name') + '\n';
    }

    /**
     * Tworzy zadanie w systemie
     * @param params Parametry zadania
     */
    private static void createTask(TaskParams params) {
        // Walidacja uprawnień CRUD
        if (!Schema.SObjectType.Task.isCreateable()) {
            System.debug(LoggingLevel.ERROR, '❌ ERROR: Brak uprawnień do tworzenia zadań');
            return;
        }
        
        Task newTask = new Task(
            Subject = params.subject,
            Description = params.description,
            Priority = params.priority,
            Status = 'Not Started',
            WhatId = params.relatedRecordId,
            ActivityDate = Date.today().addDays(2)
        );
        
        // Użyj Database.insert z opcją sprawdzania uprawnień
        Database.SaveResult result = Database.insert(newTask, true);
        if (result.isSuccess()) {
            System.debug(LoggingLevel.INFO, '✅ Utworzono zadanie rekrutera: ' + newTask.Id);
        } else {
            System.debug(LoggingLevel.ERROR, '❌ ERROR: Nie udało się utworzyć zadania: ' + result.getErrors()[0].getMessage());
        }
    }
}