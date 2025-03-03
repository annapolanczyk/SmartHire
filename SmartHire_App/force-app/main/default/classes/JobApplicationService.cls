/**
 * Service class to handle Job Application related operations
 */
public with sharing class JobApplicationService {
    
    /**
     * Get application details by Id
     * @param applicationId Application Id
     * @return Application details
     */
    public static Job_Application__c getApplicationById(Id applicationId) {
        List<Job_Application__c> applications = [
            SELECT Id, Name, Candidate__c, Candidate__r.Name, Candidate__r.Email__c, 
                   Position__c, Position__r.Name, Status__c, Application_Date__c,
                   Evaluation_Notes__c, Assigned_Reviewer__c, Assigned_Reviewer__r.Name
            FROM Job_Application__c
            WHERE Id = :applicationId
        ];
        
        if (applications.isEmpty()) {
            throw new AuraHandledException('Application not found');
        }
        
        return applications[0];
    }
    
    /**
     * Get applications for a position
     * @param positionId Position Id
     * @return List of applications
     */
    public static List<Job_Application__c> getApplicationsByPosition(Id positionId) {
        return [
            SELECT Id, Name, Candidate__c, Candidate__r.Name, Status__c, 
                   Application_Date__c, Assigned_Reviewer__c, Assigned_Reviewer__r.Name
            FROM Job_Application__c
            WHERE Position__c = :positionId
            ORDER BY Application_Date__c DESC
        ];
    }
    
    /**
     * Create a new job application
     * @param application Job application to create
     * @return Created application Id
     */
    public static Id createApplication(Job_Application__c application) {
        try {
            // Check CRUD permissions
            if (!Schema.sObjectType.Job_Application__c.isCreateable()) {
                throw new AuraHandledException('You don\'t have permission to create applications');
            }
            
            // Check if candidate already applied for this position
            Integer existingApplications = [
                SELECT COUNT() 
                FROM Job_Application__c 
                WHERE Candidate__c = :application.Candidate__c 
                AND Position__c = :application.Position__c
            ];
            
            if (existingApplications > 0) {
                throw new AuraHandledException('This candidate has already applied for this position');
            }
            
            insert application;
            return application.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating application: ' + e.getMessage());
        }
    }
    
    /**
     * Update application status
     * @param applicationId Application Id
     * @param status New status
     * @param notes Optional evaluation notes
     */
    public static void updateApplicationStatus(Id applicationId, String status, String notes) {
        try {
            // Check CRUD permissions
            if (!Schema.sObjectType.Job_Application__c.isUpdateable()) {
                throw new AuraHandledException('You don\'t have permission to update applications');
            }
            
            Job_Application__c app = new Job_Application__c(
                Id = applicationId,
                Status__c = status
            );
            
            if (!String.isBlank(notes)) {
                app.Evaluation_Notes__c = notes;
            }
            
            update app;
            
            // If hired, update candidate status to Active
            if (status == 'Hired') {
                Job_Application__c application = getApplicationById(applicationId);
                Candidate__c candidate = new Candidate__c(
                    Id = application.Candidate__c,
                    Status__c = 'Active'
                );
                update candidate;
                
                // Close the position if needed
                // This could be moved to a trigger or another service method
                Position__c position = new Position__c(
                    Id = application.Position__c,
                    Status__c = 'Closed',
                    Close_Date__c = Date.today()
                );
                update position;
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error updating application: ' + e.getMessage());
        }
    }
    
    /**
     * Assign reviewer to application
     * @param applicationId Application Id
     * @param reviewerId Reviewer Id (User)
     */
    public static void assignReviewer(Id applicationId, Id reviewerId) {
        try {
            // Check CRUD permissions
            if (!Schema.sObjectType.Job_Application__c.isUpdateable()) {
                throw new AuraHandledException('You don\'t have permission to update applications');
            }
            
            Job_Application__c app = new Job_Application__c(
                Id = applicationId,
                Assigned_Reviewer__c = reviewerId
            );
            
            update app;
        } catch (Exception e) {
            throw new AuraHandledException('Error assigning reviewer: ' + e.getMessage());
        }
    }
}