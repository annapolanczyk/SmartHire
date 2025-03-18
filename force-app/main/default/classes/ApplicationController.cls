/**
 * Controller for Application-related operations
 */
public with sharing class ApplicationController {
    
    /**
     * Get applications for a position
     */
    @AuraEnabled(cacheable=true)
    public static List<Job_Application__c> getApplicationsByPosition(Id positionId) {
        if (!Schema.SObjectType.Job_Application__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Job_Application__c');
        }
        
        return JobApplicationService.getApplicationsByPosition(positionId);
    }
    
    /**
     * Get applications for a candidate
     */
    @AuraEnabled(cacheable=true)
    public static List<Job_Application__c> getApplicationsByCandidate(Id candidateId) {
        if (!Schema.SObjectType.Job_Application__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Job_Application__c');
        }
        
        // Sprawdzamy dostęp do pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Job_Application__c.fields.getMap();
        List<String> fieldsToCheck = new List<String>{'Id', 'Name', 'Status__c', 'Candidate__c'};
        
        for (String field : fieldsToCheck) {
            if (!fieldMap.get(field).getDescribe().isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Job_Application__c.' + field);
            }
        }
        
        // Korzystamy z warstwy serwisowej zamiast bezpośredniego zapytania SOQL
        return JobApplicationService.getApplicationsByCandidate(candidateId);
    }
    
    /**
     * Get application by Id
     */
    @AuraEnabled(cacheable=true)
    public static Job_Application__c getApplicationById(Id applicationId) {
        if (!Schema.SObjectType.Job_Application__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Job_Application__c');
        }

        Job_Application__c application = JobApplicationService.getApplicationById(applicationId);
        if (application == null) {
            throw new AuraHandledException('Application not found');
        }

        return application;
    }
    
    /**
     * Create a new application
     */
    @AuraEnabled
    public static Id createApplication(Job_Application__c application) {
        if (!Schema.SObjectType.Job_Application__c.isCreateable()) {
            throw new AuraHandledException('Insufficient permissions to create Job_Application__c');
        }
        
        return JobApplicationService.createApplication(application);
    }
    
    /**
     * Update application status
     */
    @AuraEnabled
    public static void updateApplicationStatus(Id applicationId, String status, String comments) {
        if (!Schema.SObjectType.Job_Application__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Job_Application__c');
        }
        
        JobApplicationService.updateApplicationStatus(applicationId, status, comments);
    }
    
    /**
     * Get application history
     */
    @AuraEnabled(cacheable=true)
    public static List<Job_Application__History> getApplicationHistory(Id applicationId) {
        if (!Schema.SObjectType.Job_Application__History.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Job_Application__History');
        }
        
        return JobApplicationService.getApplicationHistory(applicationId);
    }
}