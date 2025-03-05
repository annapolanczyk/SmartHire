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
            
            String searchTerm = '%' + searchKey + '%';
            
            return [SELECT Id, Name, Email__c, Phone__c, Status__c, 
                           Current_Employer__c, Current_Position__c 
                    FROM Candidate__c 
                    WHERE Name LIKE :searchTerm 
                       OR Email__c LIKE :searchTerm 
                       OR Current_Employer__c LIKE :searchTerm 
                       OR Current_Position__c LIKE :searchTerm 
                    ORDER BY Name ASC];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'searchCandidates', 'Error searching candidates with key: ' + searchKey, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get candidate skills
     * @param candidateId Candidate Id
     * @return List of candidate skills
     */
    public static List<Skill__c> getCandidateSkills(Id candidateId) {
        try {
            // Sprawdzamy uprawnienia dla Skill__c
            if (!Schema.SObjectType.Skill__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Skill__c');
            }
            
            // Sprawdzamy dostęp do pól
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Skill__c.fields.getMap();
            for (String field : new List<String>{'Name', 'Category__c', 'Proficiency_Level__c'}) {
                if (!fieldMap.get(field).getDescribe().isAccessible()) {
                    throw new AuraHandledException('Insufficient permissions to access Skill__c.' + field);
                }
            }
            
            return [SELECT Id, Name, Category__c, Proficiency_Level__c 
                    FROM Skill__c 
                    WHERE Candidate__c = :candidateId 
                    ORDER BY Category__c, Name ASC];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getCandidateSkills', 'Error retrieving skills for candidate: ' + candidateId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
}