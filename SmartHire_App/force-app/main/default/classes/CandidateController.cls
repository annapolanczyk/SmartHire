/**
 * Controller for Candidate-related operations
 */
public with sharing class CandidateController {
    
    private static final String CLASS_NAME = 'CandidateController';

    /**
     * Get all candidates
     * @return List of candidates
     */
    @AuraEnabled(cacheable=true)
    public static List<Candidate__c> getAllCandidates() {
        try {
            validateReadPermissions();
            return CandidateService.getAllCandidates();
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getAllCandidates', 'Error fetching candidates', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get candidate by Id
     * @param candidateId Candidate Id
     * @return Candidate details
     */
    @AuraEnabled(cacheable=true)
    public static Candidate__c getCandidateById(Id candidateId) {
        try {
            validateReadPermissions();
            return CandidateService.getCandidateById(candidateId);
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getCandidateById', 'Error fetching candidate: ' + candidateId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Create a new candidate
     * @param candidate Candidate to create
     * @return Id of the created candidate
     */
    @AuraEnabled
    public static Id createCandidate(Candidate__c candidate) {
        try {
            validateCreatePermissions();
            return CandidateService.createCandidate(candidate);
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'createCandidate', 'Error creating candidate', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Update an existing candidate
     * @param candidate Candidate to update
     */
    @AuraEnabled
    public static void updateCandidate(Candidate__c candidate) {
        try {
            validateUpdatePermissions();
            CandidateService.updateCandidate(candidate);
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'updateCandidate', 'Error updating candidate: ' + candidate.Id, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Search candidates by keyword
     * @param searchKey Search keyword
     * @return List of matching candidates
     */
    @AuraEnabled(cacheable=true)
    public static List<Candidate__c> searchCandidates(String searchKey) {
        try {
            validateReadPermissions();
            return CandidateService.searchCandidates(searchKey);
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'searchCandidates', 'Error searching candidates', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get candidate skills
     * @param candidateId Candidate Id
     * @return List of candidate skills
     */
    @AuraEnabled(cacheable=true)
    public static List<Skill__c> getCandidateSkills(Id candidateId) {
        try {
            validateReadPermissions();
            return CandidateService.getCandidateSkills(candidateId);
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getCandidateSkills', 'Error fetching skills for candidate: ' + candidateId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Check if email exists for another candidate
     * @param email Email to check
     * @param candidateId Current candidate Id (optional)
     * @return True if email exists for another candidate
     */
    @AuraEnabled
    public static Boolean isEmailExist(String email, Id candidateId) {
        try {
            validateReadPermissions();
            return CandidateService.isEmailExist(email, candidateId);
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'isEmailExist', 'Error checking email existence: ' + email, e);
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ✅ **Private helper methods**

    /**
     * Validate read permissions for Candidate__c object
     */
    private static void validateReadPermissions() {
        if (!Schema.SObjectType.Candidate__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Candidate__c');
        }
    }

    /**
     * Validate create permissions for Candidate__c object
     */
    private static void validateCreatePermissions() {
        if (!Schema.SObjectType.Candidate__c.isCreateable()) {
            throw new AuraHandledException('Insufficient permissions to create Candidate__c');
        }
    }

    /**
     * Validate update permissions for Candidate__c object
     */
    private static void validateUpdatePermissions() {
        if (!Schema.SObjectType.Candidate__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Candidate__c');
        }
    }
}
