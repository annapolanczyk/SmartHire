/**
 * Service class for converting candidates to contacts or users.
 */
public with sharing class CandidateConversionService {
    
    private static final String CLASS_NAME = 'CandidateConversionService';
    
    private static final List<String> CANDIDATE_FIELDS = new List<String>{
        'Name', 'Email__c', 'Phone__c', 'Status__c', 'Current_Position__c'
    };
    
    private static final List<String> CONTACT_FIELDS = new List<String>{
        'FirstName', 'LastName', 'Email', 'Phone', 'AccountId', 'Title'
    };

    /**
     * Convert candidate to contact
     * @param candidateId Candidate Id
     * @param accountId Account Id
     * @return Id of the created contact
     */
    public static Id convertCandidateToContact(Id candidateId, Id accountId) {
        try {
            validateConversionPermissions();
            
            Savepoint sp = Database.setSavepoint();
            
            try {
                Candidate__c candidate = getCandidateForConversion(candidateId);
                Contact newContact = createContactRecord(candidate, accountId);
                updateCandidateStatus(candidate);

                return newContact.Id;
            } catch (Exception e) {
                Database.rollback(sp);
                throw e;
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'convertCandidateToContact', 
                'Error converting candidate ' + candidateId + ' to contact', e);
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
    public static Id convertCandidateToUser(Id candidateId, Id profileId, Id roleId) {
        try {
            validateConversionPermissions();

            Candidate__c candidate = getCandidateForConversion(candidateId);

            if (!Schema.SObjectType.User.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create User');
            }

            Map<String, Schema.SObjectField> userFieldMap = Schema.SObjectType.User.fields.getMap();
            for (String field : new List<String>{'FirstName', 'LastName', 'Email', 'ProfileId', 'UserRoleId'}) {
                if (!userFieldMap.get(field).getDescribe().isCreateable()) {
                    throw new AuraHandledException('Insufficient permissions to create User.' + field);
                }
            }

            // Handle null and missing last name cases
            String[] nameParts = candidate.Name != null ? candidate.Name.split(' ') : new List<String>{'Unknown', 'Candidate'};
            String firstName = nameParts[0];
            String lastName = nameParts.size() > 1 ? nameParts[1] : 'N/A'; // Ensure LastName is not empty

            User newUser = new User(
                FirstName = firstName,
                LastName = lastName,
                Email = candidate.Email__c,
                Username = candidate.Email__c != null ? candidate.Email__c + '.' + System.currentTimeMillis() + '@example.com' : null,
                Alias = firstName.substring(0, Math.min(firstName.length(), 5)),
                CommunityNickname = firstName + lastName.substring(0, Math.min(lastName.length(), 3)),
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                TimeZoneSidKey = 'America/Los_Angeles',
                ProfileId = profileId,
                UserRoleId = roleId
            );

            insert newUser;
            updateCandidateStatus(candidateId, 'Converted to User');

            if (Schema.SObjectType.CandidateConversionHistory__c.isCreateable()) {
                CandidateConversionHistory__c history = new CandidateConversionHistory__c(
                    Candidate__c = candidateId,
                    Conversion_Type__c = 'User',
                    Conversion_Date__c = DateTime.now(),
                    Related_Record_Id__c = newUser.Id
                );
                insert history;
            }

            return newUser.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Profile> getAvailableProfiles() {
        try {
            return [SELECT Id, Name FROM Profile ORDER BY Name];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getAvailableProfiles', 'Error getting available profiles', e);
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<UserRole> getAvailableRoles() {
        try {
            return [SELECT Id, Name FROM UserRole ORDER BY Name];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getAvailableRoles', 'Error getting available roles', e);
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void validateConversionPermissions() {
        try {
            if (!Schema.SObjectType.Candidate__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Candidate__c');
            }

            for (String field : CANDIDATE_FIELDS) {
                if (!Schema.SObjectType.Candidate__c.fields.getMap().get(field).getDescribe().isAccessible()) {
                    throw new AuraHandledException('Insufficient permissions to access Candidate__c.' + field);
                }
            }

            if (!Schema.SObjectType.Contact.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Contact');
            }

        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'validateConversionPermissions', 'Error validating conversion permissions', e);
            throw e;
        }
    }

    private static Candidate__c getCandidateForConversion(Id candidateId) {
        return [SELECT Id, Name, Email__c, Phone__c, Status__c, Current_Position__c FROM Candidate__c WHERE Id = :candidateId];
    }

    private static Contact createContactRecord(Candidate__c candidate, Id accountId) {
        String[] nameParts = candidate.Name != null ? candidate.Name.split(' ') : new List<String>{'Unknown', 'Candidate'};
        String firstName = nameParts[0];
        String lastName = nameParts.size() > 1 ? nameParts[1] : 'N/A';

        Contact newContact = new Contact(
            FirstName = firstName,
            LastName = lastName,
            Email = candidate.Email__c,
            Phone = candidate.Phone__c,
            AccountId = accountId,
            Title = candidate.Current_Position__c
        );

        insert newContact;
        return newContact;
    }

    private static void updateCandidateStatus(Candidate__c candidate) {
        candidate.Status__c = 'Converted to Contact';
        Database.update(candidate, false);
    }

    private static void updateCandidateStatus(Id candidateId, String status) {
        Candidate__c candidate = new Candidate__c(Id = candidateId, Status__c = status);
        Database.update(candidate, false);
    }
}
