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
            
            Savepoint sp = Database.setSavepoint();
            
            try {
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
                updateCandidateStatus(candidate, 'Converted to User');

                return newUser.Id;
            } catch (Exception e) {
                Database.rollback(sp);
                throw e;
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'convertCandidateToUser', 'Error converting candidate ' + candidateId + ' to user', e);
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ========================== KONWERSJA DO EMPLOYEE ==========================

    public static Id convertCandidateToEmployee(Id candidateId, Id applicationId, Map<String, Object> employeeData) {
        try {
            SecurityUtils.checkReadAccess(Candidate__c.SObjectType, 
                new List<String>{'Id', 'Name', 'Email__c', 'Phone__c', 'Status__c'});
            
            SecurityUtils.checkReadAccess(Job_Application__c.SObjectType, 
                new List<String>{'Id', 'Position__c'});
            
            SecurityUtils.checkCreateAccess(Employee__c.SObjectType, 
                new List<String>{'Name', 'Email__c', 'Phone__c', 'Position__c', 'Hire_Date__c'});
            
            Savepoint sp = Database.setSavepoint();
            
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
                updateCandidateStatus(candidate, 'Converted to Employee');

                return employee.Id;
            } catch (Exception e) {
                Database.rollback(sp);
                throw e;
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'convertCandidateToEmployee', 'Error converting candidate ' + candidateId + ' to employee', e);
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ========================== POMOCNICZE METODY ==========================

    public static Map<String, Object> getConversionDetails(Id candidateId, Id applicationId) {
        try {
            SecurityUtils.checkReadAccess(Candidate__c.SObjectType, 
                new List<String>{'Id', 'Name', 'Email__c', 'Phone__c', 'Status__c'});
            
            SecurityUtils.checkReadAccess(Job_Application__c.SObjectType, 
                new List<String>{'Id', 'Position__c', 'Position__r.Name'});
            
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
            Logger.error(CLASS_NAME, 'getConversionDetails', 'Error fetching conversion details for candidate ' + candidateId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static Boolean canConvertCandidate(Id candidateId, Id applicationId) {
        try {
            SecurityUtils.checkReadAccess(Candidate__c.SObjectType, 
                new List<String>{'Id', 'Status__c'});
            
            SecurityUtils.checkReadAccess(Job_Application__c.SObjectType, 
                new List<String>{'Id', 'Status__c'});
            
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
            Logger.error(CLASS_NAME, 'canConvertCandidate', 'Error checking if candidate ' + candidateId + ' can be converted', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static List<CandidateConversionHistory__c> getConversionHistory(Id candidateId) {
        try {
            SecurityUtils.checkReadAccess(CandidateConversionHistory__c.SObjectType, 
                new List<String>{'Id', 'Candidate__c', 'Conversion_Date__c', 'Conversion_Type__c', 'Related_Record_Id__c'});
            
            return [SELECT Id, Conversion_Type__c, Conversion_Date__c, Related_Record_Id__c 
                   FROM CandidateConversionHistory__c 
                   WHERE Candidate__c = :candidateId 
                   ORDER BY Conversion_Date__c DESC];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getConversionHistory', 'Error fetching conversion history for candidate ' + candidateId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static List<UserRole> getAvailableRoles() {
        try {
            SecurityUtils.checkReadAccess(UserRole.SObjectType, 
                new List<String>{'Id', 'Name'});
            
            return [SELECT Id, Name FROM UserRole ORDER BY Name];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getAvailableRoles', 'Error fetching available roles', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static List<Profile> getAvailableProfiles() {
        try {
            SecurityUtils.checkReadAccess(Profile.SObjectType, 
                new List<String>{'Id', 'Name'});
            
            return [SELECT Id, Name FROM Profile WHERE UserType = 'Standard' ORDER BY Name];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getAvailableProfiles', 'Error fetching available profiles', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // ========================== PRYWATNE METODY POMOCNICZE ==========================
    
    private static void validateConversionPermissions() {
        SecurityUtils.checkReadAccess(Candidate__c.SObjectType, 
            new List<String>{'Id', 'Name', 'Email__c', 'Phone__c', 'Status__c'});
        
        SecurityUtils.checkCreateAccess(Contact.SObjectType, 
            new List<String>{'FirstName', 'LastName', 'Email', 'Phone', 'AccountId', 'Title'});
        
        SecurityUtils.checkUpdateAccess(Candidate__c.SObjectType, 
            new List<String>{'Status__c'});
    }
    
    private static Candidate__c getCandidateForConversion(Id candidateId) {
        return [SELECT Id, Name, Email__c, Phone__c, Status__c, Current_Position__c 
                FROM Candidate__c 
                WHERE Id = :candidateId 
                LIMIT 1];
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
    
    private static void updateCandidateStatus(Candidate__c candidate, String status) {
        SecurityUtils.checkUpdateAccess(Candidate__c.SObjectType, 
            new List<String>{'Status__c'});
        
        candidate.Status__c = status;
        update candidate;
    }
}