/**
 * @description Controller for AI Analysis operations
 * @author Anna Polanczyk
 */
public with sharing class AiAnalysisController {
    
    /**
     * @description Get the latest analysis for a record (Candidate__c or Job_Application__c)
     * @param recordId ID of the record
     * @return ID of the latest AiAnalysisResult__c record or null if none found
     */
    @AuraEnabled
    public static Id getLatestAnalysisForRecord(Id recordId) {
        try {
            // Determine the object type
            String objectType = String.valueOf(recordId.getSobjectType());
            
            // Query for the latest analysis based on object type
            if (objectType == 'Candidate__c') {
                return getLatestAnalysisForCandidate(recordId);
            } else if (objectType == 'Job_Application__c') {
                return getLatestAnalysisForJobApplication(recordId);
            } else {
                throw new AuraHandledException('Unsupported record type: ' + objectType);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving analysis: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get the latest analysis for a candidate
     * @param candidateId ID of the candidate
     * @return ID of the latest AiAnalysisResult__c record or null if none found
     */
    private static Id getLatestAnalysisForCandidate(Id candidateId) {
        List<AiAnalysisResult__c> analyses = [
            SELECT Id, CreatedDate
            FROM AiAnalysisResult__c
            WHERE Candidate__c = :candidateId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        return analyses.isEmpty() ? null : analyses[0].Id;
    }
    
    /**
     * @description Get the latest analysis for a job application
     * @param jobApplicationId ID of the job application
     * @return ID of the latest AiAnalysisResult__c record or null if none found
     */
    private static Id getLatestAnalysisForJobApplication(Id jobApplicationId) {
        List<AiAnalysisResult__c> analyses = [
            SELECT Id, CreatedDate
            FROM AiAnalysisResult__c
            WHERE Job_Application__c = :jobApplicationId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        return analyses.isEmpty() ? null : analyses[0].Id;
    }
} 