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
     * @return ID of the updated record
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
     * Tworzy rekordy umiejętności na podstawie wyników analizy CV
     * @param candidateId ID kandydata
     * @param results Wyniki analizy CV
     * @return Lista utworzonych rekordów umiejętności
     */
    private static List<Skill__c> createSkillRecords(Id candidateId, Map<String, Object> results) {
        System.debug(LoggingLevel.INFO, '=== createSkillRecords - START ===');
        System.debug(LoggingLevel.INFO, 'createSkillRecords - candidateId: ' + candidateId);
        
        List<Skill__c> skillsToInsert = new List<Skill__c>();
        
        try {
            // Sprawdź uprawnienia do tworzenia rekordów Skill__c
            if (!Schema.SObjectType.Skill__c.isCreateable()) {
                System.debug(LoggingLevel.ERROR, 'createSkillRecords - Skill__c is not createable');
                throw new AuraHandledException('Brak uprawnień do tworzenia obiektów Skill__c');
            }
            
            // Sprawdź uprawnienia do pól
            SecurityUtils.checkCreateAccess(Skill__c.SObjectType, 
                new List<String>{'Name', 'Candidate__c', 'Category__c', 'Proficiency_Level__c'});
            
            // Pobierz umiejętności z wyników analizy
            List<String> skillsList = new List<String>();
            
            // Sprawdź różne możliwe formaty umiejętności w wynikach
            if (results.containsKey('skills') && results.get('skills') instanceof List<Object>) {
                List<Object> skillsObj = (List<Object>)results.get('skills');
                for (Object skill : skillsObj) {
                    if (skill instanceof String) {
                        skillsList.add((String)skill);
                    } else if (skill instanceof Map<String, Object>) {
                        Map<String, Object> skillMap = (Map<String, Object>)skill;
                        if (skillMap.containsKey('name')) {
                            skillsList.add(String.valueOf(skillMap.get('name')));
                        }
                    }
                }
                System.debug(LoggingLevel.INFO, 'createSkillRecords - extracted skills from "skills" key: ' + skillsList.size());
            } else if (results.containsKey('Umiejętności techniczne')) {
                Object skillsObj = results.get('Umiejętności techniczne');
                if (skillsObj instanceof List<Object>) {
                    List<Object> techSkills = (List<Object>)skillsObj;
                    for (Object skill : techSkills) {
                        if (skill instanceof String) {
                            skillsList.add((String)skill);
                        }
                    }
                } else if (skillsObj instanceof String) {
                    // Jeśli to string, spróbuj podzielić po przecinkach
                    String skillsStr = (String)skillsObj;
                    skillsList.addAll(skillsStr.split(','));
                }
                System.debug(LoggingLevel.INFO, 'createSkillRecords - extracted skills from "Umiejętności techniczne" key: ' + skillsList.size());
            }
            
            // Dodaj również dopasowane umiejętności, jeśli istnieją
            if (results.containsKey('matchedSkills') && results.get('matchedSkills') instanceof List<Object>) {
                List<Object> matchedSkillsObj = (List<Object>)results.get('matchedSkills');
                for (Object skill : matchedSkillsObj) {
                    if (skill instanceof String) {
                        String skillName = ((String)skill).trim();
                        if (!skillsList.contains(skillName)) {
                            skillsList.add(skillName);
                        }
                    }
                }
                System.debug(LoggingLevel.INFO, 'createSkillRecords - added matched skills, total skills: ' + skillsList.size());
            }
            
            // Jeśli nie znaleziono umiejętności, zakończ
            if (skillsList.isEmpty()) {
                System.debug(LoggingLevel.INFO, 'createSkillRecords - no skills found in results');
                return skillsToInsert;
            }
            
            // Utwórz rekordy umiejętności
            for (String skillName : skillsList) {
                skillName = skillName.trim();
                if (String.isNotBlank(skillName)) {
                    Skill__c skill = new Skill__c(
                        Name = skillName,
                        Candidate__c = candidateId
                    );
                    
                    // Ustaw kategorię na podstawie nazwy umiejętności (prosta logika)
                    if (skillName.containsIgnoreCase('Apex') || 
                        skillName.containsIgnoreCase('LWC') || 
                        skillName.containsIgnoreCase('Visualforce') ||
                        skillName.containsIgnoreCase('SOQL') ||
                        skillName.containsIgnoreCase('SOSL') ||
                        skillName.containsIgnoreCase('Flow')) {
                        skill.Category__c = 'Salesforce';
                    } else if (skillName.containsIgnoreCase('Java') || 
                               skillName.containsIgnoreCase('JavaScript') || 
                               skillName.containsIgnoreCase('Python') ||
                               skillName.containsIgnoreCase('C#') ||
                               skillName.containsIgnoreCase('C++')) {
                        skill.Category__c = 'Programming';
                    } else if (skillName.containsIgnoreCase('English') || 
                               skillName.containsIgnoreCase('French') || 
                               skillName.containsIgnoreCase('German') ||
                               skillName.containsIgnoreCase('Spanish')) {
                        skill.Category__c = 'Language';
                    } else {
                        skill.Category__c = 'Other';
                    }
                    
                    // Domyślny poziom biegłości
                    skill.Proficiency_Level__c = 'Intermediate';
                    
                    skillsToInsert.add(skill);
                }
            }
            
            System.debug(LoggingLevel.INFO, 'createSkillRecords - prepared ' + skillsToInsert.size() + ' skills to insert');
            
            // Wstaw rekordy umiejętności
            if (!skillsToInsert.isEmpty()) {
                // Użyj Database.insert zamiast insert, aby obsłużyć błędy
                Database.SaveResult[] saveResults = Database.insert(skillsToInsert, false);
                
                // Sprawdź wyniki
                Integer successCount = 0;
                for (Database.SaveResult sr : saveResults) {
                    if (sr.isSuccess()) {
                        successCount++;
                    } else {
                        for (Database.Error err : sr.getErrors()) {
                            System.debug(LoggingLevel.ERROR, 'createSkillRecords - Error creating skill: ' + err.getMessage());
                        }
                    }
                }
                
                System.debug(LoggingLevel.INFO, 'createSkillRecords - Successfully inserted ' + successCount + ' out of ' + skillsToInsert.size() + ' skills');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'createSkillRecords - Exception: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'createSkillRecords - Stack trace: ' + e.getStackTraceString());
            // Nie rzucamy wyjątku, aby nie przerywać głównego procesu zapisywania wyników analizy
        } finally {
            System.debug(LoggingLevel.INFO, '=== createSkillRecords - END ===');
        }
        
        return skillsToInsert;
    }
    
    /**
     * Zapisuje wyniki analizy dla obiektu Job_Application__c
     * @param recordId ID aplikacji o pracę
     * @param analysisResults Surowe wyniki analizy w formacie JSON
     * @param results Sparsowane wyniki analizy
     * @return ID zaktualizowanego rekordu
     */
    private static Id saveJobApplicationResults(Id recordId, String analysisResults, Map<String, Object> results) {
        try {
            System.debug(LoggingLevel.INFO, '=== saveJobApplicationResults - START ===');
            System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - start for recordId: ' + recordId);
            
            // Sprawdź uprawnienia
            System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - checking update access');
            SecurityUtils.checkUpdateAccess(Job_Application__c.SObjectType, 
                new List<String>{'Analysis_Results__c'});
            System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - permissions checked successfully');
            
            // Pobierz ID kandydata z aplikacji o pracę
            Job_Application__c jobApp = [SELECT Id, Candidate__c FROM Job_Application__c WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1];
            Id candidateId = jobApp.Candidate__c;
            
            // Jeśli mamy ID kandydata, utwórz rekordy umiejętności
            if (candidateId != null) {
                createSkillRecords(candidateId, results);
            }
            
            // Przygotuj dane do zapisu
            System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - preparing data for update');
            Job_Application__c application = new Job_Application__c(
                Id = recordId,
                Analysis_Results__c = analysisResults
            );
            
            // Dodaj wynik dopasowania, jeśli istnieje
            if (results.containsKey('matchScore')) {
                Object matchScoreObj = results.get('matchScore');
                System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - matchScore found, type: ' + getObjectType(matchScoreObj));
                Decimal matchScore = extractMatchScore(matchScoreObj);
                
                // Sprawdź, czy pole Match_Score__c istnieje w obiekcie Job_Application__c
                Schema.DescribeFieldResult fieldDescribe = Schema.SObjectType.Job_Application__c.fields.getMap().get('Match_Score__c')?.getDescribe();
                if (fieldDescribe != null && fieldDescribe.isUpdateable()) {
                    application.put('Match_Score__c', matchScore);
                    System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - extracted matchScore: ' + matchScore);
                } else {
                    System.debug(LoggingLevel.WARN, 'saveJobApplicationResults - Match_Score__c field does not exist or is not updateable');
                }
            } else {
                System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - matchScore not found in results');
            }
            
            // Dodaj zidentyfikowane umiejętności, jeśli istnieją
            if (results.containsKey('skills')) {
                Object skillsObj = results.get('skills');
                System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - skills found, type: ' + getObjectType(skillsObj));
                String skillsString = extractSkillsFromResults(results);
                
                // Sprawdź, czy pole Skills__c istnieje w obiekcie Job_Application__c
                Schema.DescribeFieldResult fieldDescribe = Schema.SObjectType.Job_Application__c.fields.getMap().get('Skills__c')?.getDescribe();
                if (fieldDescribe != null && fieldDescribe.isUpdateable()) {
                    application.put('Skills__c', skillsString);
                    System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - extracted skills length: ' + (skillsString != null ? skillsString.length() : 0));
                } else {
                    System.debug(LoggingLevel.WARN, 'saveJobApplicationResults - Skills__c field does not exist or is not updateable');
                }
            } else {
                System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - skills not found in results');
            }
            
            // Zapisz zmiany z wymuszeniem sprawdzania uprawnień CRUD
            System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - attempting to update record with fields: ' + 
                          'Analysis_Results__c (length: ' + (application.Analysis_Results__c != null ? application.Analysis_Results__c.length() : 0) + ')');
            
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
            dmlOptions.OptAllOrNone = true;
            Database.SaveResult result = Database.update(application, dmlOptions);
            if (!result.isSuccess()) {
                String errorMsg = 'Error updating Job_Application__c: ' + (result.getErrors().size() > 0 ? result.getErrors()[0].getMessage() : 'Unknown error');
                System.debug(LoggingLevel.ERROR, 'saveJobApplicationResults - update failed: ' + errorMsg);
                for (Database.Error err : result.getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'saveJobApplicationResults - error details: ' + 
                                 'Fields: ' + err.getFields() + ', ' +
                                 'Message: ' + err.getMessage() + ', ' +
                                 'StatusCode: ' + err.getStatusCode());
                }
                throw new AuraHandledException(errorMsg);
            }
            System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - update successful');
            return recordId;
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
     * @return ID zaktualizowanego rekordu
     */
    private static Id saveCandidateResults(Id recordId, String analysisResults, Map<String, Object> results) {
        try {
            System.debug(LoggingLevel.INFO, '=== saveCandidateResults - START ===');
            System.debug(LoggingLevel.INFO, 'saveCandidateResults - start for recordId: ' + recordId);
            
            // Sprawdź uprawnienia
            System.debug(LoggingLevel.INFO, 'saveCandidateResults - checking update access');
            SecurityUtils.checkUpdateAccess(Candidate__c.SObjectType, 
                new List<String>{'Analysis_Results__c'});
            System.debug(LoggingLevel.INFO, 'saveCandidateResults - permissions checked successfully');
            
            // Utwórz rekordy umiejętności
            createSkillRecords(recordId, results);
            
            // Przygotuj dane do zapisu
            System.debug(LoggingLevel.INFO, 'saveCandidateResults - preparing data for update');
            Candidate__c candidate = new Candidate__c(
                Id = recordId,
                Analysis_Results__c = analysisResults
            );
            
            // Dodaj zidentyfikowane umiejętności, jeśli istnieją
            if (results.containsKey('skills')) {
                Object skillsObj = results.get('skills');
                System.debug(LoggingLevel.INFO, 'saveCandidateResults - skills found, type: ' + getObjectType(skillsObj));
                String skillsString = extractSkillsFromResults(results);
                
                // Sprawdź, czy pole Skills__c istnieje w obiekcie Candidate__c
                Schema.DescribeFieldResult fieldDescribe = Schema.SObjectType.Candidate__c.fields.getMap().get('Skills__c')?.getDescribe();
                if (fieldDescribe != null && fieldDescribe.isUpdateable()) {
                    candidate.put('Skills__c', skillsString);
                    System.debug(LoggingLevel.INFO, 'saveCandidateResults - extracted skills length: ' + (skillsString != null ? skillsString.length() : 0));
                } else {
                    System.debug(LoggingLevel.WARN, 'saveCandidateResults - Skills__c field does not exist or is not updateable');
                }
            } else {
                System.debug(LoggingLevel.INFO, 'saveCandidateResults - skills not found in results');
            }
            
            // Zapisz zmiany z wymuszeniem sprawdzania uprawnień CRUD
            System.debug(LoggingLevel.INFO, 'saveCandidateResults - attempting to update record with fields: ' + 
                          'Analysis_Results__c (length: ' + (candidate.Analysis_Results__c != null ? candidate.Analysis_Results__c.length() : 0) + ')');
            
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
            dmlOptions.OptAllOrNone = true;
            Database.SaveResult result = Database.update(candidate, dmlOptions);
            if (!result.isSuccess()) {
                String errorMsg = 'Error updating Candidate__c: ' + (result.getErrors().size() > 0 ? result.getErrors()[0].getMessage() : 'Unknown error');
                System.debug(LoggingLevel.ERROR, 'saveCandidateResults - update failed: ' + errorMsg);
                for (Database.Error err : result.getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'saveCandidateResults - error details: ' + 
                                 'Fields: ' + err.getFields() + ', ' +
                                 'Message: ' + err.getMessage() + ', ' +
                                 'StatusCode: ' + err.getStatusCode());
                }
                throw new AuraHandledException(errorMsg);
            }
            System.debug(LoggingLevel.INFO, 'saveCandidateResults - update successful');
            return recordId;
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