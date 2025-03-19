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
            // Log input data
            System.debug(LoggingLevel.INFO, '=== saveAnalysisResults - START ===');
            System.debug(LoggingLevel.INFO, 'saveAnalysisResults - recordId: ' + recordId);
            System.debug(LoggingLevel.INFO, 'saveAnalysisResults - analysisResults length: ' + (analysisResults != null ? analysisResults.length() : 0));
            
            // Check record type
            String objectType = String.valueOf(recordId.getSobjectType());
            System.debug(LoggingLevel.INFO, 'saveAnalysisResults - objectType: ' + objectType);
            
            try {
                // Parse analysis results
                System.debug(LoggingLevel.INFO, 'saveAnalysisResults - attempting to deserialize JSON');
                Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(analysisResults);
                System.debug(LoggingLevel.INFO, 'saveAnalysisResults - results deserialized successfully with ' + results.size() + ' keys');
                
                // Log keys in analysis results
                System.debug(LoggingLevel.INFO, 'saveAnalysisResults - result keys: ' + results.keySet());
                
                // Detailed logging of data structure
                System.debug(LoggingLevel.INFO, '=== DETAILED ANALYSIS RESULTS STRUCTURE ===');
                for (String key : results.keySet()) {
                    Object value = results.get(key);
                    String valueType = getObjectType(value);
                    System.debug(LoggingLevel.INFO, 'Key: ' + key + ', Type: ' + valueType);
                    
                    // If value is a map, log its keys
                    if (value instanceof Map<String, Object>) {
                        Map<String, Object> nestedMap = (Map<String, Object>)value;
                        System.debug(LoggingLevel.INFO, '  Nested keys for ' + key + ': ' + nestedMap.keySet());
                    }
                    // If value is a list, log its size and type of first element (if exists)
                    else if (value instanceof List<Object>) {
                        List<Object> nestedList = (List<Object>)value;
                        String firstItemType = nestedList.isEmpty() ? 'empty' : getObjectType(nestedList[0]);
                        System.debug(LoggingLevel.INFO, '  List size for ' + key + ': ' + nestedList.size() + ', First item type: ' + firstItemType);
                        
                        // If this is a skills list, log a few first elements
                        if (key.containsIgnoreCase('skill') && !nestedList.isEmpty()) {
                            Integer samplesToLog = Math.min(nestedList.size(), 5);
                            List<Object> samples = new List<Object>();
                            for (Integer i = 0; i < samplesToLog; i++) {
                                samples.add(nestedList[i]);
                            }
                            System.debug(LoggingLevel.INFO, '  Sample skills: ' + samples);
                        }
                    }
                    // For simple types, log the value (if not too long)
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
                
                // Check if key fields we're looking for exist
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
                        
                        // Check if a similar key exists
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
     * Saves analysis results for Job_Application__c object
     * @param recordId ID of the job application
     * @param analysisResults Raw analysis results in JSON format
     * @param results Parsed analysis results
     * @return ID of the created AiAnalysisResult__c record
     */
    private static Id saveJobApplicationResults(Id recordId, String analysisResults, Map<String, Object> results) {
        try {
            System.debug(LoggingLevel.INFO, '=== saveJobApplicationResults - START ===');
            System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - start for recordId: ' + recordId);
            
            // Get candidate and position IDs from job application
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
            
            // Add positionId to analysis results to be able to split skills
            if (!results.containsKey('positionId')) {
                results.put('positionId', positionId);
                System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - Added positionId to results');
            }
            
            // Create AiAnalysisResult__c record
            Id aiResultId = createAiAnalysisResult(results, recordId, 'Job_Application__c');
            
            // Update Job_Application__c to point to the latest analysis
            // This can be done in the future if needed
            
            System.debug(LoggingLevel.INFO, 'saveJobApplicationResults - created AiAnalysisResult__c with ID: ' + aiResultId);
            return aiResultId;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'saveJobApplicationResults - Exception: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'saveJobApplicationResults - Exception type: ' + e.getTypeName());
            System.debug(LoggingLevel.ERROR, 'saveJobApplicationResults - Stack trace: ' + e.getStackTraceString());
            throw e; // Pass exception up to be handled in saveAnalysisResults
        } finally {
            System.debug(LoggingLevel.INFO, '=== saveJobApplicationResults - END ===');
        }
    }
    
    /**
     * Saves analysis results for Candidate__c object
     * @param recordId ID of the candidate
     * @param analysisResults Raw analysis results in JSON format
     * @param results Parsed analysis results
     * @return ID of the created AiAnalysisResult__c record
     */
    private static Id saveCandidateResults(Id recordId, String analysisResults, Map<String, Object> results) {
        try {
            System.debug(LoggingLevel.INFO, '=== saveCandidateResults - START ===');
            System.debug(LoggingLevel.INFO, 'saveCandidateResults - start for recordId: ' + recordId);
            
            // Create AiAnalysisResult__c record
            Id aiResultId = createAiAnalysisResult(results, recordId, 'Candidate__c');
            
            System.debug(LoggingLevel.INFO, 'saveCandidateResults - created AiAnalysisResult__c with ID: ' + aiResultId);
            return aiResultId;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'saveCandidateResults - Exception: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'saveCandidateResults - Exception type: ' + e.getTypeName());
            System.debug(LoggingLevel.ERROR, 'saveCandidateResults - Stack trace: ' + e.getStackTraceString());
            throw e; // Pass exception up to be handled in saveAnalysisResults
        } finally {
            System.debug(LoggingLevel.INFO, '=== saveCandidateResults - END ===');
        }
    }
    
    /**
     * @description Pobiera listę wymaganych umiejętności dla stanowiska
     * @param positionId Id stanowiska
     * @return Lista wymaganych umiejętności
     */
    private static List<String> getPositionSkills(Id positionId) {
        List<String> requiredSkills = new List<String>();
        
        try {
            // Użyj bezpiecznego podejścia z listą zamiast bezpośredniego przypisania
            List<Position__c> positions = [
                SELECT Id, Job_Description__c, Required_Skills__c
                FROM Position__c 
                WHERE Id = :positionId 
                LIMIT 1
            ];
            
            if (!positions.isEmpty()) {
                Position__c position = positions[0];
                
                // Zbiór do przechowywania unikalnych umiejętności z obu źródeł
                Set<String> allSkills = new Set<String>();
                
                // Najpierw sprawdź Required_Skills__c (priorytet)
                if (String.isNotBlank(position.Required_Skills__c)) {
                    List<String> skillsFromField = position.Required_Skills__c.split(',');
                    for (String skill : skillsFromField) {
                        if (String.isNotBlank(skill)) {
                            // Standaryzacja nazwy umiejętności
                            String standardizedSkill = standardizeSkillName(skill.trim());
                            allSkills.add(standardizedSkill);
                        }
                    }
                    System.debug(LoggingLevel.INFO, 'Pobrano wymagane umiejętności z Required_Skills__c: ' + allSkills);
                }
                
                // Następnie sprawdź Job_Description__c
                if (String.isNotBlank(position.Job_Description__c)) {
                    // Use position description as a source of skills
                    String description = position.Job_Description__c.toLowerCase();
                    
                    // List of common technical skills to search for in the description
                    List<String> commonSkills = new List<String>{
                        'java', 'javascript', 'js', 'python', 'c#', 'c++', 'ruby', 'php', 'html', 'css',
                        'sql', 'nosql', 'react', 'angular', 'vue', 'node', 'express', 'django', 'flask',
                        'spring', 'hibernate', 'docker', 'kubernetes', 'aws', 'azure', 'gcp', 'git',
                        'ci/cd', 'agile', 'scrum', 'kanban', 'rest', 'soap', 'api', 'microservices',
                        'salesforce', 'apex', 'visualforce', 'lightning', 'aura', 'lwc', 'soql', 'sosl',
                        'flow', 'flows', 'flow builder', 'process builder', 'formula', 'formulas',
                        'validation rule', 'validation rules', 'workflow', 'workflows', 'approval process',
                        'data loader', 'dataloader', 'integration', 'integrations', 'trigger', 'triggers',
                        'batch', 'batch apex', 'test', 'test class', 'unit test', 'custom object',
                        'custom field', 'permission set', 'profile', 'layouts', 'page layout',
                        'lightning component', 'lightning web component', 'experience cloud', 'community cloud',
                        'heroku', 'mulesoft', 'einstein', 'ai', 'analytics', 'reports', 'dashboards',
                        'cpq', 'pardot', 'marketing cloud', 'commerce cloud', 'service cloud', 'sales cloud'
                    };
                    
                    // Przekształć opis stanowiska na małe litery dla ujednoliconego porównania
                    String lcDescription = description.toLowerCase();
                    
                    for (String skill : commonSkills) {
                        if (lcDescription.contains(skill.toLowerCase())) {
                            // Zachowaj standaryzowany format dla umiejętności
                            String standardizedSkill = standardizeSkillName(skill);
                            allSkills.add(standardizedSkill);
                        }
                    }
                    
                    // Specjalne sprawdzenie dla Flow/flow
                    if (lcDescription.contains('flow') || lcDescription.contains('flows')) {
                        allSkills.add('Flow');
                    }
                    
                    System.debug(LoggingLevel.INFO, 'Pobrano wymagane umiejętności z Job_Description__c: ' + allSkills);
                }
                
                // Konwersja Set na List
                requiredSkills = new List<String>(allSkills);
                System.debug(LoggingLevel.INFO, 'Połączona lista wymaganych umiejętności: ' + requiredSkills);
            } else {
                System.debug(LoggingLevel.WARN, 'Nie znaleziono stanowiska o ID: ' + positionId);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Błąd podczas pobierania umiejętności stanowiska: ' + e.getMessage());
        }
        
        return requiredSkills;
    }
    
    /**
     * @description Standaryzuje nazwę umiejętności do jednolitego formatu
     * @param skill Nazwa umiejętności
     * @return Standaryzowana nazwa umiejętności
     */
    public static String standardizeSkillName(String skill) {
        Map<String, String> standardNames = new Map<String, String>{
            'flow' => 'Flow',
            'flows' => 'Flow',
            'flow builder' => 'Flow Builder',
            'apex' => 'Apex',
            'lwc' => 'Lightning Web Components',
            'lightning web component' => 'Lightning Web Components',
            'lightning web components' => 'Lightning Web Components',
            'visualforce' => 'Visualforce',
            'vf' => 'Visualforce',
            'soql' => 'SOQL',
            'sosl' => 'SOSL',
            'rest' => 'REST API',
            'soap' => 'SOAP API',
            'trigger' => 'Apex Triggers',
            'triggers' => 'Apex Triggers',
            'batch' => 'Batch Apex',
            'batch apex' => 'Batch Apex',
            'sales cloud' => 'Sales Cloud',
            'service' => 'Service Cloud',
            'service cloud' => 'Service Cloud'
        };
        
        String lcSkill = skill.toLowerCase();
        if (standardNames.containsKey(lcSkill)) {
            return standardNames.get(lcSkill);
        }
        
        // Konwencja: pierwsza litera wielka dla większości umiejętności
        if (skill.length() > 0) {
            return skill.substring(0, 1).toUpperCase() + 
                  (skill.length() > 1 ? skill.substring(1).toLowerCase() : '');
        }
        
        return skill;
    }
    
    /**
     * @description Creates an AiAnalysisResult__c record based on analysis results
     * @param results Map of analysis results
     * @param recordId Id of the record for which the analysis result is created
     * @param objectType Type of object for which the analysis result is created
     * @return Id of the created AiAnalysisResult__c record
     */
    private static Id createAiAnalysisResult(Map<String, Object> results, Id recordId, String objectType) {
        try {
            System.debug(LoggingLevel.ERROR, '=== createAiAnalysisResult - START ===');
            System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - recordId: ' + recordId);
            System.debug(LoggingLevel.ERROR, 'createAiAnalysisResult - objectType: ' + objectType);
            
            // Ensure we have valid data
            if (recordId == null || String.isBlank(objectType)) {
                throw new AuraHandledException('Invalid input: recordId and objectType are required');
            }
            
            // Standardize keys for easier field mapping
            Map<String, Object> standardizedResults = standardizeResultKeys(results);
            System.debug(LoggingLevel.ERROR, 'Standardized keys: ' + standardizedResults.keySet());
            
            // Create AiAnalysisResult__c record
            AiAnalysisResult__c result = new AiAnalysisResult__c();
            
            // Set relationship fields based on object type
            if (objectType == 'Job_Application__c') {
                result.Job_Application__c = recordId;
                
                // Get position and candidate from job application
                try {
                    Job_Application__c jobApp = [
                        SELECT Id, Position__c, Candidate__c 
                        FROM Job_Application__c 
                        WHERE Id = :recordId 
                        LIMIT 1
                    ];
                    
                    if (jobApp.Position__c != null) {
                        result.Position__c = jobApp.Position__c;
                    }
                    
                    if (jobApp.Candidate__c != null) {
                        result.Candidate__c = jobApp.Candidate__c;
                    }
                } catch (QueryException e) {
                    System.debug(LoggingLevel.ERROR, 'Error getting Job_Application__c: ' + e.getMessage());
                }
            } else if (objectType == 'Candidate__c') {
                result.Candidate__c = recordId;
                
                // Position might be available in the results from context
                if (standardizedResults.containsKey('positionId') && standardizedResults.get('positionId') instanceof Id) {
                    result.Position__c = (Id)standardizedResults.get('positionId');
                }
            }
            
            // Sanitize raw analysis results - remove any personal information that might have been captured
            Map<String, Object> sanitizedResults = new Map<String, Object>(results);
            
            // Store raw analysis results after sanitization
            result.RawAnalysisResults__c = JSON.serialize(sanitizedResults);
            
            // Map standard fields from standardized results
            if (standardizedResults.containsKey('matchScore')) {
                Object matchScoreObj = standardizedResults.get('matchScore');
                if (matchScoreObj instanceof Decimal) {
                    result.MatchScore__c = (Decimal)matchScoreObj;
                } else if (matchScoreObj instanceof Integer) {
                    result.MatchScore__c = (Integer)matchScoreObj;
                } else if (matchScoreObj instanceof String) {
                    try {
                        result.MatchScore__c = Decimal.valueOf((String)matchScoreObj);
                    } catch (Exception e) {
                        System.debug(LoggingLevel.ERROR, 'Error parsing matchScore: ' + e.getMessage());
                    }
                }
            }
            
            // Handle yearsOfExperience if available
            if (standardizedResults.containsKey('yearsOfExperience')) {
                Object yearsObj = standardizedResults.get('yearsOfExperience');
                String yearsText = '';
                
                if (yearsObj instanceof Decimal) {
                    yearsText = String.valueOf((Decimal)yearsObj) + ' years';
                } else if (yearsObj instanceof Integer) {
                    yearsText = String.valueOf((Integer)yearsObj) + ' years';
                } else if (yearsObj instanceof String) {
                    yearsText = (String)yearsObj;
                }
                
                if (String.isNotBlank(yearsText)) {
                    // Store in a custom field if available, or add to analysis summary
                    if (result.AnalysisSummary__c == null) {
                        result.AnalysisSummary__c = 'Years of Experience: ' + yearsText;
                    } else {
                        result.AnalysisSummary__c = 'Years of Experience: ' + yearsText + '\n\n' + result.AnalysisSummary__c;
                    }
                }
            }
            
            // Map array fields
            result.MatchingSkills__c = JSONToStringList(standardizedResults, 'matchedSkills');
            result.MissingSkills__c = JSONToStringList(standardizedResults, 'missingSkills');
            result.AdditionalSkills__c = JSONToStringList(standardizedResults, 'additionalSkills');
            result.KeyHighlights__c = JSONToStringList(standardizedResults, 'keyHighlights');
            result.PotentialConcerns__c = JSONToStringList(standardizedResults, 'potentialConcerns');
            result.Certifications__c = JSONToStringList(standardizedResults, 'certifications');
            
            // Map text fields
            if (standardizedResults.containsKey('analysisSummary')) {
                Object summaryObj = standardizedResults.get('analysisSummary');
                if (summaryObj instanceof String) {
                    if (result.AnalysisSummary__c == null) {
                        result.AnalysisSummary__c = (String)summaryObj;
                    } else {
                        result.AnalysisSummary__c += '\n\n' + (String)summaryObj;
                    }
                }
            }
            
            // Map recommendation level
            if (standardizedResults.containsKey('recommendationLevel')) {
                Object recLevelObj = standardizedResults.get('recommendationLevel');
                if (recLevelObj instanceof String) {
                    String recLevel = ((String)recLevelObj).toLowerCase().trim();
                    
                    if (recLevel == 'high' || recLevel == 'medium' || recLevel == 'low') {
                        result.RecommendationLevel__c = recLevel.substring(0, 1).toUpperCase() + recLevel.substring(1);
                    }
                }
            }
            
            // Insert record
            insert result;
            
            return result.Id;
        } catch (Exception e) {
            String errorMessage = 'Error creating AiAnalysisResult__c: ' + e.getMessage();
            Logger.error('CVAnalysisController', 'createAiAnalysisResult', errorMessage, e);
            System.debug(LoggingLevel.ERROR, 'Error in createAiAnalysisResult: ' + errorMessage);
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException(errorMessage);
        } finally {
            System.debug(LoggingLevel.ERROR, '=== createAiAnalysisResult - END ===');
        }
    }
    
    /**
     * @description Standaryzuje klucze w wynikach analizy
     * @param results Mapa wyników analizy
     * @return Mapa wyników analizy ze standaryzowanymi kluczami
     */
    private static Map<String, Object> standardizeResultKeys(Map<String, Object> results) {
        Map<String, Object> standardized = new Map<String, Object>();
        
        // Log keys before standardization
        System.debug(LoggingLevel.DEBUG, 'Keys before standardization: ' + results.keySet());
        
        // Copy all original keys
        for (String key : results.keySet()) {
            // Standaryzuj klucz do małych liter dla wewnętrznego użytku mapowania
            String lowercaseKey = key.toLowerCase();
            
            // Zachowaj oryginalny klucz w danych wyjściowych
            standardized.put(key, results.get(key));
            
            // Log data type for each key
            Object value = results.get(key);
            System.debug(LoggingLevel.DEBUG, 'Key: ' + key + ', Type: ' + getObjectType(value));
            
            // If it's a map, log its keys
            if (value instanceof Map<String, Object>) {
                Map<String, Object> nestedMap = (Map<String, Object>)value;
                System.debug(LoggingLevel.DEBUG, '  Nested keys for ' + key + ': ' + nestedMap.keySet());
                
                // Sprawdź, czy certyfikaty nie znajdują się w zagnieżdżonym obiekcie
                if ((lowercaseKey.equals('resume') || lowercaseKey.equals('candidate') || 
                     lowercaseKey.equals('analysis') || lowercaseKey.equals('result')) && 
                    containsKeyCaseInsensitive(nestedMap, 'certifications') && 
                    !containsKeyCaseInsensitive(standardized, 'certifications')) {
                    standardized.put('certifications', getValueCaseInsensitive(nestedMap, 'certifications'));
                    System.debug(LoggingLevel.DEBUG, 'Found certifications in nested object: ' + key);
                }
            }
            // If it's a list, log its size and a few first elements
            else if (value instanceof List<Object>) {
                List<Object> nestedList = (List<Object>)value;
                System.debug(LoggingLevel.DEBUG, '  List size for ' + key + ': ' + nestedList.size());
                if (!nestedList.isEmpty()) {
                    Integer samplesToLog = Math.min(nestedList.size(), 3);
                    List<Object> samples = new List<Object>();
                    for (Integer i = 0; i < samplesToLog; i++) {
                        samples.add(nestedList[i]);
                    }
                    System.debug(LoggingLevel.DEBUG, '  Sample elements: ' + samples);
                }
            }
        }
        
        // Specjalnie obsługujemy "certifications" - zapewniamy, że zawsze istnieje w wyniku
        if (!containsKeyCaseInsensitive(standardized, 'certifications')) {
            // Sprawdź czy certyfikaty są wymienione w innym miejscu
            List<String> possibleCertKeysExact = new List<String>{'certifications', 'certificates', 'certification', 'certificate'};
            List<String> possibleCertKeysPartial = new List<String>{'cert', 'certs', 'certyf', 'certif'};
            
            Boolean foundCertifications = false;
            
            // Najpierw sprawdź dokładne nazwy kluczy
            for (String certKey : possibleCertKeysExact) {
                if (containsKeyCaseInsensitive(results, certKey)) {
                    standardized.put('certifications', getValueCaseInsensitive(results, certKey));
                    System.debug(LoggingLevel.DEBUG, 'Found certifications under key: ' + certKey);
                    foundCertifications = true;
                    break;
                }
            }
            
            // Jeśli nie znaleziono, sprawdź częściowe dopasowania
            if (!foundCertifications) {
                for (String key : results.keySet()) {
                    String lowercaseKey = key.toLowerCase();
                    for (String partialKey : possibleCertKeysPartial) {
                        if (lowercaseKey.contains(partialKey.toLowerCase())) {
                            standardized.put('certifications', results.get(key));
                            System.debug(LoggingLevel.DEBUG, 'Found certifications with partial key match: ' + key);
                            foundCertifications = true;
                            break;
                        }
                    }
                    if (foundCertifications) break;
                }
            }
            
            // Sprawdź, czy certyfikaty nie znajdują się w personalData
            if (!foundCertifications && containsKeyCaseInsensitive(results, 'personalData')) {
                Object personalDataObj = getValueCaseInsensitive(results, 'personalData');
                if (personalDataObj instanceof Map<String, Object>) {
                    Map<String, Object> personalData = (Map<String, Object>)personalDataObj;
                    for (String certKey : possibleCertKeysExact) {
                        if (containsKeyCaseInsensitive(personalData, certKey)) {
                            standardized.put('certifications', getValueCaseInsensitive(personalData, certKey));
                            System.debug(LoggingLevel.DEBUG, 'Found certifications in personalData: ' + certKey);
                            foundCertifications = true;
                            break;
                        }
                    }
                    
                    if (!foundCertifications) {
                        for (String key : personalData.keySet()) {
                            String lowercaseKey = key.toLowerCase();
                            for (String partialKey : possibleCertKeysPartial) {
                                if (lowercaseKey.contains(partialKey.toLowerCase())) {
                                    standardized.put('certifications', personalData.get(key));
                                    System.debug(LoggingLevel.DEBUG, 'Found certifications in personalData with partial key match: ' + key);
                                    foundCertifications = true;
                                    break;
                                }
                            }
                            if (foundCertifications) break;
                        }
                    }
                }
            }
            
            // Jeśli ciągle nie znaleziono certyfikatów, ustaw jako pustą tablicę
            if (!foundCertifications) {
                standardized.put('certifications', new List<String>());
                System.debug(LoggingLevel.DEBUG, 'No certifications found, using empty list');
            }
        }
        
        // Zapewnij, że certifications jest zawsze listą
        Object certObj = standardized.get('certifications');
        if (certObj != null) {
            if (certObj instanceof String) {
                String certStr = (String)certObj;
                List<String> certList = new List<String>();
                
                // Obsłuż różne formaty separacji certyfikatów
                if (certStr.contains(',')) {
                    for (String cert : certStr.split(',')) {
                        certList.add(cert.trim());
                    }
                } else if (certStr.contains('\n')) {
                    for (String cert : certStr.split('\n')) {
                        certList.add(cert.trim());
                    }
                } else if (certStr.contains(';')) {
                    for (String cert : certStr.split(';')) {
                        certList.add(cert.trim());
                    }
                } else {
                    certList.add(certStr.trim());
                }
                
                standardized.put('certifications', certList);
                System.debug(LoggingLevel.DEBUG, 'Converted certifications from string to list: ' + certList);
            } else if (!(certObj instanceof List<Object>)) {
                // Jeśli to nie jest ani String, ani List, konwertuj na String i dodaj jako pojedynczy element listy
                List<String> certList = new List<String>{String.valueOf(certObj)};
                standardized.put('certifications', certList);
                System.debug(LoggingLevel.DEBUG, 'Converted non-list certifications to list: ' + certList);
            }
        }
        
        // Handle "technicalSkills" key (English version)
        if (results.containsKey('technicalSkills')) {
            Object techSkillsObj = results.get('technicalSkills');
            System.debug(LoggingLevel.DEBUG, 'Found key "technicalSkills", type: ' + getObjectType(techSkillsObj));
            
            List<String> allSkills = new List<String>();
            
            // Process different data formats
            if (techSkillsObj instanceof Map<String, Object>) {
                Map<String, Object> techSkillsMap = (Map<String, Object>)techSkillsObj;
                System.debug(LoggingLevel.DEBUG, 'technicalSkills as map, keys: ' + techSkillsMap.keySet());
                
                // Process skills map
                for (String skillKey : techSkillsMap.keySet()) {
                    Object skillValue = techSkillsMap.get(skillKey);
                    if (skillValue instanceof String) {
                        allSkills.add(skillKey + ': ' + (String)skillValue);
                    } else if (skillValue instanceof List<Object>) {
                        allSkills.add(skillKey);
                    } else {
                        allSkills.add(skillKey);
                    }
                }
            } else if (techSkillsObj instanceof List<Object>) {
                List<Object> techSkillsList = (List<Object>)techSkillsObj;
                System.debug(LoggingLevel.DEBUG, 'technicalSkills as list, size: ' + techSkillsList.size());
                
                // Process skills list
                for (Object skill : techSkillsList) {
                    if (skill instanceof String) {
                        allSkills.add((String)skill);
                    } else if (skill instanceof Map<String, Object>) {
                        Map<String, Object> skillMap = (Map<String, Object>)skill;
                        if (skillMap.containsKey('name')) {
                            allSkills.add(String.valueOf(skillMap.get('name')));
                        } else if (!skillMap.isEmpty()) {
                            String firstKey = new List<String>(skillMap.keySet())[0];
                            allSkills.add(firstKey);
                        }
                    } else {
                        allSkills.add(String.valueOf(skill));
                    }
                }
            } else if (techSkillsObj instanceof String) {
                String techSkillsStr = (String)techSkillsObj;
                System.debug(LoggingLevel.DEBUG, 'technicalSkills as string: ' + techSkillsStr);
                
                // Process skills string
                if (techSkillsStr.contains(',')) {
                    for (String skill : techSkillsStr.split(',')) {
                        allSkills.add(skill.trim());
                    }
                } else {
                    allSkills.add(techSkillsStr.trim());
                }
            }
            
            // Set skills in standard keys
            if (!allSkills.isEmpty()) {
                standardized.put('skills', allSkills);
                standardized.put('matchedSkills', allSkills);  // By default, all skills are matched
                standardized.put('additionalSkills', new List<String>());  // Empty list of additional skills
                System.debug(LoggingLevel.DEBUG, 'Set skills from "technicalSkills": ' + allSkills);
            }
        }
        
        // Also check for "skills" key directly
        if (results.containsKey('skills') && !standardized.containsKey('skills')) {
            Object skillsObj = results.get('skills');
            List<String> allSkills = new List<String>();
            
            // Convert skills to list of strings
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
            
            if (!allSkills.isEmpty()) {
                standardized.put('skills', allSkills);
                standardized.put('matchedSkills', allSkills);
                standardized.put('additionalSkills', new List<String>());
                System.debug(LoggingLevel.DEBUG, 'Set skills from "skills": ' + allSkills);
            }
        }
        
        // If we have positionId, get required skills and split skills into matched and additional
        if (results.containsKey('positionId') && standardized.containsKey('skills')) {
            Id positionId = (Id)results.get('positionId');
            List<String> requiredSkills = getPositionSkills(positionId);
            System.debug(LoggingLevel.DEBUG, 'Retrieved required skills for position: ' + requiredSkills);
            
            if (!requiredSkills.isEmpty()) {
                Object skillsObj = standardized.get('skills');
                List<String> allSkills = new List<String>();
                
                // Convert skills to list of strings
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
                
                // Split skills into matched and additional
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
                
                // Set matched and additional skills
                if (!matchedSkills.isEmpty()) {
                    standardized.put('matchedSkills', matchedSkills);
                    System.debug(LoggingLevel.DEBUG, 'Set matchedSkills: ' + matchedSkills);
                }
                
                standardized.put('additionalSkills', additionalSkills);
                System.debug(LoggingLevel.DEBUG, 'Set additionalSkills: ' + additionalSkills);
            }
        }
        
        // Specjalne mapowanie dla pól, które mogą mieć różne nazwy
        // Map analysisSummary <-> summary dla zgodności
        if (standardized.containsKey('analysisSummary') && !standardized.containsKey('summary')) {
            standardized.put('summary', standardized.get('analysisSummary'));
            System.debug(LoggingLevel.DEBUG, 'Mapped analysisSummary to summary');
        } else if (standardized.containsKey('summary') && !standardized.containsKey('analysisSummary')) {
            standardized.put('analysisSummary', standardized.get('summary'));
            System.debug(LoggingLevel.DEBUG, 'Mapped summary to analysisSummary');
        }
        
        return standardized;
    }
    
    /**
     * Konwertuje pole JSON o podanej nazwie na ciąg znaków rozdzielony separatorem
     * @param jsonMap Mapa zawierająca dane JSON
     * @param fieldName Nazwa pola do konwersji
     * @param separator Separator do łączenia elementów (domyślnie przecinek)
     * @return Ciąg znaków powstały z połączenia elementów listy
     */
    private static String JSONToStringList(Map<String, Object> jsonMap, String fieldName, String separator) {
        if (jsonMap == null || !jsonMap.containsKey(fieldName)) {
            return null;
        }
        
        Object fieldObj = jsonMap.get(fieldName);
        List<String> stringList = new List<String>();
        
        // Jeśli to lista obiektów
        if (fieldObj instanceof List<Object>) {
            List<Object> objList = (List<Object>)fieldObj;
            
            for (Object item : objList) {
                if (item instanceof String) {
                    stringList.add((String)item);
                } else if (item != null) {
                    stringList.add(String.valueOf(item));
                }
            }
        } 
        // Jeśli to pojedynczy string, sprawdź czy zawiera separatory
        else if (fieldObj instanceof String) {
            String fieldStr = (String)fieldObj;
            
            if (fieldStr.contains(',')) {
                // Jeśli zawiera przecinki
                for (String item : fieldStr.split(',')) {
                    String trimmedItem = item.trim();
                    if (String.isNotBlank(trimmedItem)) {
                        stringList.add(trimmedItem);
                    }
                }
            } else if (fieldStr.contains(';')) {
                // Jeśli zawiera średniki
                for (String item : fieldStr.split(';')) {
                    String trimmedItem = item.trim();
                    if (String.isNotBlank(trimmedItem)) {
                        stringList.add(trimmedItem);
                    }
                }
            } else if (fieldStr.contains('\n')) {
                // Jeśli zawiera znaki nowej linii
                for (String item : fieldStr.split('\n')) {
                    String trimmedItem = item.trim();
                    if (String.isNotBlank(trimmedItem)) {
                        stringList.add(trimmedItem);
                    }
                }
            } else {
                // Jeśli to pojedynczy string bez separatorów
                if (String.isNotBlank(fieldStr)) {
                    stringList.add(fieldStr);
                }
            }
        }
        
        // Określenie separatora wyjściowego na podstawie typu pola
        String outputSeparator = separator;
        
        // Dla niektórych typów pól możemy chcieć użyć innych separatorów
        if (fieldName.equals('keyHighlights') || fieldName.equals('potentialConcerns')) {
            // Dla list punktowanych używamy znaków nowej linii jako separatora
            outputSeparator = '\n';
        } else if (fieldName.equals('certifications')) {
            // Dla certyfikatów również używamy znaków nowej linii
            outputSeparator = '\n';
        }
        
        return String.isNotBlank(String.join(stringList, outputSeparator)) ? 
            String.join(stringList, outputSeparator) : null;
    }
    
    /**
     * Konwertuje pole JSON o podanej nazwie na ciąg znaków rozdzielony przecinkami
     * @param jsonMap Mapa zawierająca dane JSON
     * @param fieldName Nazwa pola do konwersji
     * @return Ciąg znaków powstały z połączenia elementów listy
     */
    private static String JSONToStringList(Map<String, Object> jsonMap, String fieldName) {
        return JSONToStringList(jsonMap, fieldName, ', ');
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

    /**
     * Sprawdza, czy mapa zawiera klucz, ignorując wielkość liter
     * @param dataMap Mapa do sprawdzenia
     * @param key Klucz do znalezienia (case-insensitive)
     * @return true jeśli klucz istnieje (w dowolnej wielkości liter), false w przeciwnym razie
     */
    private static Boolean containsKeyCaseInsensitive(Map<String, Object> dataMap, String key) {
        if (dataMap == null || key == null) return false;
        
        String lowercaseKey = key.toLowerCase();
        for (String mapKey : dataMap.keySet()) {
            if (mapKey.toLowerCase() == lowercaseKey) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * Pobiera wartość z mapy na podstawie klucza, ignorując wielkość liter
     * @param dataMap Mapa, z której pobierane są dane
     * @param key Klucz do znalezienia (case-insensitive)
     * @return Obiekt odpowiadający kluczowi lub null, jeśli nie znaleziono
     */
    private static Object getValueCaseInsensitive(Map<String, Object> dataMap, String key) {
        if (dataMap == null || key == null) return null;
        
        String lowercaseKey = key.toLowerCase();
        for (String mapKey : dataMap.keySet()) {
            if (mapKey.toLowerCase() == lowercaseKey) {
                return dataMap.get(mapKey);
            }
        }
        return null;
    }
}