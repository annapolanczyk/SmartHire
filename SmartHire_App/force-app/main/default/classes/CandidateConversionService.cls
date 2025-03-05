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
            // Sprawdzamy uprawnienia do odczytu Candidate__c
            if (!Schema.SObjectType.Candidate__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Candidate__c');
            }
            
            // Sprawdzamy uprawnienia do odczytu Job_Application__c
            if (!Schema.SObjectType.Job_Application__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Job_Application__c');
            }
            
            // Sprawdzamy uprawnienia do tworzenia Employee__c
            if (!Schema.SObjectType.Employee__c.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Employee__c');
            }
            
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
        // Sprawdzamy uprawnienia do aktualizacji Candidate__c
        if (!Schema.SObjectType.Candidate__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Candidate__c');
        }
        
        // Sprawdzamy uprawnienia do aktualizacji pola Status__c
        if (!Schema.SObjectType.Candidate__c.fields.Status__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Candidate__c.Status__c');
        }
        
        Candidate__c candidate = new Candidate__c(Id = candidateId, Status__c = status);
        Database.update(candidate, false);
    }

    private static Candidate__c getCandidateForConversion(Id candidateId) {
        // Sprawdzamy uprawnienia do odczytu Candidate__c
        if (!Schema.SObjectType.Candidate__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Candidate__c');
        }
        
        // Sprawdzamy uprawnienia do odczytu pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Candidate__c.fields.getMap();
        for (String field : new List<String>{'Id', 'Name', 'Email__c', 'Phone__c', 'Status__c'}) {
            if (!fieldMap.get(field).getDescribe().isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Candidate__c.' + field);
            }
        }
        
        return [SELECT Id, Name, Email__c, Phone__c, Status__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
    }

    private static Contact createContactRecord(Candidate__c candidate, Id accountId) {
        // Sprawdzamy uprawnienia do tworzenia Contact
        if (!Schema.SObjectType.Contact.isCreateable()) {
            throw new AuraHandledException('Insufficient permissions to create Contact');
        }
        
        // Sprawdzamy uprawnienia do tworzenia pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Contact.fields.getMap();
        for (String field : new List<String>{'FirstName', 'LastName', 'Email', 'Phone', 'AccountId', 'Title'}) {
            if (!fieldMap.get(field).getDescribe().isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Contact.' + field);
            }
        }
        
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

	public static Map<String, Object> getConversionDetails(Id candidateId, Id applicationId) {
        try {
            // Sprawdzamy uprawnienia do odczytu Candidate__c
            if (!Schema.SObjectType.Candidate__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Candidate__c');
            }
            
            // Sprawdzamy uprawnienia do odczytu Job_Application__c
            if (!Schema.SObjectType.Job_Application__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Job_Application__c');
            }
            
            // Pobieramy kandydata
            Candidate__c candidate = [SELECT Id, Name, Email__c, Phone__c, Status__c 
                                     FROM Candidate__c 
                                     WHERE Id = :candidateId];
            
            // Pobieramy aplikację
            Job_Application__c application = [SELECT Id, Position__c, Position__r.Name 
                                            FROM Job_Application__c 
                                            WHERE Id = :applicationId];
            
            Map<String, Object> details = new Map<String, Object>{
                'candidateName' => candidate.Name,
                'candidateEmail' => candidate.Email__c,
                'candidatePhone' => candidate.Phone__c,
                'candidateStatus' => candidate.Status__c,
                'positionName' => application.Position__r.Name
            };
            
            return details;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static Boolean canConvertCandidate(Id candidateId, Id applicationId) {
        try {
            // Sprawdzamy uprawnienia do odczytu Candidate__c
            if (!Schema.SObjectType.Candidate__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Candidate__c');
            }
            
            // Sprawdzamy uprawnienia do odczytu Job_Application__c
            if (!Schema.SObjectType.Job_Application__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Job_Application__c');
            }
            
            // Pobieramy kandydata
            Candidate__c candidate = [SELECT Id, Status__c 
                                     FROM Candidate__c 
                                     WHERE Id = :candidateId];
            
            // Pobieramy aplikację
            Job_Application__c application = [SELECT Id, Status__c 
                                            FROM Job_Application__c 
                                            WHERE Id = :applicationId];
            
            // Sprawdzamy, czy kandydat może być przekonwertowany
            return candidate.Status__c != 'Converted to Employee' && 
                   application.Status__c == 'Offer Accepted';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static List<CandidateConversionHistory__c> getConversionHistory(Id candidateId) {
        try {
            // Sprawdzamy uprawnienia do odczytu CandidateConversionHistory__c
            if (!Schema.SObjectType.CandidateConversionHistory__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access CandidateConversionHistory__c');
            }
            
            // Sprawdzamy uprawnienia do odczytu pól
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.CandidateConversionHistory__c.fields.getMap();
            for (String field : new List<String>{'Candidate__c', 'Conversion_Date__c', 'Conversion_Type__c', 'Related_Record_Id__c'}) {
                if (!fieldMap.get(field).getDescribe().isAccessible()) {
                    throw new AuraHandledException('Insufficient permissions to access CandidateConversionHistory__c.' + field);
                }
            }
            
            return [SELECT Id, Conversion_Type__c, Conversion_Date__c, Related_Record_Id__c 
                   FROM CandidateConversionHistory__c 
                   WHERE Candidate__c = :candidateId 
                   ORDER BY Conversion_Date__c DESC];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static List<UserRole> getAvailableRoles() {
        try {
            // Sprawdzamy uprawnienia do odczytu UserRole
            if (!Schema.SObjectType.UserRole.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access UserRole');
            }
            
            // Sprawdzamy uprawnienia do odczytu pola Name
            if (!Schema.SObjectType.UserRole.fields.Name.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access UserRole.Name');
            }
            
            return [SELECT Id, Name FROM UserRole ORDER BY Name];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static List<Profile> getAvailableProfiles() {
        try {
            // Sprawdzamy uprawnienia do odczytu Profile
            if (!Schema.SObjectType.Profile.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Profile');
            }
            
            // Sprawdzamy uprawnienia do odczytu pola Name
            if (!Schema.SObjectType.Profile.fields.Name.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Profile.Name');
            }
            
            return [SELECT Id, Name FROM Profile WHERE UserType = 'Standard' ORDER BY Name];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    private static void validateConversionPermissions() {
        // Sprawdzamy uprawnienia dla Candidate__c
        if (!Schema.SObjectType.Candidate__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Candidate__c');
        }
        
        // Sprawdzamy uprawnienia dla Contact
        if (!Schema.SObjectType.Contact.isCreateable()) {
            throw new AuraHandledException('Insufficient permissions to create Contact');
        }
        
        // Sprawdzamy uprawnienia do aktualizacji statusu kandydata
        if (!Schema.SObjectType.Candidate__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Candidate__c');
        }
        if (!Schema.SObjectType.Candidate__c.fields.Status__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Candidate__c.Status__c');
        }
    }
    
    private static void updateCandidateStatus(Candidate__c candidate, String status) {
        // Sprawdzamy uprawnienia do aktualizacji Candidate__c
        if (!Schema.SObjectType.Candidate__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Candidate__c');
        }
        if (!Schema.SObjectType.Candidate__c.fields.Status__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Candidate__c.Status__c');
        }
        
        candidate.Status__c = status;
        update candidate;
    }
}
