/**
 * Service class for Candidate Conversion operations
 */
public with sharing class CandidateConversionService {
    
    private static final String CLASS_NAME = 'CandidateConversionService';
    private static final List<String> CANDIDATE_FIELDS = new List<String>{
        'Name', 'Email__c', 'Phone__c', 'Status__c'
    };
    
    private static final List<String> APPLICATION_FIELDS = new List<String>{
        'Position__c', 'Position__r.Name', 'Position__r.Department__c',
        'Position__r.Salary_Range__c', 'Status__c'
    };
    
    private static final List<String> EMPLOYEE_FIELDS = new List<String>{
        'First_Name__c', 'Last_Name__c', 'Email__c', 'Phone__c',
        'Position__c', 'Department__c', 'Hire_Date__c', 'Salary__c',
        'Manager__c', 'Candidate__c'
    };
    
    /**
     * Convert candidate to employee
     * @param candidateId Candidate Id
     * @param applicationId Application Id
     * @param employeeData Employee data
     * @return Id of the created employee
     */
    public static Id convertCandidateToEmployee(Id candidateId, Id applicationId, Map<String, Object> employeeData) {
        try {
            validateConversionPermissions();
            validateConversionEligibility(candidateId, applicationId);
            
            Savepoint sp = Database.setSavepoint();
            
            try {
                Candidate__c candidate = getCandidateForConversion(candidateId);
                Application__c application = getApplicationForConversion(applicationId);
                
                Id employeeId = createEmployeeRecord(candidate, application, employeeData);
                updateCandidateStatus(candidate);
                updateApplicationStatus(application);
                createConversionHistoryRecord(candidateId, employeeId, applicationId);
                
                return employeeId;
            } catch (Exception e) {
                Database.rollback(sp);
                throw e;
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'convertCandidateToEmployee', 
                'Error converting candidate ' + candidateId + ' to employee', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get conversion details
     * @param candidateId Candidate Id
     * @param applicationId Application Id
     * @return Map with conversion details
     */
    public static Map<String, Object> getConversionDetails(Id candidateId, Id applicationId) {
        try {
            validateConversionDetailsPermissions();
            
            Map<String, Object> details = new Map<String, Object>();
            details.put('candidate', getCandidateForConversion(candidateId));
            details.put('application', getApplicationForConversion(applicationId));
            details.put('managers', getAvailableManagers());
            details.put('departments', getDepartmentPicklistValues());
            
            return details;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getConversionDetails', 
                'Error getting conversion details for candidate ' + candidateId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Check if candidate can be converted
     * @param candidateId Candidate Id
     * @param applicationId Application Id
     * @return True if candidate can be converted
     */
    public static Boolean canConvertCandidate(Id candidateId, Id applicationId) {
        try {
            SecurityUtils.checkReadAccess(Application__c.SObjectType, new List<String>{'Status__c', 'Candidate__c'});
            SecurityUtils.checkReadAccess(Candidate__c.SObjectType, new List<String>{'Status__c'});
            SecurityUtils.checkReadAccess(Employee__c.SObjectType, new List<String>{'Candidate__c'});
            
            return validateApplicationStatus(applicationId, candidateId) && 
                   validateCandidateStatus(candidateId) && 
                   !isAlreadyEmployee(candidateId);
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'canConvertCandidate', 
                'Error checking if candidate ' + candidateId + ' can be converted', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get conversion history
     * @param candidateId Candidate Id
     * @return List of conversion history records
     */
    public static List<CandidateConversionHistory__c> getConversionHistory(Id candidateId) {
        try {
            SecurityUtils.checkReadAccess(CandidateConversionHistory__c.SObjectType, 
                new List<String>{'Candidate__c', 'Employee__c', 'Application__c', 'Conversion_Date__c', 'CreatedBy.Name'});
            
            return [SELECT Id, Candidate__c, Employee__c, Application__c, 
                           Conversion_Date__c, CreatedBy.Name 
                    FROM CandidateConversionHistory__c 
                    WHERE Candidate__c = :candidateId 
                    ORDER BY Conversion_Date__c DESC];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getConversionHistory', 
                'Error getting conversion history for candidate ' + candidateId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Private helper methods
    
    private static void validateConversionPermissions() {
        try {
            SecurityUtils.checkReadAccess(Candidate__c.SObjectType, CANDIDATE_FIELDS);
            SecurityUtils.checkReadAccess(Application__c.SObjectType, APPLICATION_FIELDS);
            SecurityUtils.checkCreateAccess(Employee__c.SObjectType, EMPLOYEE_FIELDS);
            SecurityUtils.checkUpdateAccess(Candidate__c.SObjectType, new List<String>{'Status__c'});
            SecurityUtils.checkUpdateAccess(Application__c.SObjectType, new List<String>{'Status__c'});
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'validateConversionPermissions', 'Error validating conversion permissions', e);
            throw e;
        }
    }
    
    private static void validateConversionDetailsPermissions() {
        try {
            SecurityUtils.checkReadAccess(Candidate__c.SObjectType, CANDIDATE_FIELDS);
            SecurityUtils.checkReadAccess(Application__c.SObjectType, APPLICATION_FIELDS);
            SecurityUtils.checkReadAccess(User.SObjectType, new List<String>{'Name'});
            SecurityUtils.checkReadAccess(Profile.SObjectType, new List<String>{'Name'});
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'validateConversionDetailsPermissions', 'Error validating conversion details permissions', e);
            throw e;
        }
    }
    
    private static void validateConversionEligibility(Id candidateId, Id applicationId) {
        try {
            if (!canConvertCandidate(candidateId, applicationId)) {
                throw new AuraHandledException('Candidate is not eligible for conversion');
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'validateConversionEligibility', 
                'Error validating conversion eligibility for candidate ' + candidateId, e);
            throw e;
        }
    }
    
    private static Candidate__c getCandidateForConversion(Id candidateId) {
        try {
            SecurityUtils.checkReadAccess(Candidate__c.SObjectType, CANDIDATE_FIELDS);
            
            return [SELECT Id, Name, Email__c, Phone__c, Status__c 
                    FROM Candidate__c 
                    WHERE Id = :candidateId];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getCandidateForConversion', 
                'Error getting candidate ' + candidateId + ' for conversion', e);
            throw e;
        }
    }
    
    private static Application__c getApplicationForConversion(Id applicationId) {
        try {
            SecurityUtils.checkReadAccess(Application__c.SObjectType, APPLICATION_FIELDS);
            
            return [SELECT Id, Position__c, Position__r.Name, Status__c 
                    FROM Application__c 
                    WHERE Id = :applicationId];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getApplicationForConversion', 
                'Error getting application ' + applicationId + ' for conversion', e);
            throw e;
        }
    }
    
    private static Id createEmployeeRecord(Candidate__c candidate, Application__c application, Map<String, Object> employeeData) {
        try {
            Employee__c employee = new Employee__c(
                First_Name__c = (String)employeeData.get('firstName'),
                Last_Name__c = (String)employeeData.get('lastName'),
                Email__c = candidate.Email__c,
                Phone__c = candidate.Phone__c,
                Position__c = application.Position__c,
                Department__c = (String)employeeData.get('department'),
                Hire_Date__c = Date.valueOf((String)employeeData.get('hireDate')),
                Salary__c = Decimal.valueOf((String)employeeData.get('salary')),
                Manager__c = (Id)employeeData.get('managerId'),
                Candidate__c = candidate.Id
            );
            
            insert employee;
            return employee.Id;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'createEmployeeRecord', 
                'Error creating employee record for candidate ' + candidate.Id, e);
            throw e;
        }
    }
    
    private static void updateCandidateStatus(Candidate__c candidate) {
        try {
            candidate.Status__c = 'Hired';
            update candidate;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'updateCandidateStatus', 
                'Error updating status for candidate ' + candidate.Id, e);
            throw e;
        }
    }
    
    private static void updateApplicationStatus(Application__c application) {
        try {
            application.Status__c = 'Hired';
            update application;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'updateApplicationStatus', 
                'Error updating status for application ' + application.Id, e);
            throw e;
        }
    }
    
    private static Boolean validateApplicationStatus(Id applicationId, Id candidateId) {
        try {
            SecurityUtils.checkReadAccess(Application__c.SObjectType, 
                new List<String>{'Status__c', 'Candidate__c'});
            
            List<Application__c> applications = [SELECT Id 
                                               FROM Application__c 
                                               WHERE Id = :applicationId 
                                               AND Candidate__c = :candidateId 
                                               AND Status__c = 'Offer Accepted'];
            return !applications.isEmpty();
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'validateApplicationStatus', 
                'Error validating application status for application ' + applicationId, e);
            throw e;
        }
    }
    
    private static Boolean validateCandidateStatus(Id candidateId) {
        try {
            SecurityUtils.checkReadAccess(Candidate__c.SObjectType, 
                new List<String>{'Status__c'});
            
            List<Candidate__c> candidates = [SELECT Id 
                                           FROM Candidate__c 
                                           WHERE Id = :candidateId 
                                           AND Status__c != 'Hired'];
            return !candidates.isEmpty();
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'validateCandidateStatus', 
                'Error validating candidate status for candidate ' + candidateId, e);
            throw e;
        }
    }
    
    private static Boolean isAlreadyEmployee(Id candidateId) {
        try {
            SecurityUtils.checkReadAccess(Employee__c.SObjectType, 
                new List<String>{'Candidate__c'});
            
            List<Employee__c> employees = [SELECT Id 
                                         FROM Employee__c 
                                         WHERE Candidate__c = :candidateId];
            return !employees.isEmpty();
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'isAlreadyEmployee', 
                'Error checking if candidate ' + candidateId + ' is already an employee', e);
            throw e;
        }
    }
    
    private static List<User> getAvailableManagers() {
        try {
            SecurityUtils.checkReadAccess(User.SObjectType, 
                new List<String>{'Name', 'IsActive', 'Profile.Name'});
            
            return [SELECT Id, Name 
                    FROM User 
                    WHERE IsActive = true 
                    AND Profile.Name = 'Manager' 
                    ORDER BY Name];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getAvailableManagers', 'Error getting available managers', e);
            throw e;
        }
    }
    
    private static List<String> getDepartmentPicklistValues() {
        try {
            List<String> departments = new List<String>();
            Schema.DescribeFieldResult fieldResult = Employee__c.Department__c.getDescribe();
            
            for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
                departments.add(entry.getValue());
            }
            
            return departments;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getDepartmentPicklistValues', 'Error getting department picklist values', e);
            throw e;
        }
    }
    
    private static void createConversionHistoryRecord(Id candidateId, Id employeeId, Id applicationId) {
        try {
            SecurityUtils.checkCreateAccess(CandidateConversionHistory__c.SObjectType, 
                new List<String>{'Candidate__c', 'Employee__c', 'Application__c', 'Conversion_Date__c'});
            
            CandidateConversionHistory__c history = new CandidateConversionHistory__c(
                Candidate__c = candidateId,
                Employee__c = employeeId,
                Application__c = applicationId,
                Conversion_Date__c = DateTime.now()
            );
            
            insert history;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'createConversionHistoryRecord', 
                'Error creating conversion history record for candidate ' + candidateId, e);
            throw e;
        }
    }
}