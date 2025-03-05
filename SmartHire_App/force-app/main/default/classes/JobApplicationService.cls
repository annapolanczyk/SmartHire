/**
 * Service class to handle Job Application related operations
 */
public with sharing class JobApplicationService {
    
    private static final String CLASS_NAME = 'JobApplicationService';
    
    private static final List<String> BASIC_FIELDS = new List<String>{
        'Name', 'Candidate__c', 'Position__c', 'Status__c', 'Application_Date__c', 'Assigned_Reviewer__c'
    };
    
    private static final List<String> DETAIL_FIELDS = new List<String>{
        'Evaluation_Notes__c'
    };
    
    /**
     * Get application details by Id
     * @param applicationId Application Id
     * @return Application details
     */
    public static Job_Application__c getApplicationById(Id applicationId) {
        try {
            List<String> allFields = new List<String>{'Id'};
            allFields.addAll(BASIC_FIELDS);
            allFields.addAll(DETAIL_FIELDS);
            
            SecurityUtils.checkReadAccess(Schema.SObjectType.Job_Application__c, allFields);
            SecurityUtils.checkReadAccess(Schema.SObjectType.Contact, new List<String>{'Name', 'Email__c'});
            SecurityUtils.checkReadAccess(Schema.SObjectType.Position__c, new List<String>{'Name'});
            SecurityUtils.checkReadAccess(Schema.SObjectType.User, new List<String>{'Name'});
            
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
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getApplicationById', 'Error retrieving application: ' + applicationId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get applications for a position
     * @param positionId Position Id
     * @return List of applications
     */
    public static List<Job_Application__c> getApplicationsByPosition(Id positionId) {
        try {
            List<String> fieldsToCheck = new List<String>{'Id'};
            fieldsToCheck.addAll(BASIC_FIELDS);
            
            SecurityUtils.checkReadAccess(Schema.SObjectType.Job_Application__c, fieldsToCheck);
            SecurityUtils.checkReadAccess(Schema.SObjectType.Contact, new List<String>{'Name'});
            SecurityUtils.checkReadAccess(Schema.SObjectType.User, new List<String>{'Name'});
            
            return [
                SELECT Id, Name, Candidate__c, Candidate__r.Name, Status__c, 
                       Application_Date__c, Assigned_Reviewer__c, Assigned_Reviewer__r.Name
                FROM Job_Application__c
                WHERE Position__c = :positionId
                ORDER BY Application_Date__c DESC
            ];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getApplicationsByPosition', 'Error retrieving applications for position: ' + positionId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Create a new job application
     * @param application Job application to create
     * @return Created application Id
     */
    public static Id createApplication(Job_Application__c application) {
        try {
            // Check CRUD permissions
            List<String> fieldsToCheck = new List<String>{'Id'};
            fieldsToCheck.addAll(BASIC_FIELDS);
            SecurityUtils.checkCreateAccess(Schema.SObjectType.Job_Application__c, fieldsToCheck);
            
            // Check if candidate already applied for this position
            SecurityUtils.checkReadAccess(Schema.SObjectType.Job_Application__c, 
                new List<String>{'Id', 'Candidate__c', 'Position__c'});
                
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
            Logger.error(CLASS_NAME, 'createApplication', 'Error creating application', e);
            throw new AuraHandledException(e.getMessage());
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
            // Check CRUD permissions for Job_Application__c
            List<String> appFieldsToCheck = new List<String>{'Id', 'Status__c', 'Evaluation_Notes__c'};
            SecurityUtils.checkUpdateAccess(Schema.SObjectType.Job_Application__c, appFieldsToCheck);
            
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
                
                // Check CRUD permissions for Candidate__c
                SecurityUtils.checkUpdateAccess(Schema.SObjectType.Candidate__c, 
                    new List<String>{'Id', 'Status__c'});
                
                Candidate__c candidate = new Candidate__c(
                    Id = application.Candidate__c,
                    Status__c = 'Active'
                );
                update candidate;
                
                // Check CRUD permissions for Position__c
                SecurityUtils.checkUpdateAccess(Schema.SObjectType.Position__c, 
                    new List<String>{'Id', 'Status__c', 'Close_Date__c'});
                
                // Close the position if needed
                Position__c position = new Position__c(
                    Id = application.Position__c,
                    Status__c = 'Closed',
                    Close_Date__c = Date.today()
                );
                update position;
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'updateApplicationStatus', 'Error updating application status: ' + applicationId, e);
            throw new AuraHandledException(e.getMessage());
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
            SecurityUtils.checkUpdateAccess(Schema.SObjectType.Job_Application__c, 
                new List<String>{'Id', 'Assigned_Reviewer__c'});
            
            Job_Application__c app = new Job_Application__c(
                Id = applicationId,
                Assigned_Reviewer__c = reviewerId
            );
            
            update app;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'assignReviewer', 'Error assigning reviewer to application: ' + applicationId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
}