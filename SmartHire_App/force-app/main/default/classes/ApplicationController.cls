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
        
        return ApplicationService.getApplicationsByPosition(positionId);
    }
    
    /**
     * Get applications for a candidate
     */
    @AuraEnabled(cacheable=true)
    public static List<Job_Application__c> getApplicationsByCandidate(Id candidateId) {
        if (!Schema.SObjectType.Application__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Application__c');
        }
        
        return ApplicationService.getApplicationsByCandidate(candidateId);
    }
    
    /**
     * Get application by Id
     */
    @AuraEnabled(cacheable=true)
    public static Job_Application__c getApplicationById(Id applicationId) {
        if (!Schema.SObjectType.Job_Application__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Job_Application__c');
        }

        Job_Application__c application = ApplicationService.getApplicationById(applicationId);
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
        
        return ApplicationService.createApplication(application);
    }
    
    /**
     * Update application status
     */
    @AuraEnabled
    public static void updateApplicationStatus(Id applicationId, String status, String comments) {
        if (!Schema.SObjectType.Job_Application__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Job_Application__c');
        }
        
        ApplicationService.updateApplicationStatus(applicationId, status, comments);
    }
    
    /**
     * Get application history
     */
    @AuraEnabled(cacheable=true)
    public static List<ApplicationStatusHistory__c> getApplicationHistory(Id applicationId) {
        if (!Schema.SObjectType.ApplicationStatusHistory__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access ApplicationStatusHistory__c');
        }
        
        return ApplicationService.getApplicationHistory(applicationId);
    }
}
