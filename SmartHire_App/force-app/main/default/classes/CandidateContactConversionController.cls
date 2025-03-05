/**
 * Controller for Candidate to Contact/User conversion operations
 */
public with sharing class CandidateContactConversionController {
    
    /**
     * Get available roles
     * @return List of available roles
     */
    @AuraEnabled(cacheable=true)
    public static List<UserRole> getAvailableRoles() {
        try {
            return CandidateContactConversionService.getAvailableRoles();
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
            return CandidateContactConversionService.getAvailableProfiles();
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
            return CandidateContactConversionService.convertCandidateToUser(candidateId, profileId, roleId);
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
            return CandidateContactConversionService.convertCandidateToContact(candidateId, accountId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
} 