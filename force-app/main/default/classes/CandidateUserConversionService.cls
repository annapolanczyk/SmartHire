/**
 * Service class for converting candidates to Salesforce users
 */
public with sharing class CandidateUserConversionService {
    
    private static final String CLASS_NAME = 'CandidateUserConversionService';
    
    private static final List<String> CANDIDATE_FIELDS = new List<String>{
        'Name', 'Email__c', 'Phone__c', 'Status__c'
    };
    
    private static final List<String> USER_FIELDS = new List<String>{
        'FirstName', 'LastName', 'Email', 'Phone', 'Username', 'Alias',
        'CommunityNickname', 'EmailEncodingKey', 'LanguageLocaleKey',
        'LocaleSidKey', 'TimeZoneSidKey', 'ProfileId', 'UserRoleId', 'IsActive'
    };
    
    /**
     * Convert candidate to user
     * @param candidateId Candidate Id
     * @param profileId Profile Id
     * @param roleId Role Id
     * @return Id of the created user
     */
    public static Id convertCandidateToUser(Id candidateId, Id profileId, Id roleId) {
        try {
            validateConversionPermissions();
            
            Savepoint sp = Database.setSavepoint();
            
            try {
                Candidate__c candidate = getCandidateForConversion(candidateId);
                User newUser = createUserRecord(candidate, profileId, roleId);
                updateCandidateStatus(candidate);
                
                return newUser.Id;
            } catch (Exception e) {
                Database.rollback(sp);
                throw e;
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'convertCandidateToUser', 
                'Error converting candidate ' + candidateId + ' to user', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get available user roles
     * @return List of available user roles
     */
    public static List<UserRole> getAvailableRoles() {
        try {
            SecurityUtils.checkReadAccess(UserRole.SObjectType, new List<String>{'Name'});
            
            return [SELECT Id, Name 
                    FROM UserRole 
                    ORDER BY Name];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getAvailableRoles', 'Error getting available user roles', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get available profiles
     * @return List of available profiles
     */
    public static List<Profile> getAvailableProfiles() {
        try {
            SecurityUtils.checkReadAccess(Profile.SObjectType, new List<String>{'Name'});
            
            return [SELECT Id, Name 
                    FROM Profile 
                    WHERE UserType = 'Standard' 
                    ORDER BY Name];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getAvailableProfiles', 'Error getting available profiles', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Private helper methods
    
    private static void validateConversionPermissions() {
        try {
            SecurityUtils.checkReadAccess(Candidate__c.SObjectType, CANDIDATE_FIELDS);
            SecurityUtils.checkCreateAccess(User.SObjectType, USER_FIELDS);
            SecurityUtils.checkUpdateAccess(Candidate__c.SObjectType, new List<String>{'Status__c'});
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'validateConversionPermissions', 'Error validating conversion permissions', e);
            throw e;
        }
    }
    
    private static Candidate__c getCandidateForConversion(Id candidateId) {
        try {
            return [SELECT Id, Name, Email__c, Phone__c, Status__c 
                    FROM Candidate__c 
                    WHERE Id = :candidateId];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getCandidateForConversion', 
                'Error getting candidate ' + candidateId + ' for conversion', e);
            throw e;
        }
    }
    
    private static User createUserRecord(Candidate__c candidate, Id profileId, Id roleId) {
        try {
            List<String> nameParts = candidate.Name.split(' ', 2);
            String firstName = nameParts[0];
            String lastName = nameParts.size() > 1 ? nameParts[1] : '';
            
            User newUser = new User(
                FirstName = firstName,
                LastName = lastName,
                Email = candidate.Email__c,
                Phone = candidate.Phone__c,
                Username = candidate.Email__c,
                Alias = firstName.left(1) + lastName.left(7),
                CommunityNickname = firstName.left(1) + lastName.left(7) + String.valueOf(Crypto.getRandomInteger()),
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                TimeZoneSidKey = 'America/Los_Angeles',
                ProfileId = profileId,
                UserRoleId = roleId,
                IsActive = true
            );
            
            insert newUser;
            return newUser;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'createUserRecord', 
                'Error creating user record for candidate ' + candidate.Id, e);
            throw e;
        }
    }
    
    private static void updateCandidateStatus(Candidate__c candidate) {
        try {
            candidate.Status__c = 'Converted to User';
            update candidate;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'updateCandidateStatus', 
                'Error updating status for candidate ' + candidate.Id, e);
            throw e;
        }
    }
}