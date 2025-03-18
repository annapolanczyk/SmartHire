/**
 * Service class for Candidate-related operations
 */
public with sharing class CandidateService {
    
    private static final String CLASS_NAME = 'CandidateService';
    
    private static final List<String> BASIC_FIELDS = new List<String>{
        'Name', 'Email__c', 'Phone__c', 'Status__c', 'Current_Employer__c', 
        'Current_Position__c', 'LinkedIn_Profile__c'
    };
    
    private static final List<String> DETAIL_FIELDS = new List<String>{
        'Resume__c', 'Cover_Letter__c', 'Education__c', 'Experience__c'
    };
    
    /**
     * Check if email exists for another candidate
     * @param email Email to check
     * @param candidateId Current candidate Id (optional)
     * @return True if email exists for another candidate
     */
    public static Boolean isEmailExist(String email, Id candidateId) {
        try {
            // Sprawdzamy uprawnienia dla Candidate__c
            if (!Schema.SObjectType.Candidate__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Candidate__c');
            }
            
            // Sprawdzamy dostęp do pól
            if (!Schema.SObjectType.Candidate__c.fields.Email__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Candidate__c.Email__c');
            }
            
            String query = 'SELECT Id FROM Candidate__c WHERE Email__c = :email';
            if (candidateId != null) {
                query += ' AND Id != :candidateId';
            }
            
            List<Candidate__c> candidates = Database.query(query);
            return !candidates.isEmpty();
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'isEmailExist', 'Error checking email existence', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get all candidates
     * @return List of candidates
     */
    public static List<Candidate__c> getAllCandidates() {
        try {
            // Sprawdzamy uprawnienia dla Candidate__c
            if (!Schema.SObjectType.Candidate__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Candidate__c');
            }
            
            // Sprawdzamy dostęp do pól
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Candidate__c.fields.getMap();
            for (String field : BASIC_FIELDS) {
                if (!fieldMap.get(field).getDescribe().isAccessible()) {
                    throw new AuraHandledException('Insufficient permissions to access Candidate__c.' + field);
                }
            }
            
            return [SELECT Id, Name, Email__c, Phone__c, Status__c, 
                           Current_Employer__c, Current_Position__c, LinkedIn_Profile__c 
                    FROM Candidate__c 
                    ORDER BY Name ASC];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getAllCandidates', 'Error retrieving candidates', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get candidate by Id
     * @param candidateId Candidate Id
     * @return Candidate details
     */
    public static Candidate__c getCandidateById(Id candidateId) {
        try {
            // Sprawdzamy uprawnienia dla Candidate__c
            if (!Schema.SObjectType.Candidate__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Candidate__c');
            }
            
            // Sprawdzamy dostęp do pól
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Candidate__c.fields.getMap();
            List<String> allFields = new List<String>();
            allFields.addAll(BASIC_FIELDS);
            allFields.addAll(DETAIL_FIELDS);
            
            for (String field : allFields) {
                if (!fieldMap.get(field).getDescribe().isAccessible()) {
                    throw new AuraHandledException('Insufficient permissions to access Candidate__c.' + field);
                }
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
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getCandidateById', 'Error retrieving candidate: ' + candidateId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Create a new candidate
     * @param candidate Candidate to create
     * @return Id of the created candidate
     */
    public static Id createCandidate(Candidate__c candidate) {
        try {
            // Sprawdzamy uprawnienia dla Candidate__c
            if (!Schema.SObjectType.Candidate__c.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Candidate__c');
            }
            
            // Sprawdzamy dostęp do pól
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Candidate__c.fields.getMap();
            List<String> allFields = new List<String>();
            allFields.addAll(BASIC_FIELDS);
            allFields.addAll(DETAIL_FIELDS);
            
            for (String field : allFields) {
                if (!fieldMap.get(field).getDescribe().isCreateable()) {
                    throw new AuraHandledException('Insufficient permissions to create Candidate__c.' + field);
                }
            }
            
            insert candidate;
            return candidate.Id;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'createCandidate', 'Error creating candidate', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Update an existing candidate
     * @param candidate Candidate to update
     */
    public static void updateCandidate(Candidate__c candidate) {
        try {
            // Sprawdzamy uprawnienia dla Candidate__c
            if (!Schema.SObjectType.Candidate__c.isUpdateable()) {
                throw new AuraHandledException('Insufficient permissions to update Candidate__c');
            }
            
            // Sprawdzamy dostęp do pól
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Candidate__c.fields.getMap();
            List<String> allFields = new List<String>();
            allFields.addAll(BASIC_FIELDS);
            allFields.addAll(DETAIL_FIELDS);
            
            for (String field : allFields) {
                if (!fieldMap.get(field).getDescribe().isUpdateable()) {
                    throw new AuraHandledException('Insufficient permissions to update Candidate__c.' + field);
                }
            }
            
            update candidate;
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
    public static List<Candidate__c> searchCandidates(String searchKey) {
        try {
            String searchPattern = '%' + searchKey + '%';
            return [SELECT Id, Name, Email__c, Phone__c, Status__c, LinkedIn_Profile__c
                    FROM Candidate__c
                    WHERE Name LIKE :searchPattern
                    OR Email__c LIKE :searchPattern
                    OR Phone__c LIKE :searchPattern
                    ORDER BY Name ASC
                    LIMIT 100];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'searchCandidates', 'Error searching candidates with key: ' + searchKey, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
}