/**
 * Service class for Candidate Conversion operations
 */
public with sharing class CandidateConversionService {
    
    /**
     * Convert candidate to employee
     * @param candidateId Candidate Id
     * @param applicationId Application Id
     * @param employeeData Employee data
     * @return Id of the created employee
     */
    public static Id convertCandidateToEmployee(Id candidateId, Id applicationId, Map<String, Object> employeeData) {
        // Check permissions
        if (!Schema.SObjectType.Candidate__c.isAccessible() || 
            !Schema.SObjectType.Application__c.isAccessible() ||
            !Schema.SObjectType.Employee__c.isCreateable() ||
            !Schema.SObjectType.Candidate__c.isUpdateable() ||
            !Schema.SObjectType.Application__c.isUpdateable()) {
            throw new SecurityException('Insufficient permissions for candidate conversion');
        }
        
        // Validate conversion eligibility
        if (!canConvertCandidate(candidateId, applicationId)) {
            throw new AuraHandledException('Candidate is not eligible for conversion');
        }
        
        // Start transaction
        Savepoint sp = Database.setSavepoint();
        
        try {
            // Get candidate and application details
            Candidate__c candidate = [SELECT Id, Name, Email__c, Phone__c, Status__c 
                                     FROM Candidate__c 
                                     WHERE Id = :candidateId];
            
            Application__c application = [SELECT Id, Position__c, Position__r.Name, Status__c 
                                         FROM Application__c 
                                         WHERE Id = :applicationId];
            
            // Create employee record
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
                Candidate__c = candidateId
            );
            
            insert employee;
            
            // Update candidate status
            candidate.Status__c = 'Hired';
            update candidate;
            
            // Update application status
            application.Status__c = 'Hired';
            update application;
            
            // Create conversion history record
            createConversionHistoryRecord(candidateId, employee.Id, applicationId);
            
            return employee.Id;
        } catch (Exception e) {
            // Rollback transaction on error
            Database.rollback(sp);
            throw new AuraHandledException('Error during conversion: ' + e.getMessage());
        }
    }
    
    /**
     * Get conversion details
     * @param candidateId Candidate Id
     * @param applicationId Application Id
     * @return Map with conversion details
     */
    public static Map<String, Object> getConversionDetails(Id candidateId, Id applicationId) {
        if (!Schema.SObjectType.Candidate__c.isAccessible() || 
            !Schema.SObjectType.Application__c.isAccessible() ||
            !Schema.SObjectType.Position__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access conversion details');
        }
        
        Map<String, Object> details = new Map<String, Object>();
        
        // Get candidate details
        Candidate__c candidate = [SELECT Id, Name, Email__c, Phone__c 
                                 FROM Candidate__c 
                                 WHERE Id = :candidateId];
        
        // Get application and position details
        Application__c application = [SELECT Id, Position__c, Position__r.Name, Position__r.Department__c,
                                             Position__r.Salary_Range__c 
                                     FROM Application__c 
                                     WHERE Id = :applicationId];
        
        // Get available managers
        List<User> managers = [SELECT Id, Name 
                              FROM User 
                              WHERE IsActive = true 
                              AND Profile.Name = 'Manager' 
                              ORDER BY Name];
        
        // Populate details map
        details.put('candidate', candidate);
        details.put('application', application);
        details.put('managers', managers);
        details.put('departments', getDepartmentPicklistValues());
        
        return details;
    }
    
    /**
     * Check if candidate can be converted
     * @param candidateId Candidate Id
     * @param applicationId Application Id
     * @return True if candidate can be converted
     */
    public static Boolean canConvertCandidate(Id candidateId, Id applicationId) {
        if (!Schema.SObjectType.Candidate__c.isAccessible() || 
            !Schema.SObjectType.Application__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to check conversion eligibility');
        }
        
        // Check if application status is 'Offer Accepted'
        List<Application__c> applications = [SELECT Id, Status__c 
                                            FROM Application__c 
                                            WHERE Id = :applicationId 
                                            AND Candidate__c = :candidateId 
                                            AND Status__c = 'Offer Accepted'];
        
        // Check if candidate is not already hired
        List<Candidate__c> candidates = [SELECT Id 
                                        FROM Candidate__c 
                                        WHERE Id = :candidateId 
                                        AND Status__c != 'Hired'];
        
        // Check if candidate is not already converted to employee
        List<Employee__c> employees = [SELECT Id 
                                      FROM Employee__c 
                                      WHERE Candidate__c = :candidateId];
        
        return !applications.isEmpty() && !candidates.isEmpty() && employees.isEmpty();
    }
    
    /**
     * Create conversion history record
     * @param candidateId Candidate Id
     * @param employeeId Employee Id
     * @param applicationId Application Id
     */
    private static void createConversionHistoryRecord(Id candidateId, Id employeeId, Id applicationId) {
        if (!Schema.SObjectType.CandidateConversionHistory__c.isCreateable()) {
            throw new SecurityException('Insufficient permissions to create conversion history');
        }
        
        CandidateConversionHistory__c history = new CandidateConversionHistory__c(
            Candidate__c = candidateId,
            Employee__c = employeeId,
            Application__c = applicationId,
            Conversion_Date__c = DateTime.now()
        );
        
        insert history;
    }
    
    /**
     * Get conversion history
     * @param candidateId Candidate Id
     * @return List of conversion history records
     */
    public static List<CandidateConversionHistory__c> getConversionHistory(Id candidateId) {
        if (!Schema.SObjectType.CandidateConversionHistory__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access conversion history');
        }
        
        return [SELECT Id, Candidate__c, Employee__c, Application__c, 
                       Conversion_Date__c, CreatedBy.Name 
                FROM CandidateConversionHistory__c 
                WHERE Candidate__c = :candidateId 
                ORDER BY Conversion_Date__c DESC];
    }
    
    /**
     * Get department picklist values
     * @return List of department values
     */
    private static List<String> getDepartmentPicklistValues() {
        List<String> departments = new List<String>();
        
        Schema.DescribeFieldResult fieldResult = Employee__c.Department__c.getDescribe();
        List<Schema.PicklistEntry> entries = fieldResult.getPicklistValues();
        
        for (Schema.PicklistEntry entry : entries) {
            departments.add(entry.getValue());
        }
        
        return departments;
    }
}