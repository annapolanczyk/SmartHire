/**
 * Controller for CV Analysis operations
 */
public with sharing class CVAnalysisController {
    
    /**
     * Analyze candidate resume
     * @param contentDocumentId ID of the resume document
     * @param positionId Position Id for matching
     * @param bypassCache Whether to bypass cache
     * @return Map with analysis results
     */
    @AuraEnabled
    public static Map<String, Object> analyzeCandidateResume(Id contentDocumentId, Id positionId, Boolean bypassCache) {
        try {
            return CVAnalysisService.analyzeCandidateResume(contentDocumentId, positionId, bypassCache != null ? bypassCache : false);
        } catch (CVAnalysisService.CVAnalysisException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (CVAnalysisHelper.CVAnalysisException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Save analysis results to the record
     * @param recordId ID of the record (Job_Application__c or Candidate__c)
     * @param analysisResults JSON string with analysis results
     * @return ID of the created AiAnalysisResult__c record
     */
    @AuraEnabled
    public static Id saveAnalysisResults(Id recordId, String analysisResults) {
        try {
            // Logowanie danych wejściowych
            System.debug(LoggingLevel.INFO, '=== saveAnalysisResults - START ===');
            System.debug(LoggingLevel.INFO, 'saveAnalysisResults - recordId: ' + recordId);
            System.debug(LoggingLevel.INFO, 'saveAnalysisResults - analysisResults length: ' + (analysisResults != null ? analysisResults.length() : 0));
            
            // Sprawdź typ rekordu
            String objectType = String.valueOf(recordId.getSobjectType());
            System.debug(LoggingLevel.INFO, 'saveAnalysisResults - objectType: ' + objectType);
            
            try {
                // Parsuj wyniki analizy
                System.debug(LoggingLevel.INFO, 'saveAnalysisResults - attempting to deserialize JSON');
                Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(analysisResults);
                System.debug(LoggingLevel.INFO, 'saveAnalysisResults - results deserialized successfully with ' + results.size() + ' keys');
                
                // Logowanie kluczy w wynikach analizy
                System.debug(LoggingLevel.INFO, 'saveAnalysisResults - result keys: ' + results.keySet());
                
                if (objectType == 'Job_Application__c') {
                    System.debug(LoggingLevel.INFO, 'saveAnalysisResults - calling saveJobApplicationResults');
                    return saveJobApplicationResults(recordId, analysisResults, results);
                } 
                else if (objectType == 'Candidate__c') {
                    System.debug(LoggingLevel.INFO, 'saveAnalysisResults - calling saveCandidateResults');
                    return saveCandidateResults(recordId, analysisResults, results);
                } 
                else {
                    System.debug(LoggingLevel.ERROR, 'saveAnalysisResults - unsupported record type: ' + objectType);
                    throw new AuraHandledException('Unsupported record type: ' + objectType);
                }
            } catch (JSONException jsonEx) {
                System.debug(LoggingLevel.ERROR, 'saveAnalysisResults - JSON deserialization error: ' + jsonEx.getMessage());
                System.debug(LoggingLevel.ERROR, 'saveAnalysisResults - JSON sample: ' + (analysisResults != null && analysisResults.length() > 100 ? analysisResults.substring(0, 100) + '...' : analysisResults));
                throw new AuraHandledException('Error parsing analysis results JSON: ' + jsonEx.getMessage());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'saveAnalysisResults - Exception: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'saveAnalysisResults - Exception type: ' + e.getTypeName());
            System.debug(LoggingLevel.ERROR, 'saveAnalysisResults - Stack trace: ' + e.getStackTraceString());
            Logger.error('CVAnalysisController', 'saveAnalysisResults', 'Error saving analysis results: ' + e.getMessage(), e);
            throw new AuraHandledException('Failed to save analysis results: ' + e.getMessage());
        } finally {
            System.debug(LoggingLevel.INFO, '=== saveAnalysisResults - END ===');
        }
    }
    
    /**
     * Tworzy rekord AiAnalysisResult__c na podstawie wyników analizy CV
     * @param candidateId ID kandydata
     * @param positionId ID pozycji (opcjonalnie)
     * @param jobApplicationId ID aplikacji o pracę (opcjonalnie)
     * @param analysisResults Surowe wyniki analizy w formacie JSON
     * @param results Sparsowane wyniki analizy
     * @return ID utworzonego rekordu AiAnalysisResult__c
     */
    private static Id createAiAnalysisResult(Id candidateId, Id positionId, Id jobApplicationId, String analysisResults, Map<String, Object> results) {
        System.debug(LoggingLevel.INFO, '=== createAiAnalysisResult - START ===');
        System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - candidateId: ' + candidateId);
        System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - positionId: ' + positionId);
        System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - jobApplicationId: ' + jobApplicationId);
        
        try {
            // Sprawdź uprawnienia do tworzenia rekordów AiAnalysisResult__c
            if (!Schema.SObjectType.AiAnalysisResult__c.isCreateable()) {
                String errorMsg = 'Brak uprawnień do tworzenia obiektów AiAnalysisResult__c';
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - ' + errorMsg);
                throw new AuraHandledException(errorMsg);
            }
            
            // Sprawdź, czy obiekt AiAnalysisResult__c istnieje
            try {
                SObjectType aiAnalysisType = Schema.getGlobalDescribe().get('AiAnalysisResult__c');
                if (aiAnalysisType == null) {
                    String errorMsg = 'Obiekt AiAnalysisResult__c nie istnieje w organizacji';
                    System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - ' + errorMsg);
                    throw new AuraHandledException(errorMsg);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Error checking object existence: ' + e.getMessage());
                throw new AuraHandledException('Błąd podczas sprawdzania istnienia obiektu AiAnalysisResult__c: ' + e.getMessage());
            }
            
            // Przygotuj rekord AiAnalysisResult__c
            AiAnalysisResult__c aiResult = new AiAnalysisResult__c();
            
            // Ustaw pola relacji z obsługą błędów
            try {
                if (candidateId != null && Schema.SObjectType.AiAnalysisResult__c.fields.Candidate__c.isCreateable()) {
                    aiResult.Candidate__c = candidateId;
                    System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - Set Candidate__c: ' + candidateId);
                } else {
                    System.debug(LoggingLevel.WARN, 'createAiAnalysisResult - Cannot set Candidate__c field');
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Error setting Candidate__c: ' + e.getMessage());
            }
            
            try {
                if (positionId != null && Schema.SObjectType.AiAnalysisResult__c.fields.Position__c.isCreateable()) {
                    aiResult.Position__c = positionId;
                    System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - Set Position__c: ' + positionId);
                } else {
                    System.debug(LoggingLevel.WARN, 'createAiAnalysisResult - Cannot set Position__c field');
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Error setting Position__c: ' + e.getMessage());
            }
            
            try {
                if (jobApplicationId != null && Schema.SObjectType.AiAnalysisResult__c.fields.Job_Application__c.isCreateable()) {
                    aiResult.Job_Application__c = jobApplicationId;
                    System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - Set Job_Application__c: ' + jobApplicationId);
                } else {
                    System.debug(LoggingLevel.WARN, 'createAiAnalysisResult - Cannot set Job_Application__c field');
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Error setting Job_Application__c: ' + e.getMessage());
            }
            
            // Ustaw surowe wyniki analizy
            try {
                if (analysisResults != null && Schema.SObjectType.AiAnalysisResult__c.fields.RawAnalysisResults__c.isCreateable()) {
                    if (analysisResults.length() <= 131072) { // Sprawdź limit długości pola
                        aiResult.RawAnalysisResults__c = analysisResults;
                        System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - Set RawAnalysisResults__c');
                    } else {
                        System.debug(LoggingLevel.WARN, 'createAiAnalysisResult - RawAnalysisResults__c exceeds field length limit, truncating');
                        aiResult.RawAnalysisResults__c = analysisResults.substring(0, 131072);
                    }
                } else {
                    System.debug(LoggingLevel.WARN, 'createAiAnalysisResult - Cannot set RawAnalysisResults__c field');
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Error setting RawAnalysisResults__c: ' + e.getMessage());
            }
            
            // Próba wstawienia rekordu
            try {
                insert aiResult;
                System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - Successfully inserted AiAnalysisResult__c with ID: ' + aiResult.Id);
                return aiResult.Id;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Error inserting record: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Stack trace: ' + e.getStackTraceString());
                throw new AuraHandledException('Błąd podczas zapisywania wyników analizy: ' + e.getMessage());
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Unexpected exception: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Błąd podczas tworzenia rekordu analizy: ' + e.getMessage());
        } finally {
            System.debug(LoggingLevel.INFO, '=== createAiAnalysisResult - END ===');
        }
    }
    
    /**
     * Zapisuje wyniki analizy dla obiektu Job_Application__c
     * @param recordId ID aplikacji o pracę
     * @param analysisResults Surowe wyniki analizy w formacie JSON
     * @param results Sparsowane wyniki analizy
     * @return ID utworzonego rekordu AiAnalysisResult__c
     */
    private static Id saveJobApplicationResults(Id recordId, String analysisResults, Map<String, Object> results) {
        try {
            System.debug(LoggingLevel.INFO, '=== saveJobApplicationResults - START ===');
            System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - start for recordId: ' + recordId);
            
            // Pobierz ID kandydata i pozycji z aplikacji o pracę
            Job_Application__c jobApp = [
                SELECT Id, Candidate__c, Position__c 
                FROM Job_Application__c 
                WHERE Id = :recordId 
                WITH SECURITY_ENFORCED 
                LIMIT 1
            ];
            
            Id candidateId = jobApp.Candidate__c;
            Id positionId = jobApp.Position__c;
            
            System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - candidateId: ' + candidateId);
            System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - positionId: ' + positionId);
            
            // Utwórz rekord AiAnalysisResult__c
            Id aiResultId = createAiAnalysisResult(candidateId, positionId, recordId, analysisResults, results);
            
            // Zaktualizuj Job_Application__c, aby wskazywał na najnowszą analizę
            // Można to zrobić w przyszłości, jeśli będzie taka potrzeba
            
            System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - created AiAnalysisResult__c with ID: ' + aiResultId);
            return aiResultId;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'saveJobApplicationResults - Exception: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'saveJobApplicationResults - Exception type: ' + e.getTypeName());
            System.debug(LoggingLevel.ERROR, 'saveJobApplicationResults - Stack trace: ' + e.getStackTraceString());
            throw e; // Przekazujemy wyjątek wyżej, aby został obsłużony w saveAnalysisResults
        } finally {
            System.debug(LoggingLevel.INFO, '=== saveJobApplicationResults - END ===');
        }
    }
    
    /**
     * Zapisuje wyniki analizy dla obiektu Candidate__c
     * @param recordId ID kandydata
     * @param analysisResults Surowe wyniki analizy w formacie JSON
     * @param results Sparsowane wyniki analizy
     * @return ID utworzonego rekordu AiAnalysisResult__c
     */
    private static Id saveCandidateResults(Id recordId, String analysisResults, Map<String, Object> results) {
        try {
            System.debug(LoggingLevel.INFO, '=== saveCandidateResults - START ===');
            System.debug(LoggingLevel.INFO, 'saveCandidateResults - start for recordId: ' + recordId);
            
            // Utwórz rekord AiAnalysisResult__c
            Id aiResultId = createAiAnalysisResult(recordId, null, null, analysisResults, results);
            
            System.debug(LoggingLevel.INFO, 'saveCandidateResults - created AiAnalysisResult__c with ID: ' + aiResultId);
            return aiResultId;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'saveCandidateResults - Exception: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'saveCandidateResults - Exception type: ' + e.getTypeName());
            System.debug(LoggingLevel.ERROR, 'saveCandidateResults - Stack trace: ' + e.getStackTraceString());
            throw e; // Przekazujemy wyjątek wyżej, aby został obsłużony w saveAnalysisResults
        } finally {
            System.debug(LoggingLevel.INFO, '=== saveCandidateResults - END ===');
        }
    }
    
    /**
     * Ekstrahuje umiejętności z wyników analizy
     * @param results Mapa wyników analizy
     * @return String zawierający umiejętności oddzielone przecinkami lub pusty string
     */
    private static String extractSkillsFromResults(Map<String, Object> results) {
        Object skills = results.get('skills');
        if (skills instanceof List<Object>) {
            return extractSkillsAsString((List<Object>)skills);
        }
        return '';
    }

    /**
     * Ekstrahuje umiejętności z listy obiektów i zwraca je jako string oddzielony przecinkami
     * @param skillsList Lista obiektów reprezentujących umiejętności
     * @return String zawierający umiejętności oddzielone przecinkami
     */
    private static String extractSkillsAsString(List<Object> skillsList) {
        List<String> skillsStrings = new List<String>();
        
        for (Object skill : skillsList) {
            if (skill instanceof String) {
                skillsStrings.add((String)skill);
            } else if (skill instanceof Map<String, Object>) {
                Map<String, Object> skillMap = (Map<String, Object>)skill;
                if (skillMap.containsKey('name')) {
                    skillsStrings.add(String.valueOf(skillMap.get('name')));
                }
            }
        }
        
        return !skillsStrings.isEmpty() ? String.join(skillsStrings, ', ') : '';
    }

    /**
     * Ekstrahuje wynik dopasowania z obiektu
     * @param matchScoreObj Obiekt zawierający wynik dopasowania
     * @return Wynik dopasowania jako Decimal
     */
    private static Decimal extractMatchScore(Object matchScoreObj) {
        try {
            System.debug(LoggingLevel.INFO, 'extractMatchScore - input type: ' + getObjectType(matchScoreObj));
            
            if (matchScoreObj == null) {
                System.debug(LoggingLevel.WARN, 'extractMatchScore - matchScoreObj is null, returning 0');
                return 0;
            }
            
            // Jeśli to już Decimal, zwróć bezpośrednio
            if (matchScoreObj instanceof Decimal) {
                System.debug(LoggingLevel.INFO, 'extractMatchScore - matchScoreObj is Decimal: ' + (Decimal)matchScoreObj);
                return (Decimal)matchScoreObj;
            }
            
            // Jeśli to Integer, konwertuj na Decimal
            if (matchScoreObj instanceof Integer) {
                System.debug(LoggingLevel.INFO, 'extractMatchScore - matchScoreObj is Integer: ' + (Integer)matchScoreObj);
                return Decimal.valueOf((Integer)matchScoreObj);
            }
            
            // Jeśli to Double, konwertuj na Decimal
            if (matchScoreObj instanceof Double) {
                System.debug(LoggingLevel.INFO, 'extractMatchScore - matchScoreObj is Double: ' + (Double)matchScoreObj);
                return Decimal.valueOf((Double)matchScoreObj);
            }
            
            // Jeśli to String, próbuj sparsować
            if (matchScoreObj instanceof String) {
                String scoreStr = (String)matchScoreObj;
                System.debug(LoggingLevel.INFO, 'extractMatchScore - matchScoreObj is String: ' + scoreStr);
                
                // Usuń znaki procentu i inne niebędące liczbami
                scoreStr = scoreStr.replaceAll('[^0-9\\.]', '');
                
                if (String.isBlank(scoreStr)) {
                    System.debug(LoggingLevel.WARN, 'extractMatchScore - scoreStr is blank after cleaning, returning 0');
                    return 0;
                }
                
                try {
                    return Decimal.valueOf(scoreStr);
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'extractMatchScore - Error parsing String to Decimal: ' + e.getMessage());
                    return 0;
                }
            }
            
            // Dla innych typów, próbuj konwersji przez String
            try {
                System.debug(LoggingLevel.INFO, 'extractMatchScore - attempting conversion via String for type: ' + getObjectType(matchScoreObj));
                String scoreStr = String.valueOf(matchScoreObj);
                scoreStr = scoreStr.replaceAll('[^0-9\\.]', '');
                
                if (String.isBlank(scoreStr)) {
                    System.debug(LoggingLevel.WARN, 'extractMatchScore - scoreStr is blank after cleaning, returning 0');
                    return 0;
                }
                
                return Decimal.valueOf(scoreStr);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'extractMatchScore - Error in final conversion attempt: ' + e.getMessage());
                return 0;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'extractMatchScore - Unexpected error: ' + e.getMessage());
            return 0;
        }
    }
    
    /**
     * Zwraca typ obiektu jako String
     * @param obj Obiekt do sprawdzenia
     * @return Nazwa typu obiektu
     */
    private static String getObjectType(Object obj) {
        if (obj == null) {
            return 'null';
        } else if (obj instanceof String) {
            return 'String';
        } else if (obj instanceof Integer) {
            return 'Integer';
        } else if (obj instanceof Decimal) {
            return 'Decimal';
        } else if (obj instanceof Double) {
            return 'Double';
        } else if (obj instanceof Boolean) {
            return 'Boolean';
        } else if (obj instanceof Date) {
            return 'Date';
        } else if (obj instanceof Datetime) {
            return 'Datetime';
        } else if (obj instanceof List<Object>) {
            return 'List<Object>';
        } else if (obj instanceof Map<String, Object>) {
            return 'Map<String, Object>';
        } else if (obj instanceof SObject) {
            return 'SObject: ' + ((SObject)obj).getSObjectType().getDescribe().getName();
        } else {
            return 'Unknown type: ' + obj.toString();
        }
    }
}