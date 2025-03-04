/**
 * Controller for Application-related operations
 */
public with sharing class ApplicationController {
    
    /**
     * Get applications for a position
     * @param positionId Position Id
     * @return List of applications
     */
    @AuraEnabled(cacheable=true)
    public static List<Application__c> getApplicationsByPosition(Id positionId) {
        try {
            return ApplicationService.getApplicationsByPosition(positionId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get applications for a candidate
     * @param candidateId Candidate Id
     * @return List of applications
     */
    @AuraEnabled(cacheable=true)
    public static List<Application__c> getApplicationsByCandidate(Id candidateId) {
        try {
            return ApplicationService.getApplicationsByCandidate(candidateId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get application by Id
     * @param applicationId Application Id
     * @return Application details
     */
    @AuraEnabled(cacheable=true)
    public static Application__c getApplicationById(Id applicationId) {
        try {
            return ApplicationService.getApplicationById(applicationId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Create a new application
     * @param application Application to create
     * @return Id of the created application
     */
    @AuraEnabled
    public static Id createApplication(Application__c application) {
        try {
            return ApplicationService.createApplication(application);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Update application status
     * @param applicationId Application Id
     * @param status New status
     * @param comments Optional comments
     */
    @AuraEnabled
    public static void updateApplicationStatus(Id applicationId, String status, String comments) {
        try {
            ApplicationService.updateApplicationStatus(applicationId, status, comments);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get application history
     * @param applicationId Application Id
     * @return List of status history records
     */
    @AuraEnabled(cacheable=true)
    public static List<ApplicationStatusHistory__c> getApplicationHistory(Id applicationId) {
        try {
            return ApplicationService.getApplicationHistory(applicationId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
} 