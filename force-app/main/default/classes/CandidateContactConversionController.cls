/**
 * Controller for Candidate to Contact/User conversion operations
 */
public with sharing class CandidateContactConversionController {
    
    private static final String CLASS_NAME = 'CandidateContactConversionController';

    /**
     * Get available roles
     * @return List of available roles
     */
    @AuraEnabled(cacheable=true)
    public static List<UserRole> getAvailableRoles() {
        try {
            return CandidateConversionService.getAvailableRoles();
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getAvailableRoles', 'Error fetching available roles', e);
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
            Logger.error(CLASS_NAME, 'getAvailableProfiles', 'Error fetching available profiles', e);
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
            validateCandidatePermissions();
            return CandidateConversionService.convertCandidateToUser(candidateId, profileId, roleId);
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'convertCandidateToUser', 'Error converting candidate to user', e);
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
            validateCandidatePermissions();
            return CandidateConversionService.convertCandidateToContact(candidateId, accountId);
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'convertCandidateToContact', 'Error converting candidate to contact', e);
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Validate permissions for Candidate__c object
     */
    private static void validateCandidatePermissions() {
        if (!Schema.SObjectType.Candidate__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Candidate__c');
        }
    }
}