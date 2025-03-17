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
            
            // Mapuj klucze z wyników analizy na standardowe klucze
            Map<String, Object> standardizedResults = standardizeResultKeys(results);
            System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - Standardized keys: ' + standardizedResults.keySet());
            
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
            
            // Ustaw MatchScore
            try {
                if (standardizedResults.containsKey('matchScore') && Schema.SObjectType.AiAnalysisResult__c.fields.MatchScore__c.isCreateable()) {
                    Object matchScoreObj = standardizedResults.get('matchScore');
                    Decimal matchScore = extractMatchScore(matchScoreObj);
                    aiResult.MatchScore__c = matchScore;
                    System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - Set MatchScore__c: ' + matchScore);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Error setting MatchScore__c: ' + e.getMessage());
            }
            
            // Ustaw MatchingSkills
            try {
                if (standardizedResults.containsKey('matchedSkills') && Schema.SObjectType.AiAnalysisResult__c.fields.MatchingSkills__c.isCreateable()) {
                    Object matchedSkillsObj = standardizedResults.get('matchedSkills');
                    String matchedSkills = '';
                    
                    if (matchedSkillsObj instanceof List<Object>) {
                        matchedSkills = extractSkillsAsString((List<Object>)matchedSkillsObj);
                    } else if (matchedSkillsObj instanceof String) {
                        matchedSkills = (String)matchedSkillsObj;
                    }
                    
                    if (matchedSkills.length() <= 32768) { // Sprawdź limit długości pola
                        aiResult.MatchingSkills__c = matchedSkills;
                        System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - Set MatchingSkills__c: ' + matchedSkills);
                    } else {
                        System.debug(LoggingLevel.WARN, 'createAiAnalysisResult - MatchingSkills__c exceeds field length limit, truncating');
                        aiResult.MatchingSkills__c = matchedSkills.substring(0, 32768);
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Error setting MatchingSkills__c: ' + e.getMessage());
            }
            
            // Ustaw MissingSkills
            try {
                if (standardizedResults.containsKey('missingSkills') && Schema.SObjectType.AiAnalysisResult__c.fields.MissingSkills__c.isCreateable()) {
                    Object missingSkillsObj = standardizedResults.get('missingSkills');
                    String missingSkills = '';
                    
                    if (missingSkillsObj instanceof List<Object>) {
                        missingSkills = extractSkillsAsString((List<Object>)missingSkillsObj);
                    } else if (missingSkillsObj instanceof String) {
                        missingSkills = (String)missingSkillsObj;
                    }
                    
                    if (missingSkills.length() <= 32768) {
                        aiResult.MissingSkills__c = missingSkills;
                        System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - Set MissingSkills__c: ' + missingSkills);
                    } else {
                        System.debug(LoggingLevel.WARN, 'createAiAnalysisResult - MissingSkills__c exceeds field length limit, truncating');
                        aiResult.MissingSkills__c = missingSkills.substring(0, 32768);
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Error setting MissingSkills__c: ' + e.getMessage());
            }
            
            // Ustaw AdditionalSkills
            try {
                if (Schema.SObjectType.AiAnalysisResult__c.fields.AdditionalSkills__c.isCreateable()) {
                    String additionalSkills = '';
                    
                    if (standardizedResults.containsKey('additionalSkills')) {
                        Object additionalSkillsObj = standardizedResults.get('additionalSkills');
                        
                        if (additionalSkillsObj instanceof List<Object>) {
                            additionalSkills = extractSkillsAsString((List<Object>)additionalSkillsObj);
                        } else if (additionalSkillsObj instanceof String) {
                            additionalSkills = (String)additionalSkillsObj;
                        }
                    } else if (standardizedResults.containsKey('skills')) {
                        // Jeśli nie ma additionalSkills, ale są skills, użyj ich jako additionalSkills
                        Object skillsObj = standardizedResults.get('skills');
                        
                        if (skillsObj instanceof List<Object>) {
                            additionalSkills = extractSkillsAsString((List<Object>)skillsObj);
                        } else if (skillsObj instanceof String) {
                            additionalSkills = (String)skillsObj;
                        }
                    }
                    
                    if (additionalSkills.length() <= 32768) {
                        aiResult.AdditionalSkills__c = additionalSkills;
                        System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - Set AdditionalSkills__c: ' + additionalSkills);
                    } else {
                        System.debug(LoggingLevel.WARN, 'createAiAnalysisResult - AdditionalSkills__c exceeds field length limit, truncating');
                        aiResult.AdditionalSkills__c = additionalSkills.substring(0, 32768);
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Error setting AdditionalSkills__c: ' + e.getMessage());
            }
            
            // Ustaw AnalysisSummary
            try {
                if (standardizedResults.containsKey('summary') && Schema.SObjectType.AiAnalysisResult__c.fields.AnalysisSummary__c.isCreateable()) {
                    Object summaryObj = standardizedResults.get('summary');
                    String summary = '';
                    
                    if (summaryObj instanceof String) {
                        summary = (String)summaryObj;
                    } else if (summaryObj instanceof List<Object>) {
                        List<String> summaryList = new List<String>();
                        for (Object item : (List<Object>)summaryObj) {
                            if (item instanceof String) {
                                summaryList.add((String)item);
                            }
                        }
                        summary = String.join(summaryList, '\n');
                    }
                    
                    if (summary.length() <= 32768) {
                        aiResult.AnalysisSummary__c = summary;
                        System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - Set AnalysisSummary__c: ' + summary);
                    } else {
                        System.debug(LoggingLevel.WARN, 'createAiAnalysisResult - AnalysisSummary__c exceeds field length limit, truncating');
                        aiResult.AnalysisSummary__c = summary.substring(0, 32768);
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Error setting AnalysisSummary__c: ' + e.getMessage());
            }
            
            // Ustaw RecommendationLevel na podstawie matchScore
            try {
                if (aiResult.MatchScore__c != null && Schema.SObjectType.AiAnalysisResult__c.fields.RecommendationLevel__c.isCreateable()) {
                    if (aiResult.MatchScore__c >= 0.75) {
                        aiResult.RecommendationLevel__c = 'High';
                    } else if (aiResult.MatchScore__c >= 0.5) {
                        aiResult.RecommendationLevel__c = 'Medium';
                    } else {
                        aiResult.RecommendationLevel__c = 'Low';
                    }
                    System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - Set RecommendationLevel__c: ' + aiResult.RecommendationLevel__c);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Error setting RecommendationLevel__c: ' + e.getMessage());
            }
            
            // Ustaw KeyHighlights
            try {
                if (standardizedResults.containsKey('keyHighlights') && Schema.SObjectType.AiAnalysisResult__c.fields.KeyHighlights__c.isCreateable()) {
                    Object keyHighlightsObj = standardizedResults.get('keyHighlights');
                    String keyHighlights = '';
                    
                    if (keyHighlightsObj instanceof String) {
                        keyHighlights = (String)keyHighlightsObj;
                    } else if (keyHighlightsObj instanceof List<Object>) {
                        List<String> highlights = new List<String>();
                        for (Object highlight : (List<Object>)keyHighlightsObj) {
                            if (highlight instanceof String) {
                                highlights.add((String)highlight);
                            }
                        }
                        keyHighlights = String.join(highlights, '\n');
                    }
                    
                    if (keyHighlights.length() <= 32768) {
                        aiResult.KeyHighlights__c = keyHighlights;
                        System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - Set KeyHighlights__c: ' + keyHighlights);
                    } else {
                        System.debug(LoggingLevel.WARN, 'createAiAnalysisResult - KeyHighlights__c exceeds field length limit, truncating');
                        aiResult.KeyHighlights__c = keyHighlights.substring(0, 32768);
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Error setting KeyHighlights__c: ' + e.getMessage());
            }
            
            // Ustaw PotentialConcerns
            try {
                if ((standardizedResults.containsKey('potentialConcerns') || standardizedResults.containsKey('concerns')) && 
                    Schema.SObjectType.AiAnalysisResult__c.fields.PotentialConcerns__c.isCreateable()) {
                    Object concernsObj = standardizedResults.containsKey('potentialConcerns') ? 
                        standardizedResults.get('potentialConcerns') : standardizedResults.get('concerns');
                    
                    String concerns = '';
                    if (concernsObj instanceof String) {
                        concerns = (String)concernsObj;
                    } else if (concernsObj instanceof List<Object>) {
                        List<String> concernsList = new List<String>();
                        for (Object concern : (List<Object>)concernsObj) {
                            if (concern instanceof String) {
                                concernsList.add((String)concern);
                            }
                        }
                        concerns = String.join(concernsList, '\n');
                    }
                    
                    if (concerns.length() <= 32768) {
                        aiResult.PotentialConcerns__c = concerns;
                        System.debug(LoggingLevel.INFO, 'createAiAnalysisResult - Set PotentialConcerns__c: ' + concerns);
                    } else {
                        System.debug(LoggingLevel.WARN, 'createAiAnalysisResult - PotentialConcerns__c exceeds field length limit, truncating');
                        aiResult.PotentialConcerns__c = concerns.substring(0, 32768);
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - Error setting PotentialConcerns__c: ' + e.getMessage());
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
     * Mapuje klucze z wyników analizy na standardowe klucze używane w kodzie
     * @param results Mapa wyników analizy
     * @return Mapa ze znormalizowanymi kluczami
     */
    private static Map<String, Object> standardizeResultKeys(Map<String, Object> results) {
        Map<String, Object> standardized = new Map<String, Object>(results);
        Map<String, String> keyMappings = new Map<String, String>();
        
        // Definiuj mapowania kluczy (format: 'standardowy_klucz' => 'możliwe_alternatywne_klucze')
        keyMappings.put('matchScore', 'match_score,dopasowanie,wynik_dopasowania,score,wynik');
        keyMappings.put('matchedSkills', 'matched_skills,dopasowane_umiejętności,pasujące_umiejętności,matching_skills');
        keyMappings.put('missingSkills', 'missing_skills,brakujące_umiejętności,niedobór_umiejętności');
        keyMappings.put('additionalSkills', 'additional_skills,dodatkowe_umiejętności,inne_umiejętności');
        keyMappings.put('skills', 'umiejętności,technologie,technologies,tech_skills');
        keyMappings.put('summary', 'podsumowanie,streszczenie,overview');
        keyMappings.put('keyHighlights', 'key_highlights,główne_punkty,zalety,strengths,mocne_strony');
        keyMappings.put('potentialConcerns', 'potential_concerns,concerns,obawy,słabe_strony,weaknesses,wady');
        
        // Sprawdź każdy standardowy klucz
        for (String standardKey : keyMappings.keySet()) {
            // Jeśli standardowy klucz już istnieje, nie rób nic
            if (standardized.containsKey(standardKey)) {
                continue;
            }
            
            // Sprawdź alternatywne klucze
            List<String> alternativeKeys = keyMappings.get(standardKey).split(',');
            for (String altKey : alternativeKeys) {
                // Sprawdź dokładne dopasowanie
                if (results.containsKey(altKey)) {
                    standardized.put(standardKey, results.get(altKey));
                    System.debug(LoggingLevel.INFO, 'standardizeResultKeys - Mapped ' + altKey + ' to ' + standardKey);
                    break;
                }
                
                // Sprawdź częściowe dopasowanie (zawieranie)
                for (String actualKey : results.keySet()) {
                    if (actualKey.containsIgnoreCase(altKey) || altKey.containsIgnoreCase(actualKey)) {
                        standardized.put(standardKey, results.get(actualKey));
                        System.debug(LoggingLevel.INFO, 'standardizeResultKeys - Mapped similar key ' + actualKey + ' to ' + standardKey);
                        break;
                    }
                }
            }
        }
        
        // Sprawdź specjalne przypadki dla struktury danych
        for (String key : results.keySet()) {
            // Sprawdź, czy mamy sekcję "Umiejętności techniczne" lub podobną
            if (key.containsIgnoreCase('umiejętności') || key.containsIgnoreCase('skills')) {
                Object value = results.get(key);
                if (value instanceof Map<String, Object>) {
                    Map<String, Object> skillsMap = (Map<String, Object>)value;
                    
                    // Jeśli nie mamy jeszcze standardowego klucza 'skills', dodaj go
                    if (!standardized.containsKey('skills')) {
                        List<String> extractedSkills = new List<String>();
                        for (String skillKey : skillsMap.keySet()) {
                            Object skillValue = skillsMap.get(skillKey);
                            if (skillValue instanceof String) {
                                extractedSkills.add(skillKey + ': ' + (String)skillValue);
                            } else {
                                extractedSkills.add(skillKey);
                            }
                        }
                        standardized.put('skills', extractedSkills);
                        System.debug(LoggingLevel.INFO, 'standardizeResultKeys - Extracted skills from map: ' + key);
                    }
                }
            }
            
            // Sprawdź, czy mamy sekcję "Doświadczenie zawodowe" lub podobną, która może zawierać umiejętności
            if (key.containsIgnoreCase('doświadczenie') || key.containsIgnoreCase('experience')) {
                Object value = results.get(key);
                if (value instanceof Map<String, Object> && !standardized.containsKey('skills')) {
                    Map<String, Object> expMap = (Map<String, Object>)value;
                    List<String> extractedSkills = new List<String>();
                    
                    // Próbuj znaleźć umiejętności w doświadczeniu
                    for (String expKey : expMap.keySet()) {
                        if (expKey.containsIgnoreCase('umiejętności') || expKey.containsIgnoreCase('skills') || 
                            expKey.containsIgnoreCase('technologie') || expKey.containsIgnoreCase('technologies')) {
                            Object skillsValue = expMap.get(expKey);
                            if (skillsValue instanceof List<Object>) {
                                extractedSkills.addAll(extractSkillsAsList((List<Object>)skillsValue));
                            } else if (skillsValue instanceof String) {
                                extractedSkills.add((String)skillsValue);
                            }
                        }
                    }
                    
                    if (!extractedSkills.isEmpty()) {
                        standardized.put('skills', extractedSkills);
                        System.debug(LoggingLevel.INFO, 'standardizeResultKeys - Extracted skills from experience section');
                    }
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