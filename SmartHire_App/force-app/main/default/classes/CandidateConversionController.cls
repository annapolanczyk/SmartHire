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
    
    /**
     * Get available roles
     * @return List of available roles
     */
    @AuraEnabled(cacheable=true)
    public static List<UserRole> getAvailableRoles() {
        try {
            return CandidateConversionService.getAvailableRoles();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get available profiles
     * @return List of available profiles
     */
    @AuraEnabled(cacheable=true)
    public static List<Profile> getAvailableProfiles() {
        try {
            return CandidateConversionService.getAvailableProfiles();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Convert candidate to user
     * @param candidateId Candidate Id
     * @param profileId Profile Id
     * @param roleId Role Id
     * @return Id of the created user
     */
    @AuraEnabled
    public static Id convertCandidateToUser(Id candidateId, Id profileId, Id roleId) {
        try {
            return CandidateConversionService.convertCandidateToUser(candidateId, profileId, roleId); // 🔄 Zmiana na CandidateConversionService
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Convert candidate to contact
     * @param candidateId Candidate Id
     * @param accountId Account Id
     * @return Id of the created contact
     */
    @AuraEnabled
    public static Id convertCandidateToContact(Id candidateId, Id accountId) {
        try {
            return CandidateConversionService.convertCandidateToContact(candidateId, accountId); // 🔄 Zmiana na CandidateConversionService
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
