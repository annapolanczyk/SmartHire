/**
 * Service class to handle Candidate related operations
 */
public with sharing class CandidateService {
    
    /**
     * Get all candidates
     * @return List of candidates
     */
    public static List<Candidate__c> getAllCandidates() {
        return [
            SELECT Id, Name, Email__c, Phone__c, Status__c, LinkedIn_URL__c, Skills__c
            FROM Candidate__c
            ORDER BY Name ASC
        ];
    }
    
    /**
     * Search candidates by name, email or skills
     * @param searchTerm Search term
     * @return List of matching candidates
     */
    public static List<Candidate__c> searchCandidates(String searchTerm) {
        if (String.isBlank(searchTerm)) {
            return getAllCandidates();
        }
        
        String likeSearchTerm = '%' + searchTerm + '%';
        
        return [
            SELECT Id, Name, Email__c, Phone__c, Status__c, LinkedIn_URL__c, Skills__c
            FROM Candidate__c
            WHERE Name LIKE :likeSearchTerm 
               OR Email__c LIKE :likeSearchTerm 
               OR Skills__c LIKE :likeSearchTerm
            ORDER BY Name ASC
        ];
    }
    
    /**
     * Get candidate details by Id
     * @param candidateId Candidate Id
     * @return Candidate details with related applications
     */
    public static Candidate__c getCandidateById(Id candidateId) {
        List<Candidate__c> candidates = [
            SELECT Id, Name, Email__c, Phone__c, Status__c, LinkedIn_URL__c, Skills__c,
                   (SELECT Id, Name, Position__c, Position__r.Name, Status__c, Application_Date__c 
                    FROM Job_Applications__r
                    ORDER BY Application_Date__c DESC)
            FROM Candidate__c
            WHERE Id = :candidateId
        ];
        
        if (candidates.isEmpty()) {
            throw new AuraHandledException('Candidate not found');
        }
        
        return candidates[0];
    }
    
    /**
     * Create a new candidate
     * @param candidate Candidate to create
     * @return Created candidate Id
     */
    public static Id createCandidate(Candidate__c candidate) {
        try {
            // Check CRUD permissions
            if (!Schema.sObjectType.Candidate__c.isCreateable()) {
                throw new AuraHandledException('You don\'t have permission to create candidates');
            }
            
            insert candidate;
            return candidate.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating candidate: ' + e.getMessage());
        }
    }
    
    /**
     * Update a candidate
     * @param candidate Candidate to update
     */
    public static void updateCandidate(Candidate__c candidate) {
        try {
            // Check CRUD permissions
            if (!Schema.sObjectType.Candidate__c.isUpdateable()) {
                throw new AuraHandledException('You don\'t have permission to update candidates');
            }
            
            update candidate;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating candidate: ' + e.getMessage());
        }
    }
    
    /**
     * Check if email already exists
     * @param email Email to check
     * @param candidateId Optional candidate Id to exclude from check (for updates)
     * @return True if email exists
     */
    public static Boolean isEmailExist(String email, Id candidateId) {
        if (String.isBlank(email)) {
            return false;
        }
        
        Integer count;
        
        if (candidateId != null) {
            count = [SELECT COUNT() FROM Candidate__c WHERE Email__c = :email AND Id != :candidateId];
        } else {
            count = [SELECT COUNT() FROM Candidate__c WHERE Email__c = :email];
        }
        
        return count > 0;
    }
}