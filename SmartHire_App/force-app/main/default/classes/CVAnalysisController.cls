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
            // Sprawdź typ rekordu
            String objectType = String.valueOf(recordId.getSobjectType());
            
            // Parsuj wyniki analizy
            Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(analysisResults);
            
            if (objectType == 'Job_Application__c') {
                return saveJobApplicationResults(recordId, analysisResults, results);
            } 
            else if (objectType == 'Candidate__c') {
                return saveCandidateResults(recordId, analysisResults, results);
            } 
            else {
                throw new AuraHandledException('Unsupported record type: ' + objectType);
            }
        } catch (Exception e) {
            Logger.error('CVAnalysisController', 'saveAnalysisResults', 'Error saving analysis results', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Zapisuje wyniki analizy dla obiektu Job_Application__c
     * @param recordId ID aplikacji o pracę
     * @param analysisResults Surowe wyniki analizy w formacie JSON
     * @param results Sparsowane wyniki analizy
     * @return ID zaktualizowanego rekordu
     */
    private static Id saveJobApplicationResults(Id recordId, String analysisResults, Map<String, Object> results) {
        // Sprawdź uprawnienia
        SecurityUtils.checkUpdateAccess(Job_Application__c.SObjectType, 
            new List<String>{'Analysis_Results__c', 'Analysis_Score__c', 'Skills_Identified__c'});
        // Powyższa metoda sprawdza zarówno uprawnienia do aktualizacji obiektu (isUpdateable), 
        // jak i uprawnienia do aktualizacji poszczególnych pól
        
        // Sprawdź uprawnienia do aktualizacji obiektu
        if (!Schema.SObjectType.Job_Application__c.isUpdateable()) {
            throw new AuraHandledException('Brak uprawnień do aktualizacji obiektów Job_Application__c');
        }
        
        // Przygotuj dane do zapisu
        Job_Application__c app = new Job_Application__c(
            Id = recordId,
            Analysis_Results__c = analysisResults,
            Analysis_Date__c = Datetime.now()
        );
        
        // Dodaj wynik dopasowania, jeśli istnieje
        if (results.containsKey('matchScore')) {
            app.Analysis_Score__c = extractMatchScore(results.get('matchScore'));
        }
        
        // Dodaj zidentyfikowane umiejętności, jeśli istnieją
        if (results.containsKey('skills')) {
            app.Skills_Identified__c = extractSkillsFromResults(results);
        }
        
        // Zapisz zmiany z wymuszeniem sprawdzania uprawnień CRUD
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.OptAllOrNone = true;
        Database.SaveResult result = Database.update(app, dmlOptions);
        if (!result.isSuccess()) {
            throw new AuraHandledException('Error updating Job_Application__c: ' + result.getErrors()[0].getMessage());
        }
        return recordId;
    }
    
    /**
     * Zapisuje wyniki analizy dla obiektu Candidate__c
     * @param recordId ID kandydata
     * @param analysisResults Surowe wyniki analizy w formacie JSON
     * @param results Sparsowane wyniki analizy
     * @return ID zaktualizowanego rekordu
     */
    private static Id saveCandidateResults(Id recordId, String analysisResults, Map<String, Object> results) {
        // Sprawdź uprawnienia
        SecurityUtils.checkUpdateAccess(Candidate__c.SObjectType, 
            new List<String>{'Analysis_Results__c', 'Skills__c'});
        // Powyższa metoda sprawdza zarówno uprawnienia do aktualizacji obiektu (isUpdateable), 
        // jak i uprawnienia do aktualizacji poszczególnych pól
        
        // Sprawdź uprawnienia do aktualizacji obiektu
        if (!Schema.SObjectType.Candidate__c.isUpdateable()) {
            throw new AuraHandledException('Brak uprawnień do aktualizacji obiektów Candidate__c');
        }
        
        // Przygotuj dane do zapisu
        Candidate__c candidate = new Candidate__c(
            Id = recordId,
            Analysis_Results__c = analysisResults,
            Last_Analysis_Date__c = Datetime.now()
        );
        
        // Dodaj zidentyfikowane umiejętności, jeśli istnieją
        if (results.containsKey('skills')) {
            candidate.Skills__c = extractSkillsFromResults(results);
        }
        
        // Zapisz zmiany z wymuszeniem sprawdzania uprawnień CRUD
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.OptAllOrNone = true;
        Database.SaveResult result = Database.update(candidate, dmlOptions);
        if (!result.isSuccess()) {
            throw new AuraHandledException('Error updating Candidate__c: ' + result.getErrors()[0].getMessage());
        }
        return recordId;
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
     * Ekstrahuje wynik dopasowania z obiektu i konwertuje go na Decimal
     * @param matchScoreObj Obiekt reprezentujący wynik dopasowania
     * @return Wynik dopasowania jako Decimal lub null jeśli konwersja nie jest możliwa
     */
    private static Decimal extractMatchScore(Object matchScoreObj) {
        if (matchScoreObj instanceof Decimal) {
            return (Decimal)matchScoreObj;
        } else if (matchScoreObj instanceof String) {
            try {
                return Decimal.valueOf((String)matchScoreObj);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Could not convert matchScore to Decimal: ' + e.getMessage());
            }
        }
        return null;
    }
}