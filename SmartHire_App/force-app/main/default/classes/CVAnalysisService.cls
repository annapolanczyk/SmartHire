/**
 * Klasa usługowa do analizy CV kandydatów
 * @author SmartHire Team
 */
public with sharing class CVAnalysisService {
    
    // Stałe dla cache
    private static final String CACHE_PARTITION_NAME = 'SmartHireCache';
    private static final Integer ORG_CACHE_TTL = 86400; // 24 godziny
    private static final Integer SESSION_CACHE_TTL = 7200; // 2 godziny
    private static final Integer MAX_CACHE_SIZE = 100000; // Maksymalny rozmiar danych w cache (w bajtach)
    
    /**
     * Analizuje CV kandydata i zwraca wyniki analizy
     * @param contentDocumentId Id dokumentu CV
     * @param positionId Id stanowiska (opcjonalnie)
     * @param bypassCache Czy pominąć cache
     * @return Map<String, Object> Wyniki analizy CV
     */
    public static Map<String, Object> analyzeCandidateResume(Id contentDocumentId, Id positionId, Boolean bypassCache) {
        try {
            // Walidacja parametru wejściowego
            if (contentDocumentId == null) {
                System.debug(LoggingLevel.ERROR, 'Błąd: contentDocumentId nie może być null');
                throw new CVAnalysisException('Nie podano ID dokumentu CV');
            }
            
            System.debug(LoggingLevel.INFO, 'Rozpoczynam analizę CV dla dokumentu: ' + contentDocumentId);
            
            // Pobierz informacje o dokumencie CV
            ContentVersion cv = getContentVersion(contentDocumentId);
            if (cv == null) {
                throw new CVAnalysisException('Nie znaleziono dokumentu CV o ID: ' + contentDocumentId);
            }
            
            System.debug(LoggingLevel.INFO, 'Znaleziono dokument CV: ' + cv.Title + ', typ: ' + cv.FileType + ', rozmiar: ' + cv.ContentSize);
            
            // Generuj klucz cache
            String cacheKey = generateCacheKey(contentDocumentId);
            if (positionId != null) {
                cacheKey += '_' + positionId;
            }
            System.debug(LoggingLevel.INFO, 'Wygenerowany klucz cache: ' + cacheKey);
            
            // Próba pobrania wyników z cache, jeśli nie pomijamy cache
            if (!bypassCache) {
                Map<String, Object> cachedResults = getCachedResults(cacheKey);
                if (cachedResults != null) {
                    System.debug(LoggingLevel.INFO, 'Znaleziono wyniki w cache dla klucza: ' + cacheKey);
                    return cachedResults;
                }
            } else {
                System.debug(LoggingLevel.INFO, 'Pomijam cache zgodnie z parametrem bypassCache');
            }
            
            System.debug(LoggingLevel.INFO, 'Brak wyników w cache lub cache pominięty, wykonuję analizę CV...');
            
            // Wykonaj analizę CV
            Map<String, Object> results = CVAnalysisHelper.analyzeResume(cv, positionId);
            
            // Zapisz wyniki do cache, jeśli nie pomijamy cache
            if (results != null && !bypassCache) {
                saveToCache(cacheKey, results);
            }
            
            return results;
        } catch (CVAnalysisHelper.CVAnalysisException e) {
            System.debug(LoggingLevel.ERROR, 'Błąd podczas analizy CV: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            throw new CVAnalysisException('Błąd podczas analizy CV: ' + e.getMessage());
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Błąd podczas analizy CV: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            throw new CVAnalysisException('Błąd podczas analizy CV: ' + e.getMessage());
        }
    }
    
    /**
     * Analizuje CV kandydata i zwraca wyniki analizy
     * @param contentDocumentId Id dokumentu CV
     * @return Map<String, Object> Wyniki analizy CV
     */
    public static Map<String, Object> analyzeCandidateResume(Id contentDocumentId) {
        return analyzeCandidateResume(contentDocumentId, null, false);
    }
    
    /**
     * Tworzy zadanie dla rekrutera na podstawie wyników analizy CV
     * @param applicationId Id aplikacji
     * @param analysisResults Wyniki analizy CV
     */
    public static void createRecruiterTaskFromAnalysis(Id applicationId, Map<String, Object> analysisResults) {
        try {
            if (applicationId == null || analysisResults == null) {
                System.debug(LoggingLevel.ERROR, 'Błąd: applicationId lub analysisResults nie może być null');
                return;
            }
            
            // Sprawdź uprawnienia
            SecurityUtils.checkReadAccess(Job_Application__c.SObjectType, 
                new List<String>{'Id', 'Name', 'Candidate__c', 'Position__c'});
            SecurityUtils.checkCreateAccess(Task.SObjectType, 
                new List<String>{'Subject', 'Description', 'WhatId', 'Status', 'Priority', 'ActivityDate'});
            
            // Pobierz dane aplikacji
            Job_Application__c app = [
                SELECT Id, Name, Candidate__c, Position__c, Position__r.Name
                FROM Job_Application__c
                WHERE Id = :applicationId
                LIMIT 1
            ];
            
            // Przygotuj opis zadania
            String taskDescription = 'Wyniki analizy CV dla aplikacji: ' + app.Name + '\n\n';
            
            // Dodaj informacje o dopasowaniu, jeśli istnieją
            if (analysisResults.containsKey('matchScore')) {
                Object matchScore = analysisResults.get('matchScore');
                taskDescription += 'Dopasowanie do stanowiska: ' + matchScore + '\n\n';
            }
            
            // Dodaj informacje o umiejętnościach, jeśli istnieją
            if (analysisResults.containsKey('skills')) {
                Object skills = analysisResults.get('skills');
                if (skills instanceof List<Object>) {
                    List<Object> skillsList = (List<Object>)skills;
                    taskDescription += 'Umiejętności kandydata:\n';
                    for (Object skill : skillsList) {
                        taskDescription += '- ' + String.valueOf(skill) + '\n';
                    }
                    taskDescription += '\n';
                }
            }
            
            // Dodaj informacje o doświadczeniu, jeśli istnieją
            if (analysisResults.containsKey('experience')) {
                Object experience = analysisResults.get('experience');
                taskDescription += 'Doświadczenie zawodowe:\n' + String.valueOf(experience) + '\n\n';
            }
            
            // Utwórz zadanie
            Task task = new Task(
                Subject = 'Przegląd CV - ' + app.Position__r.Name,
                Description = taskDescription,
                WhatId = applicationId,
                Status = 'Not Started',
                Priority = 'Normal',
                ActivityDate = Date.today().addDays(2)
            );
            
            insert task;
            System.debug(LoggingLevel.INFO, 'Utworzono zadanie dla rekrutera: ' + task.Id);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Błąd podczas tworzenia zadania dla rekrutera: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * Pobiera wersję zawartości dokumentu
     * @param contentDocumentId Id dokumentu
     * @return ContentVersion Wersja zawartości dokumentu
     */
    private static ContentVersion getContentVersion(Id contentDocumentId) {
        List<ContentVersion> versions = [
            SELECT Id, Title, FileType, ContentSize, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            AND IsLatest = true
            LIMIT 1
        ];
        
        return versions.isEmpty() ? null : versions[0];
    }
    
    /**
     * Generuje klucz cache dla dokumentu CV
     * @param contentDocumentId Id dokumentu CV
     * @return String Klucz cache
     */
    private static String generateCacheKey(Id contentDocumentId) {
        // Prefiks CV + ID dokumentu, usunięcie znaków niealfanumerycznych
        String rawKey = 'CV' + contentDocumentId;
        return sanitizeCacheKey(rawKey);
    }
    
    /**
     * Sanityzuje klucz cache, usuwając znaki niealfanumeryczne
     * @param key Oryginalny klucz
     * @return String Sanityzowany klucz
     */
    private static String sanitizeCacheKey(String key) {
        if (String.isBlank(key)) {
            return '';
        }
        
        // Usuń wszystkie znaki niealfanumeryczne
        return key.replaceAll('[^a-zA-Z0-9]', '');
    }
    
    /**
     * Pobiera wyniki analizy CV z cache
     * @param cacheKey Klucz cache
     * @return Map<String, Object> Wyniki analizy CV z cache lub null jeśli nie znaleziono
     */
    private static Map<String, Object> getCachedResults(String cacheKey) {
        try {
            // Walidacja klucza cache
            if (String.isBlank(cacheKey)) {
                System.debug(LoggingLevel.WARN, 'Pusty klucz cache, pomijam odczyt z cache');
                return null;
            }
            
            // Sanityzacja klucza cache
            String sanitizedKey = sanitizeCacheKey(cacheKey);
            if (String.isBlank(sanitizedKey)) {
                System.debug(LoggingLevel.WARN, 'Klucz cache po sanityzacji jest pusty, pomijam odczyt z cache');
                return null;
            }
            
            System.debug(LoggingLevel.INFO, 'Próba odczytu z cache dla klucza: ' + sanitizedKey);
            
            // Próba odczytu z Trial cache (zamiast Organization)
            try {
                Cache.OrgPartition orgPart = Cache.Org.getPartition(CACHE_PARTITION_NAME);
                if (orgPart != null) {
                    // Używamy typu Trial zamiast Organization, ale bez parametru Cache.Visibility
                    Object cachedValue = orgPart.get(sanitizedKey);
                    if (cachedValue != null) {
                        System.debug(LoggingLevel.INFO, 'Znaleziono wyniki w Trial cache');
                        return (Map<String, Object>)cachedValue;
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Błąd podczas odczytu z Trial cache: ' + e.getMessage());
                // Kontynuuj do Session cache
            }
            
            // Próba odczytu z Session cache
            try {
                Cache.SessionPartition sessionPart = Cache.Session.getPartition(CACHE_PARTITION_NAME);
                if (sessionPart != null) {
                    Object cachedValue = sessionPart.get(sanitizedKey);
                    if (cachedValue != null) {
                        System.debug(LoggingLevel.INFO, 'Znaleziono wyniki w Session cache');
                        return (Map<String, Object>)cachedValue;
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Błąd podczas odczytu z Session cache: ' + e.getMessage());
            }
            
            System.debug(LoggingLevel.INFO, 'Nie znaleziono wyników w cache');
            return null;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Błąd podczas pobierania wyników z cache: ' + e.getMessage());
            return null; // Zwróć null, aby kontynuować analizę bez cache
        }
    }
    
    /**
     * Zapisuje wyniki analizy CV do cache
     * @param cacheKey Klucz cache
     * @param results Wyniki analizy CV
     */
    private static void saveToCache(String cacheKey, Map<String, Object> results) {
        try {
            // Walidacja parametrów
            if (String.isBlank(cacheKey) || results == null) {
                System.debug(LoggingLevel.WARN, 'Pusty klucz cache lub wyniki, pomijam zapis do cache');
                return;
            }
            
            // Sanityzacja klucza cache
            String sanitizedKey = sanitizeCacheKey(cacheKey);
            if (String.isBlank(sanitizedKey)) {
                System.debug(LoggingLevel.WARN, 'Klucz cache po sanityzacji jest pusty, pomijam zapis do cache');
                return;
            }
            
            System.debug(LoggingLevel.INFO, 'Próba zapisu do cache dla klucza: ' + sanitizedKey);
            
            // Optymalizacja danych przed zapisem do cache
            Map<String, Object> optimizedResults = optimizeDataForCache(results);
            
            // Próba zapisu do Trial cache (zamiast Organization)
            boolean savedToTrialCache = false;
            try {
                Cache.OrgPartition orgPart = Cache.Org.getPartition(CACHE_PARTITION_NAME);
                if (orgPart != null) {
                    // Używamy typu Trial zamiast Organization, ale bez parametru Cache.Visibility
                    orgPart.put(sanitizedKey, optimizedResults, ORG_CACHE_TTL);
                    savedToTrialCache = true;
                    System.debug(LoggingLevel.INFO, 'Zapisano wyniki do Trial cache');
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Błąd podczas zapisu do Trial cache: ' + e.getMessage());
                // Kontynuuj do Session cache
            }
            
            // Jeśli nie udało się zapisać do Trial cache, spróbuj Session cache
            if (!savedToTrialCache) {
                try {
                    Cache.SessionPartition sessionPart = Cache.Session.getPartition(CACHE_PARTITION_NAME);
                    if (sessionPart != null) {
                        sessionPart.put(sanitizedKey, optimizedResults, SESSION_CACHE_TTL);
                        System.debug(LoggingLevel.INFO, 'Zapisano wyniki do Session cache');
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'Błąd podczas zapisu do Session cache: ' + e.getMessage());
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Błąd podczas zapisywania wyników do cache: ' + e.getMessage());
            // Kontynuuj bez cache
        }
    }
    
    /**
     * Optymalizuje dane przed zapisem do cache
     * @param results Wyniki analizy CV
     * @return Map<String, Object> Zoptymalizowane wyniki
     */
    private static Map<String, Object> optimizeDataForCache(Map<String, Object> results) {
        // Implementacja optymalizacji danych, np. usunięcie zbędnych danych
        // lub konwersja do mniejszego formatu
        return results;
    }
    
    /**
     * Klasa wyjątku dla błędów analizy CV
     */
    public class CVAnalysisException extends Exception {}
}