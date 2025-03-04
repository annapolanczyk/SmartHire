/**
 * Controller for Candidate Conversion operations
 */
public with sharing class CandidateConversionController {
    
    /**
     * Convert candidate to employee
     * @param candidateId Candidate Id
     * @param applicationId Application Id
     * @param employeeData Employee data
     * @return Id of the created employee
     */
    @AuraEnabled
    public static Id convertCandidateToEmployee(Id candidateId, Id applicationId, Map<String, Object> employeeData) {
        try {
            return CandidateConversionService.convertCandidateToEmployee(candidateId, applicationId, employeeData);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get conversion details
     * @param candidateId Candidate Id
     * @param applicationId Application Id
     * @return Map with conversion details
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getConversionDetails(Id candidateId, Id applicationId) {
        try {
            return CandidateConversionService.getConversionDetails(candidateId, applicationId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Check if candidate can be converted
     * @param candidateId Candidate Id
     * @param applicationId Application Id
     * @return True if candidate can be converted
     */
    @AuraEnabled(cacheable=true)
    public static Boolean canConvertCandidate(Id candidateId, Id applicationId) {
        try {
            return CandidateConversionService.canConvertCandidate(candidateId, applicationId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get conversion history
     * @param candidateId Candidate Id
     * @return List of conversion history records
     */
    @AuraEnabled(cacheable=true)
    public static List<CandidateConversionHistory__c> getConversionHistory(Id candidateId) {
        try {
            return CandidateConversionService.getConversionHistory(candidateId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
} 