/**
 * Service class for converting candidates to contacts, users, or employees.
 */
public with sharing class CandidateConversionService {
    
    private static final String CLASS_NAME = 'CandidateConversionService';

    // ========================== KONWERSJA DO CONTACT ==========================

    public static Id convertCandidateToContact(Id candidateId, Id accountId) {
        try {
            validateConversionPermissions();
            
            Savepoint sp = Database.setSavepoint();
            
            try {
                Candidate__c candidate = getCandidateForConversion(candidateId);
                Contact newContact = createContactRecord(candidate, accountId);
                updateCandidateStatus(candidate, 'Converted to Contact');
                
                return newContact.Id;
            } catch (Exception e) {
                Database.rollback(sp);
                throw e;
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'convertCandidateToContact', 'Error converting candidate ' + candidateId + ' to contact', e);
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ========================== KONWERSJA DO USER ==========================

    public static Id convertCandidateToUser(Id candidateId, Id profileId, Id roleId) {
        try {
            validateConversionPermissions();

            Candidate__c candidate = getCandidateForConversion(candidateId);

            if (!Schema.SObjectType.User.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create User');
            }

            String[] nameParts = candidate.Name != null ? candidate.Name.split(' ') : new List<String>{'Unknown', 'Candidate'};
            String firstName = nameParts[0];
            String lastName = nameParts.size() > 1 ? nameParts[1] : 'N/A';

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

            return newUser.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ========================== KONWERSJA DO EMPLOYEE ==========================

    public static Id convertCandidateToEmployee(Id candidateId, Id applicationId, Map<String, Object> employeeData) {
        try {
            Candidate__c candidate = getCandidateForConversion(candidateId);
            Job_Application__c application = [SELECT Id, Position__c FROM Job_Application__c WHERE Id = :applicationId];

            Employee__c employee = new Employee__c(
                Name = candidate.Name,
                Email__c = candidate.Email__c,
                Phone__c = candidate.Phone__c,
                Position__c = application.Position__c,
                Hire_Date__c = Date.today()
            );

            insert employee;
            updateCandidateStatus(candidateId, 'Converted to Employee');

            return employee.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ========================== POMOCNICZE METODY ==========================

    private static void updateCandidateStatus(Id candidateId, String status) {
        Candidate__c candidate = new Candidate__c(Id = candidateId, Status__c = status);
        Database.update(candidate, false);
    }

    private static Candidate__c getCandidateForConversion(Id candidateId) {
        return [SELECT Id, Name, Email__c, Phone__c, Status__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
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
}
