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
            
            // Sprawdzamy uprawnienia dla Job_Application__c
            SecurityUtils.checkReadAccess(Job_Application__c.SObjectType, new List<String>{'Id', 'Name', 'Status__c', 'Candidate__c', 'Position__c'});
            
            // Sprawdzamy uprawnienia dla Candidate__c
            SecurityUtils.checkReadAccess(Candidate__c.SObjectType, new List<String>{'Id', 'Name', 'Email__c'});
            
            // Sprawdzamy uprawnienia dla Position__c
            SecurityUtils.checkReadAccess(Position__c.SObjectType, new List<String>{'Id', 'Name', 'Department__c'});
            
            // Sprawdzamy uprawnienia dla User
            SecurityUtils.checkReadAccess(User.SObjectType, new List<String>{'Id', 'Name'});
            
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
            
            // Sprawdzamy uprawnienia dla Job_Application__c
            SecurityUtils.checkReadAccess(Job_Application__c.SObjectType, new List<String>{'Id', 'Name', 'Status__c', 'Candidate__c', 'Position__c'});
            
            // Sprawdzamy uprawnienia dla Candidate__c
            SecurityUtils.checkReadAccess(Candidate__c.SObjectType, new List<String>{'Id', 'Name'});
            
            // Sprawdzamy uprawnienia dla User
            SecurityUtils.checkReadAccess(User.SObjectType, new List<String>{'Id', 'Name'});
            
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
     * Get applications for a candidate
     * @param candidateId Candidate Id
     * @return List of applications
     */
    public static List<Job_Application__c> getApplicationsByCandidate(Id candidateId) {
        try {
            SecurityUtils.checkReadAccess(Job_Application__c.SObjectType, new List<String>{'Id', 'Name', 'Status__c', 'Position__c'});
            
            return [
                SELECT Id, Name, Status__c, Position__c, Position__r.Name, Application_Date__c
                FROM Job_Application__c 
                WHERE Candidate__c = :candidateId
                ORDER BY Application_Date__c DESC
            ];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getApplicationsByCandidate', 'Error retrieving applications for candidate: ' + candidateId, e);
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
            // Sprawdzamy uprawnienia do tworzenia Job_Application__c
            SecurityUtils.checkCreateAccess(Job_Application__c.SObjectType, new List<String>{'Candidate__c', 'Position__c', 'Status__c'});
            
            // Sprawdzamy, czy kandydat i pozycja istnieją
            SecurityUtils.checkReadAccess(Candidate__c.SObjectType, new List<String>{'Id'});
            SecurityUtils.checkReadAccess(Position__c.SObjectType, new List<String>{'Id'});
            
            Integer existingApplications = [
                SELECT COUNT() 
                FROM Job_Application__c 
                WHERE Candidate__c = :application.Candidate__c 
                AND Position__c = :application.Position__c
            ];
            
            if (existingApplications > 0) {
                throw new AuraHandledException('This candidate has already applied for this position');
            }
            
            // Ustawienie domyślnych wartości
            setDefaultValues(application);
            
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
            // Sprawdzamy uprawnienia do aktualizacji Job_Application__c
            SecurityUtils.checkUpdateAccess(Job_Application__c.SObjectType, new List<String>{'Status__c'});
            
            // Pobierz aktualny status aplikacji
            Job_Application__c currentApp = getApplicationById(applicationId);
            
            // Jeśli status nie zmienił się, nie rób nic
            if (currentApp.Status__c == status) {
                return;
            }
            
            // Aktualizuj status aplikacji
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
                // Sprawdzamy uprawnienia do aktualizacji Candidate__c
                SecurityUtils.checkUpdateAccess(Candidate__c.SObjectType, new List<String>{'Id', 'Status__c'});
                
                Candidate__c candidate = new Candidate__c(
                    Id = currentApp.Candidate__c,
                    Status__c = 'Active'
                );
                update candidate;
                
                // Sprawdzamy uprawnienia do aktualizacji Position__c
                SecurityUtils.checkUpdateAccess(Position__c.SObjectType, new List<String>{'Id', 'Status__c', 'Close_Date__c'});
                
                // Close the position if needed
                Position__c position = new Position__c(
                    Id = currentApp.Position__c,
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
            // Sprawdzamy uprawnienia dla Job_Application__c
            SecurityUtils.checkUpdateAccess(Job_Application__c.SObjectType, new List<String>{'Id', 'Assigned_Reviewer__c'});
            
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
    
    /**
     * Get application status history using standard history tracking
     * @param applicationId Application Id
     * @return List of history records
     */
    public static List<Job_Application__History> getApplicationHistory(Id applicationId) {
        try {
            SecurityUtils.checkReadAccess(Job_Application__History.SObjectType, 
                                         new List<String>{'Id', 'Field', 'OldValue', 'NewValue', 'CreatedDate', 'CreatedById'});
            
            return [SELECT Id, Field, OldValue, NewValue, CreatedDate, CreatedBy.Name 
                   FROM Job_Application__History 
                   WHERE ParentId = :applicationId 
                   AND Field = 'Status__c'
                   ORDER BY CreatedDate DESC];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getApplicationHistory', 'Error retrieving application history: ' + applicationId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // ===================== Private helper methods =====================
    
    /**
     * Set default values for new application
     * @param application Application to set defaults for
     */
    private static void setDefaultValues(Job_Application__c application) {
        if (application.Application_Date__c == null) {
            application.Application_Date__c = Date.today();
        }
        
        if (String.isBlank(application.Status__c)) {
            application.Status__c = 'Applied';
        }
    }
}