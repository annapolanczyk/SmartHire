/**
 * Controller for Candidate-related operations
 */
public with sharing class CandidateController {
    
    /**
     * Get all candidates
     * @return List of candidates
     */
    @AuraEnabled(cacheable=true)
    public static List<Candidate__c> getAllCandidates() {
        try {
            return CandidateService.getAllCandidates();
        } catch (Exception e) {
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
            return CandidateService.getCandidateById(candidateId);
        } catch (Exception e) {
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
            return CandidateService.createCandidate(candidate);
        } catch (Exception e) {
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
            CandidateService.updateCandidate(candidate);
        } catch (Exception e) {
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
            return CandidateService.searchCandidates(searchKey);
        } catch (Exception e) {
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
            return CandidateService.getCandidateSkills(candidateId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
} 