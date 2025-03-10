/**
 * Service class for Application-related operations
 */
public with sharing class ApplicationService {
    
    private static final String CLASS_NAME = 'ApplicationService';
    
    private static final List<String> BASIC_FIELDS = new List<String>{
        'Name', 'Candidate__c', 'Position__c', 'Status__c',
        'Application_Date__c', 'Last_Modified_Date__c'
    };
    
    private static final List<String> DETAIL_FIELDS = new List<String>{
        'Cover_Letter__c', 'Resume__c', 'Notes__c'
    };
    
    /**
     * Get applications for a position
     */
    public static List<Application__c> getApplicationsByPosition(Id positionId) {
        try {
            validateReadPermissions();

            return [SELECT Id, Name, Candidate__c, Candidate__r.Name, Position__c, Position__r.Name,
                          Status__c, Application_Date__c, Last_Modified_Date__c 
                   FROM Application__c 
                   WHERE Position__c = :positionId 
                   ORDER BY Application_Date__c DESC];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getApplicationsByPosition', 'Error retrieving applications for position: ' + positionId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get application by Id
     */
    public static Application__c getApplicationById(Id applicationId) {
        try {
            validateReadPermissions();

            List<Application__c> applications = [SELECT Id, Name, Candidate__c, Candidate__r.Name, 
                                                     Position__c, Position__r.Name, Status__c, 
                                                     Application_Date__c, Last_Modified_Date__c,
                                                     Cover_Letter__c, Resume__c, Notes__c 
                                              FROM Application__c 
                                              WHERE Id = :applicationId LIMIT 1];
            
            if (applications.isEmpty()) {
                throw new AuraHandledException('Application not found');
            }
            
            return applications[0];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getApplicationById', 'Error retrieving application: ' + applicationId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    public static List<Application__c> getApplicationsByCandidate(Id candidateId) {
        return [SELECT Id, Name, Status__c FROM Application__c WHERE Candidate__c = :candidateId];
    }
    
    /**
     * Create a new application
     */
    public static Id createApplication(Application__c application) {
        try {
            validateCreatePermissions();
            validateNoDuplicateApplication(application);
            setDefaultValues(application);

            insert application;
            createStatusHistoryRecord(application.Id, application.Status__c, 'Initial application');
            
            return application.Id;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'createApplication', 'Error creating application', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Update application status
     */
    public static void updateApplicationStatus(Id applicationId, String status, String comments) {
        try {
            validateUpdatePermissions();

            Application__c application = getApplicationById(applicationId);
            
            if (application.Status__c == status) {
                return; // No change needed
            }
            
            updateStatus(application, status);
            createStatusHistoryRecord(applicationId, status, comments);
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'updateApplicationStatus', 'Error updating application status: ' + applicationId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get application history
     */
    public static List<ApplicationStatusHistory__c> getApplicationHistory(Id applicationId) {
        try {
            if (!Schema.SObjectType.ApplicationStatusHistory__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access ApplicationStatusHistory__c');
            }

            return [SELECT Id, Status__c, Comments__c, Change_Date__c, CreatedBy.Name 
                   FROM ApplicationStatusHistory__c 
                   WHERE Application__c = :applicationId 
                   ORDER BY Change_Date__c DESC];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getApplicationHistory', 'Error retrieving application history: ' + applicationId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // ✅ **Private helper methods**
    
    private static void validateReadPermissions() {
        if (!Schema.SObjectType.Application__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Application__c');
        }
    }

    private static void validateCreatePermissions() {
        if (!Schema.SObjectType.Application__c.isCreateable()) {
            throw new AuraHandledException('Insufficient permissions to create Application__c');
        }
    }
    
    private static void validateUpdatePermissions() {
        if (!Schema.SObjectType.Application__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Application__c');
        }
    }
    
    private static void validateNoDuplicateApplication(Application__c application) {
        if (!Schema.SObjectType.Application__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to check Application__c');
        }

        List<Application__c> existingApplications = [
            SELECT Id FROM Application__c 
            WHERE Candidate__c = :application.Candidate__c 
            AND Position__c = :application.Position__c
        ];
        
        if (!existingApplications.isEmpty()) {
            throw new AuraHandledException('Candidate has already applied for this position');
        }
    }
    
    private static void setDefaultValues(Application__c application) {
        if (application.Application_Date__c == null) {
            application.Application_Date__c = Date.today();
        }
        
        if (String.isBlank(application.Status__c)) {
            application.Status__c = 'Applied';
        }
    }
    
    private static void updateStatus(Application__c application, String status) {
        validateUpdatePermissions();

        application.Status__c = status;
        update application;
    }
    
    private static void createStatusHistoryRecord(Id applicationId, String status, String comments) {
        if (!Schema.SObjectType.ApplicationStatusHistory__c.isCreateable()) {
            throw new AuraHandledException('Insufficient permissions to create ApplicationStatusHistory__c');
        }

        ApplicationStatusHistory__c history = new ApplicationStatusHistory__c(
            Application__c = applicationId,
            Status__c = status,
            Comments__c = comments,
            Change_Date__c = DateTime.now()
        );

        insert history;
    }
}