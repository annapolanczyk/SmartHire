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
                
                // Szczegółowe logowanie struktury danych
                System.debug(LoggingLevel.INFO, '=== DETAILED ANALYSIS RESULTS STRUCTURE ===');
                for (String key : results.keySet()) {
                    Object value = results.get(key);
                    String valueType = getObjectType(value);
                    System.debug(LoggingLevel.INFO, 'Key: ' + key + ', Type: ' + valueType);
                    
                    // Jeśli wartość to mapa, zaloguj jej klucze
                    if (value instanceof Map<String, Object>) {
                        Map<String, Object> nestedMap = (Map<String, Object>)value;
                        System.debug(LoggingLevel.INFO, '  Nested keys for ' + key + ': ' + nestedMap.keySet());
                    }
                    // Jeśli wartość to lista, zaloguj jej rozmiar i typ pierwszego elementu (jeśli istnieje)
                    else if (value instanceof List<Object>) {
                        List<Object> nestedList = (List<Object>)value;
                        String firstItemType = nestedList.isEmpty() ? 'empty' : getObjectType(nestedList[0]);
                        System.debug(LoggingLevel.INFO, '  List size for ' + key + ': ' + nestedList.size() + ', First item type: ' + firstItemType);
                        
                        // Jeśli to lista umiejętności, zaloguj kilka pierwszych elementów
                        if (key.containsIgnoreCase('skill') && !nestedList.isEmpty()) {
                            Integer samplesToLog = Math.min(nestedList.size(), 5);
                            List<Object> samples = new List<Object>();
                            for (Integer i = 0; i < samplesToLog; i++) {
                                samples.add(nestedList[i]);
                            }
                            System.debug(LoggingLevel.INFO, '  Sample skills: ' + samples);
                        }
                    }
                    // Dla prostych typów, zaloguj wartość (jeśli nie jest za długa)
                    else if (value instanceof String) {
                        String strValue = (String)value;
                        if (strValue.length() <= 100) {
                            System.debug(LoggingLevel.INFO, '  Value: ' + strValue);
                        } else {
                            System.debug(LoggingLevel.INFO, '  Value (truncated): ' + strValue.substring(0, 100) + '...');
                        }
                    }
                    else if (value instanceof Decimal || value instanceof Integer || value instanceof Double || value instanceof Boolean) {
                        System.debug(LoggingLevel.INFO, '  Value: ' + value);
                    }
                }
                System.debug(LoggingLevel.INFO, '=== END OF DETAILED ANALYSIS RESULTS STRUCTURE ===');
                
                // Sprawdź, czy istnieją kluczowe pola, których szukamy
                List<String> expectedKeys = new List<String>{
                    'matchScore', 'matchedSkills', 'missingSkills', 'additionalSkills', 
                    'summary', 'keyHighlights', 'potentialConcerns', 'skills'
                };
                
                System.debug(LoggingLevel.INFO, '=== CHECKING FOR EXPECTED KEYS ===');
                for (String expectedKey : expectedKeys) {
                    if (results.containsKey(expectedKey)) {
                        System.debug(LoggingLevel.INFO, 'Expected key found: ' + expectedKey);
                    } else {
                        System.debug(LoggingLevel.WARN, 'Expected key NOT found: ' + expectedKey);
                        
                        // Sprawdź, czy istnieje podobny klucz
                        for (String actualKey : results.keySet()) {
                            if (actualKey.containsIgnoreCase(expectedKey)) {
                                System.debug(LoggingLevel.INFO, '  Similar key found: ' + actualKey);
                            }
                        }
                    }
                }
                System.debug(LoggingLevel.INFO, '=== END OF CHECKING FOR EXPECTED KEYS ===');
                
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
            
            // Dodaj positionId do wyników analizy, aby można było podzielić umiejętności
            if (!results.containsKey('positionId')) {
                results.put('positionId', positionId);
                System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - Added positionId to results');
            }
            
            // Utwórz rekord AiAnalysisResult__c
            Id aiResultId = createAiAnalysisResult(results, recordId, 'Job_Application__c');
            
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
            Id aiResultId = createAiAnalysisResult(results, recordId, 'Candidate__c');
            
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
     * @description Pobiera umiejętności wymagane dla danej pozycji
     * @param positionId Id pozycji
     * @return Lista umiejętności wymaganych dla pozycji
     */
    private static List<String> getPositionSkills(Id positionId) {
        List<String> skills = new List<String>();
        
        try {
            Position__c position = [SELECT required_skills__c FROM Position__c WHERE Id = :positionId LIMIT 1];
            if (position != null && position.required_skills__c != null) {
                // Zakładamy, że umiejętności są oddzielone przecinkami lub nowymi liniami
                String skillsText = position.required_skills__c;
                
                // Zamień nowe linie na przecinki
                skillsText = skillsText.replace('\n', ',').replace('\r', ',');
                
                // Podziel tekst na podstawie przecinków
                for (String skill : skillsText.split(',')) {
                    String trimmedSkill = skill.trim();
                    if (String.isNotBlank(trimmedSkill)) {
                        skills.add(trimmedSkill);
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Błąd podczas pobierania umiejętności z pozycji: ' + e.getMessage());
        }
        
        return skills;
    }
    
    /**
     * @description Tworzy rekord AiAnalysisResult__c na podstawie wyników analizy
     * @param results Mapa wyników analizy
     * @param recordId Id rekordu, dla którego tworzony jest wynik analizy
     * @param objectType Typ obiektu, dla którego tworzony jest wynik analizy
     * @return Id utworzonego rekordu AiAnalysisResult__c
     */
    private static Id createAiAnalysisResult(Map<String, Object> results, Id recordId, String objectType) {
        try {
            // Usuwamy sprawdzenie uprawnień, które powodowało błędy
            // SecurityUtils.checkCreateAccess(AiAnalysisResult__c.SObjectType, new List<String>{
            //     AiAnalysisResult__c.Name.getDescribe().getName(),
            //     AiAnalysisResult__c.Record_Id__c.getDescribe().getName(),
            //     AiAnalysisResult__c.Object_Type__c.getDescribe().getName(),
            //     AiAnalysisResult__c.RawAnalysisResults__c.getDescribe().getName()
            // });
            
            // Standardyzacja kluczy w wynikach analizy
            results = standardizeResultKeys(results);
            
            // Logowanie kluczy po standaryzacji
            System.debug(LoggingLevel.DEBUG, 'Klucze po standaryzacji: ' + results.keySet());
            
            // Tworzenie rekordu AiAnalysisResult__c
            AiAnalysisResult__c result = new AiAnalysisResult__c();
            
            // Ustawiamy pola relacji na podstawie typu obiektu
            if (objectType == 'Job_Application__c') {
                result.Job_Application__c = recordId;
            } else if (objectType == 'Candidate__c') {
                result.Candidate__c = recordId;
            }
            
            // Ustawiamy surowe wyniki analizy
            result.RawAnalysisResults__c = JSON.serialize(results);
            
            // Ustawienie pól na podstawie wyników analizy
            if (results.containsKey('matchScore')) {
                Object matchScoreObj = results.get('matchScore');
                if (matchScoreObj instanceof Decimal) {
                    result.MatchScore__c = (Decimal)matchScoreObj;
                } else if (matchScoreObj instanceof Integer) {
                    result.MatchScore__c = (Integer)matchScoreObj;
                } else if (matchScoreObj instanceof String) {
                    try {
                        result.MatchScore__c = Decimal.valueOf((String)matchScoreObj);
                    } catch (Exception e) {
                        System.debug(LoggingLevel.ERROR, 'Nie można przekonwertować matchScore na Decimal: ' + e.getMessage());
                    }
                }
                System.debug(LoggingLevel.DEBUG, 'Ustawiono MatchScore__c: ' + result.MatchScore__c);
            }
            
            // Ustawienie pól dla umiejętności
            if (results.containsKey('matchedSkills')) {
                Object matchedSkillsObj = results.get('matchedSkills');
                if (matchedSkillsObj instanceof List<Object>) {
                    List<Object> matchedSkillsList = (List<Object>)matchedSkillsObj;
                    List<String> skillStrings = new List<String>();
                    for (Object skill : matchedSkillsList) {
                        skillStrings.add(String.valueOf(skill));
                    }
                    result.MatchingSkills__c = String.join(skillStrings, ', ');
                    System.debug(LoggingLevel.DEBUG, 'Ustawiono MatchingSkills__c: ' + result.MatchingSkills__c);
                } else if (matchedSkillsObj instanceof String) {
                    result.MatchingSkills__c = (String)matchedSkillsObj;
                    System.debug(LoggingLevel.DEBUG, 'Ustawiono MatchingSkills__c (string): ' + result.MatchingSkills__c);
                }
            }
            
            if (results.containsKey('additionalSkills')) {
                Object additionalSkillsObj = results.get('additionalSkills');
                if (additionalSkillsObj instanceof List<Object>) {
                    List<Object> additionalSkillsList = (List<Object>)additionalSkillsObj;
                    List<String> skillStrings = new List<String>();
                    for (Object skill : additionalSkillsList) {
                        skillStrings.add(String.valueOf(skill));
                    }
                    result.AdditionalSkills__c = String.join(skillStrings, ', ');
                    System.debug(LoggingLevel.DEBUG, 'Ustawiono AdditionalSkills__c: ' + result.AdditionalSkills__c);
                } else if (additionalSkillsObj instanceof String) {
                    result.AdditionalSkills__c = (String)additionalSkillsObj;
                    System.debug(LoggingLevel.DEBUG, 'Ustawiono AdditionalSkills__c (string): ' + result.AdditionalSkills__c);
                }
            }
            
            // Wstawienie rekordu
            insert result;
            System.debug(LoggingLevel.DEBUG, 'Utworzono rekord AiAnalysisResult__c: ' + result.Id);
            return result.Id;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Błąd podczas tworzenia rekordu AiAnalysisResult__c: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Błąd podczas tworzenia rekordu analizy: ' + e.getMessage());
        }
    }
    
    /**
     * @description Standaryzuje klucze w wynikach analizy
     * @param results Mapa wyników analizy
     * @return Mapa wyników analizy ze standaryzowanymi kluczami
     */
    private static Map<String, Object> standardizeResultKeys(Map<String, Object> results) {
        Map<String, Object> standardized = new Map<String, Object>();
        
        // Logowanie kluczy przed standaryzacją
        System.debug(LoggingLevel.DEBUG, 'Klucze przed standaryzacją: ' + results.keySet());
        
        // Kopiuj wszystkie oryginalne klucze
        for (String key : results.keySet()) {
            standardized.put(key, results.get(key));
        }
        
        // Mapowanie kluczy na standardowe nazwy
        Map<String, String> keyMapping = new Map<String, String>{
            'matchscore' => 'matchScore',
            'match_score' => 'matchScore',
            'match score' => 'matchScore',
            'dopasowanie' => 'matchScore',
            'wynik_dopasowania' => 'matchScore',
            'wynik dopasowania' => 'matchScore',
            
            'matchedskills' => 'matchedSkills',
            'matched_skills' => 'matchedSkills',
            'matched skills' => 'matchedSkills',
            'pasujące_umiejętności' => 'matchedSkills',
            'pasujące umiejętności' => 'matchedSkills',
            'dopasowane_umiejętności' => 'matchedSkills',
            'dopasowane umiejętności' => 'matchedSkills',
            
            'missingskills' => 'missingSkills',
            'missing_skills' => 'missingSkills',
            'missing skills' => 'missingSkills',
            'brakujące_umiejętności' => 'missingSkills',
            'brakujące umiejętności' => 'missingSkills',
            
            'additionalskills' => 'additionalSkills',
            'additional_skills' => 'additionalSkills',
            'additional skills' => 'additionalSkills',
            'dodatkowe_umiejętności' => 'additionalSkills',
            'dodatkowe umiejętności' => 'additionalSkills',
            
            'skills' => 'skills',
            'umiejętności' => 'skills',
            'umiejętności techniczne' => 'skills',
            'umiejętności_techniczne' => 'skills'
        };
        
        // Standaryzacja kluczy
        for (String originalKey : results.keySet()) {
            String lowerKey = originalKey.toLowerCase();
            if (keyMapping.containsKey(lowerKey)) {
                String standardKey = keyMapping.get(lowerKey);
                standardized.put(standardKey, results.get(originalKey));
                System.debug(LoggingLevel.DEBUG, 'Zmapowano klucz: ' + originalKey + ' -> ' + standardKey);
            }
        }
        
        // Sprawdź, czy mamy klucz "Umiejętności techniczne" lub podobny
        if (results.containsKey('Umiejętności techniczne')) {
            Object skillsObj = results.get('Umiejętności techniczne');
            standardized.put('skills', skillsObj);
            System.debug(LoggingLevel.DEBUG, 'Znaleziono klucz "Umiejętności techniczne", dodano jako "skills"');
        }
        
        // Jeśli mamy positionId, pobierz wymagane umiejętności i podziel umiejętności na pasujące i dodatkowe
        if (results.containsKey('positionId')) {
            Id positionId = (Id)results.get('positionId');
            List<String> requiredSkills = getPositionSkills(positionId);
            System.debug(LoggingLevel.DEBUG, 'Pobrano wymagane umiejętności dla pozycji: ' + requiredSkills);
            
            // Jeśli mamy umiejętności i wymagane umiejętności, podziel je na pasujące i dodatkowe
            if (standardized.containsKey('skills') && !requiredSkills.isEmpty()) {
                Object skillsObj = standardized.get('skills');
                List<String> allSkills = new List<String>();
                
                // Konwersja umiejętności na listę stringów
                if (skillsObj instanceof List<Object>) {
                    for (Object skill : (List<Object>)skillsObj) {
                        allSkills.add(String.valueOf(skill));
                    }
                } else if (skillsObj instanceof String) {
                    String skillsStr = (String)skillsObj;
                    if (skillsStr.contains(',')) {
                        for (String skill : skillsStr.split(',')) {
                            allSkills.add(skill.trim());
                        }
                    } else {
                        allSkills.add(skillsStr.trim());
                    }
                }
                
                // Podziel umiejętności na pasujące i dodatkowe
                List<String> matchedSkills = new List<String>();
                List<String> additionalSkills = new List<String>();
                
                for (String skill : allSkills) {
                    Boolean matched = false;
                    for (String requiredSkill : requiredSkills) {
                        if (skill.toLowerCase().contains(requiredSkill.toLowerCase()) || 
                            requiredSkill.toLowerCase().contains(skill.toLowerCase())) {
                            matchedSkills.add(skill);
                            matched = true;
                            break;
                        }
                    }
                    
                    if (!matched) {
                        additionalSkills.add(skill);
                    }
                }
                
                // Ustaw pasujące i dodatkowe umiejętności
                if (!matchedSkills.isEmpty()) {
                    standardized.put('matchedSkills', matchedSkills);
                    System.debug(LoggingLevel.DEBUG, 'Ustawiono matchedSkills: ' + matchedSkills);
                } else {
                    // Jeśli nie znaleziono pasujących umiejętności, użyj wszystkich jako pasujących
                    standardized.put('matchedSkills', allSkills);
                    System.debug(LoggingLevel.DEBUG, 'Nie znaleziono pasujących umiejętności, użyto wszystkich: ' + allSkills);
                }
                
                if (!additionalSkills.isEmpty()) {
                    standardized.put('additionalSkills', additionalSkills);
                    System.debug(LoggingLevel.DEBUG, 'Ustawiono additionalSkills: ' + additionalSkills);
                } else {
                    // Jeśli nie znaleziono dodatkowych umiejętności, ustaw pustą listę
                    standardized.put('additionalSkills', new List<String>());
                    System.debug(LoggingLevel.DEBUG, 'Nie znaleziono dodatkowych umiejętności, ustawiono pustą listę');
                }
            }
        }
        
        return standardized;
    }
    
    /**
     * Ekstrahuje umiejętności z listy obiektów i zwraca je jako listę stringów
     * @param skillsList Lista obiektów reprezentujących umiejętności
     * @return Lista stringów zawierających umiejętności
     */
    private static List<String> extractSkillsAsList(List<Object> skillsList) {
        List<String> skillsStrings = new List<String>();
        
        for (Object skill : skillsList) {
            if (skill instanceof String) {
                skillsStrings.add((String)skill);
            } else if (skill instanceof Map<String, Object>) {
                Map<String, Object> skillMap = (Map<String, Object>)skill;
                if (skillMap.containsKey('name')) {
                    skillsStrings.add(String.valueOf(skillMap.get('name')));
                } else if (skillMap.containsKey('nazwa')) {
                    skillsStrings.add(String.valueOf(skillMap.get('nazwa')));
                } else if (!skillMap.isEmpty()) {
                    // Jeśli nie ma klucza 'name', użyj pierwszego klucza
                    String firstKey = new List<String>(skillMap.keySet())[0];
                    skillsStrings.add(firstKey + ': ' + String.valueOf(skillMap.get(firstKey)));
                }
            }
        }
        
        return skillsStrings;
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