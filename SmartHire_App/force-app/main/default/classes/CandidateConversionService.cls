/**
 * Service class for candidate conversion operations
 */
public with sharing class CandidateConversionService {
    
    private static final String CLASS_NAME = 'CandidateConversionService';

    /**
     * Convert candidate to employee
     */
    public static Id convertCandidateToEmployee(Id candidateId, Id applicationId, Map<String, Object> employeeData) {
        try {
            if (!Schema.SObjectType.Candidate__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Candidate__c');
            }
            if (!Schema.SObjectType.Job_Application__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Job_Application__c');
            }
            
            Candidate__c candidate = [SELECT Id, Name, Email__c, Phone__c, Status__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
            Job_Application__c application = [SELECT Id, Position__c FROM Job_Application__c WHERE Id = :applicationId LIMIT 1];
            
            if (!Schema.SObjectType.Employee__c.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Employee__c');
            }
            
            Employee__c employee = new Employee__c(
                Name = candidate.Name,
                Email__c = candidate.Email__c,
                Phone__c = candidate.Phone__c,
                Position__c = application.Position__c,
                Hire_Date__c = Date.today()
            );
            
            if (employeeData != null) {
                if (employeeData.containsKey('Department__c')) employee.Department__c = (String)employeeData.get('Department__c');
                if (employeeData.containsKey('Manager__c')) employee.Manager__c = (Id)employeeData.get('Manager__c');
                if (employeeData.containsKey('Salary__c')) employee.Salary__c = (Decimal)employeeData.get('Salary__c');
            }
            
            insert employee;
            
            candidate.Status__c = 'Converted to Employee';
            update candidate;
            
            application.Status__c = 'Hired';
            update application;
            
            if (Schema.SObjectType.CandidateConversionHistory__c.isCreateable()) {
                CandidateConversionHistory__c history = new CandidateConversionHistory__c(
                    Candidate__c = candidateId,
                    Conversion_Date__c = DateTime.now(),
                    Employee__c = employee.Id  // Powiązanie zamiast Related_Record_Id__c
                );
                insert history;
            }
            
            return employee.Id;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'convertCandidateToEmployee', 'Error converting candidate to employee', e);
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Get conversion history
     */
    public static List<CandidateConversionHistory__c> getConversionHistory(Id candidateId) {
        try {
            if (!Schema.SObjectType.CandidateConversionHistory__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access CandidateConversionHistory__c');
            }
            
            return [SELECT Id, Conversion_Date__c, Employee__c
                    FROM CandidateConversionHistory__c 
                    WHERE Candidate__c = :candidateId 
                    ORDER BY Conversion_Date__c DESC];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getConversionHistory', 'Error getting conversion history', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
}
