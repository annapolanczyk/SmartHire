/**
 * Service class for Candidate-related operations
 */
public with sharing class CandidateService {
    
    /**
     * Get all candidates
     * @return List of candidates
     */
    public static List<Candidate__c> getAllCandidates() {
        if (!Schema.SObjectType.Candidate__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Candidate__c');
        }
        
        return [SELECT Id, Name, Email__c, Phone__c, Status__c, 
                       Current_Employer__c, Current_Position__c, LinkedIn_Profile__c 
                FROM Candidate__c 
                ORDER BY Name ASC];
    }
    
    /**
     * Get candidate by Id
     * @param candidateId Candidate Id
     * @return Candidate details
     */
    public static Candidate__c getCandidateById(Id candidateId) {
        if (!Schema.SObjectType.Candidate__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Candidate__c');
        }
        
        List<Candidate__c> candidates = [SELECT Id, Name, Email__c, Phone__c, Status__c, 
                                                Current_Employer__c, Current_Position__c, LinkedIn_Profile__c,
                                                Resume__c, Cover_Letter__c, Education__c, Experience__c 
                                         FROM Candidate__c 
                                         WHERE Id = :candidateId];
        
        if (candidates.isEmpty()) {
            throw new AuraHandledException('Candidate not found');
        }
        
        return candidates[0];
    }
    
    /**
     * Create a new candidate
     * @param candidate Candidate to create
     * @return Id of the created candidate
     */
    public static Id createCandidate(Candidate__c candidate) {
        if (!Schema.SObjectType.Candidate__c.isCreateable()) {
            throw new SecurityException('Insufficient permissions to create Candidate__c');
        }
        
        insert candidate;
        return candidate.Id;
    }
    
    /**
     * Update an existing candidate
     * @param candidate Candidate to update
     */
    public static void updateCandidate(Candidate__c candidate) {
        if (!Schema.SObjectType.Candidate__c.isUpdateable()) {
            throw new SecurityException('Insufficient permissions to update Candidate__c');
        }
        
        update candidate;
    }
    
    /**
     * Search candidates by keyword
     * @param searchKey Search keyword
     * @return List of matching candidates
     */
    public static List<Candidate__c> searchCandidates(String searchKey) {
        if (!Schema.SObjectType.Candidate__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Candidate__c');
        }
        
        String searchTerm = '%' + searchKey + '%';
        
        return [SELECT Id, Name, Email__c, Phone__c, Status__c, 
                       Current_Employer__c, Current_Position__c 
                FROM Candidate__c 
                WHERE Name LIKE :searchTerm 
                   OR Email__c LIKE :searchTerm 
                   OR Current_Employer__c LIKE :searchTerm 
                   OR Current_Position__c LIKE :searchTerm 
                ORDER BY Name ASC];
    }
    
    /**
     * Get candidate skills
     * @param candidateId Candidate Id
     * @return List of candidate skills
     */
    public static List<Skill__c> getCandidateSkills(Id candidateId) {
        if (!Schema.SObjectType.Skill__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Skill__c');
        }
        
        return [SELECT Id, Name, Category__c, Proficiency_Level__c 
                FROM Skill__c 
                WHERE Candidate__c = :candidateId 
                ORDER BY Category__c, Name ASC];
    }
}