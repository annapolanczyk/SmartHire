/**
 * Service class for converting candidates to contacts
 */
public with sharing class CandidateContactConversionService {
    
    private static final String CLASS_NAME = 'CandidateContactConversionService';
    
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
    
    // Private helper methods
    
    private static void validateConversionPermissions() {
        try {
            // Sprawdzamy uprawnienia dla Candidate__c
            if (!Schema.SObjectType.Candidate__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Candidate__c');
            }
            
            // Sprawdzamy dostęp do pól Candidate__c
            Map<String, Schema.SObjectField> candidateFieldMap = Schema.SObjectType.Candidate__c.fields.getMap();
            for (String field : CANDIDATE_FIELDS) {
                if (!candidateFieldMap.get(field).getDescribe().isAccessible()) {
                    throw new AuraHandledException('Insufficient permissions to access Candidate__c.' + field);
                }
            }
            
            // Sprawdzamy uprawnienia dla Contact
            if (!Schema.SObjectType.Contact.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Contact');
            }
            
            // Sprawdzamy dostęp do pól Contact
            Map<String, Schema.SObjectField> contactFieldMap = Schema.SObjectType.Contact.fields.getMap();
            for (String field : CONTACT_FIELDS) {
                if (!contactFieldMap.get(field).getDescribe().isCreateable()) {
                    throw new AuraHandledException('Insufficient permissions to create Contact.' + field);
                }
            }
            
            // Sprawdzamy uprawnienia do aktualizacji statusu kandydata
            if (!Schema.SObjectType.Candidate__c.isUpdateable()) {
                throw new AuraHandledException('Insufficient permissions to update Candidate__c');
            }
            if (!Schema.SObjectType.Candidate__c.fields.Status__c.isUpdateable()) {
                throw new AuraHandledException('Insufficient permissions to update Candidate__c.Status__c');
            }
            
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'validateConversionPermissions', 'Error validating conversion permissions', e);
            throw e;
        }
    }
    
    private static Candidate__c getCandidateForConversion(Id candidateId) {
        try {
            // Sprawdzamy uprawnienia dla Candidate__c
            if (!Schema.SObjectType.Candidate__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Candidate__c');
            }
            
            // Sprawdzamy dostęp do pól
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Candidate__c.fields.getMap();
            List<String> fieldsToCheck = new List<String>{
                'Id', 'Name', 'Email__c', 'Phone__c', 'Status__c', 
                'Current_Employer__c', 'Current_Position__c'
            };
            
            for (String field : fieldsToCheck) {
                if (!fieldMap.get(field).getDescribe().isAccessible()) {
                    throw new AuraHandledException('Insufficient permissions to access Candidate__c.' + field);
                }
            }
            
            // Wykonujemy zapytanie bezpośrednio po sprawdzeniu uprawnień
            return [SELECT Id, Name, Email__c, Phone__c, Status__c,
                           Current_Employer__c, Current_Position__c 
                    FROM Candidate__c 
                    WHERE Id = :candidateId];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getCandidateForConversion', 
                'Error getting candidate ' + candidateId + ' for conversion', e);
            throw e;
        }
    }
    
    private static Contact createContactRecord(Candidate__c candidate, Id accountId) {
        try {
            // Przygotowanie danych
            List<String> nameParts = candidate.Name.split(' ', 2);
            String firstName = nameParts[0];
            String lastName = nameParts.size() > 1 ? nameParts[1] : '';
            
            Contact newContact = new Contact(
                FirstName = firstName,
                LastName = lastName,
                Email = candidate.Email__c,
                Phone = candidate.Phone__c,
                AccountId = accountId,
                Title = candidate.Current_Position__c
            );
            
            // Sprawdzamy uprawnienia bezpośrednio przed DML
            if (!Schema.SObjectType.Contact.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Contact');
            }
            
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Contact.fields.getMap();
            List<String> contactFields = new List<String>{
                'FirstName', 'LastName', 'Email', 'Phone', 'AccountId', 'Title'
            };
            
            for (String field : contactFields) {
                if (!fieldMap.get(field).getDescribe().isCreateable()) {
                    throw new AuraHandledException('Insufficient permissions to create Contact.' + field);
                }
            }
            
            // Wykonujemy operację DML bezpośrednio po sprawdzeniu uprawnień
            insert newContact;
            return newContact;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'createContactRecord', 
                'Error creating contact record for candidate ' + candidate.Id, e);
            throw e;
        }
    }
    
    private static void updateCandidateStatus(Candidate__c candidate) {
        try {
            // Przygotowanie danych
            candidate.Status__c = 'Converted to Contact';
            
            // Sprawdzamy uprawnienia bezpośrednio przed DML
            if (!Schema.SObjectType.Candidate__c.isUpdateable()) {
                throw new AuraHandledException('Insufficient permissions to update Candidate__c');
            }
            if (!Schema.SObjectType.Candidate__c.fields.Status__c.isUpdateable()) {
                throw new AuraHandledException('Insufficient permissions to update Candidate__c.Status__c');
            }
            
            // Wykonujemy operację DML bezpośrednio po sprawdzeniu uprawnień
            update candidate;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'updateCandidateStatus', 
                'Error updating status for candidate ' + candidate.Id, e);
            throw e;
        }
    }
} 