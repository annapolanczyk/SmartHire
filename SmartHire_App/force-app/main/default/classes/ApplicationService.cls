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
     * @param positionId Position Id
     * @return List of applications
     */
    public static List<Application__c> getApplicationsByPosition(Id positionId) {
        try {
            // Sprawdzamy uprawnienia dla Application__c
            if (!Schema.SObjectType.Application__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Application__c');
            }
            
            // Sprawdzamy uprawnienia dla pól Application__c
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Application__c.fields.getMap();
            for (String field : new List<String>{'Name', 'Candidate__c', 'Position__c', 'Status__c', 
                'Application_Date__c', 'Last_Modified_Date__c'}) {
                if (!fieldMap.get(field).getDescribe().isAccessible()) {
                    throw new AuraHandledException('Insufficient permissions to access Application__c.' + field);
                }
            }
            
            // Sprawdzamy uprawnienia dla Contact (Candidate__r)
            if (!Schema.SObjectType.Contact.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Contact');
            }
            if (!Schema.SObjectType.Contact.fields.Name.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Contact.Name');
            }
            
            // Sprawdzamy uprawnienia dla Position__c
            if (!Schema.SObjectType.Position__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Position__c');
            }
            if (!Schema.SObjectType.Position__c.fields.Name.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Position__c.Name');
            }
            
            // Wykonujemy zapytanie po upewnieniu się, że mamy wszystkie uprawnienia
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
     * @param applicationId Application Id
     * @return Application details
     */
    public static Application__c getApplicationById(Id applicationId) {
        try {
            // Sprawdzamy uprawnienia dla Application__c
            if (!Schema.SObjectType.Application__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Application__c');
            }
            
            // Sprawdzamy uprawnienia dla pól Application__c
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Application__c.fields.getMap();
            List<String> appFields = new List<String>{
                'Name', 'Candidate__c', 'Position__c', 'Status__c', 'Application_Date__c', 
                'Last_Modified_Date__c', 'Cover_Letter__c', 'Resume__c', 'Notes__c'
            };
            for (String field : appFields) {
                if (!fieldMap.get(field).getDescribe().isAccessible()) {
                    throw new AuraHandledException('Insufficient permissions to access Application__c.' + field);
                }
            }
            
            // Sprawdzamy uprawnienia dla Contact (Candidate__r)
            if (!Schema.SObjectType.Contact.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Contact');
            }
            if (!Schema.SObjectType.Contact.fields.Name.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Contact.Name');
            }
            
            // Sprawdzamy uprawnienia dla Position__c
            if (!Schema.SObjectType.Position__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Position__c');
            }
            if (!Schema.SObjectType.Position__c.fields.Name.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Position__c.Name');
            }
            
            // Wykonujemy zapytanie po upewnieniu się, że mamy wszystkie uprawnienia
            List<Application__c> applications = [SELECT Id, Name, Candidate__c, Candidate__r.Name, 
                                                     Position__c, Position__r.Name, Status__c, 
                                                     Application_Date__c, Last_Modified_Date__c,
                                                     Cover_Letter__c, Resume__c, Notes__c 
                                              FROM Application__c 
                                              WHERE Id = :applicationId];
            
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
     * Create a new application
     * @param application Application to create
     * @return Id of the created application
     */
    public static Id createApplication(Application__c application) {
        try {
            // Sprawdzamy uprawnienia przed DML
            validateCreatePermissions();
            validateNoDuplicateApplication(application);
            setDefaultValues(application);
            
            // Sprawdzamy uprawnienia bezpośrednio przed DML
            if (!Schema.SObjectType.Application__c.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Application__c');
            }
            
            // Sprawdzamy uprawnienia dla pól
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Application__c.fields.getMap();
            for (String field : BASIC_FIELDS) {
                if (!fieldMap.get(field).getDescribe().isCreateable()) {
                    throw new AuraHandledException('Insufficient permissions to create Application__c.' + field);
                }
            }
            
            insert application;
            
            // Sprawdzamy uprawnienia dla tworzenia historii statusu
            if (!Schema.SObjectType.ApplicationStatusHistory__c.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create ApplicationStatusHistory__c');
            }
            
            Map<String, Schema.SObjectField> historyFieldMap = Schema.SObjectType.ApplicationStatusHistory__c.fields.getMap();
            for (String field : new List<String>{'Application__c', 'Status__c', 'Comments__c', 'Change_Date__c'}) {
                if (!historyFieldMap.get(field).getDescribe().isCreateable()) {
                    throw new AuraHandledException('Insufficient permissions to create ApplicationStatusHistory__c.' + field);
                }
            }
            
            createStatusHistoryRecord(application.Id, application.Status__c, 'Initial application');
            
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
     * @param comments Optional comments
     */
    public static void updateApplicationStatus(Id applicationId, String status, String comments) {
        try {
            // Sprawdzamy uprawnienia przed DML
            validateUpdatePermissions();
            
            // Najpierw sprawdzamy uprawnienia do odczytu
            if (!Schema.SObjectType.Application__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Application__c');
            }
            if (!Schema.SObjectType.Application__c.fields.Status__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Application__c.Status__c');
            }
                
            Application__c application = getApplicationById(applicationId);
            
            if (application.Status__c == status) {
                return; // No change needed
            }
            
            // Sprawdzamy uprawnienia do utworzenia statusu historii przed aktualizacją
            if (!Schema.SObjectType.ApplicationStatusHistory__c.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create ApplicationStatusHistory__c');
            }
            
            Map<String, Schema.SObjectField> historyFieldMap = Schema.SObjectType.ApplicationStatusHistory__c.fields.getMap();
            for (String field : new List<String>{'Application__c', 'Status__c', 'Comments__c', 'Change_Date__c'}) {
                if (!historyFieldMap.get(field).getDescribe().isCreateable()) {
                    throw new AuraHandledException('Insufficient permissions to create ApplicationStatusHistory__c.' + field);
                }
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
     * @param applicationId Application Id
     * @return List of status history records
     */
    public static List<ApplicationStatusHistory__c> getApplicationHistory(Id applicationId) {
        try {
            // Sprawdzamy uprawnienia do odczytu przed SOQL
            if (!Schema.SObjectType.ApplicationStatusHistory__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access ApplicationStatusHistory__c');
            }
            
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.ApplicationStatusHistory__c.fields.getMap();
            for (String field : new List<String>{'Application__c', 'Status__c', 'Comments__c', 'Change_Date__c', 'CreatedById'}) {
                if (!fieldMap.get(field).getDescribe().isAccessible()) {
                    throw new AuraHandledException('Insufficient permissions to access ApplicationStatusHistory__c.' + field);
                }
            }
            
            // Sprawdzamy uprawnienia dla User (CreatedBy)
            if (!Schema.SObjectType.User.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access User');
            }
            if (!Schema.SObjectType.User.fields.Name.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access User.Name');
            }
            
            // Wykonujemy zapytanie bezpośrednio po sprawdzeniu uprawnień
            return [SELECT Id, Status__c, Comments__c, Change_Date__c, CreatedBy.Name 
                   FROM ApplicationStatusHistory__c 
                   WHERE Application__c = :applicationId 
                   ORDER BY Change_Date__c DESC];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getApplicationHistory', 'Error retrieving application history: ' + applicationId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Private helper methods
    
    private static void validateCreatePermissions() {
        if (!Schema.SObjectType.Application__c.isCreateable()) {
            throw new AuraHandledException('Insufficient permissions to create Application__c');
        }
        
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Application__c.fields.getMap();
        for (String field : new List<String>{'Candidate__c', 'Position__c', 'Status__c', 'Application_Date__c'}) {
            if (!fieldMap.get(field).getDescribe().isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Application__c.' + field);
            }
        }
    }
    
    private static void validateUpdatePermissions() {
        if (!Schema.SObjectType.Application__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Application__c');
        }
        
        if (!Schema.SObjectType.Application__c.fields.Status__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Application__c.Status__c');
        }
    }
    
    private static void validateNoDuplicateApplication(Application__c application) {
        // Sprawdzamy uprawnienia do odczytu przed SOQL
        if (!Schema.SObjectType.Application__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Application__c');
        }
        if (!Schema.SObjectType.Application__c.fields.Candidate__c.isAccessible() ||
            !Schema.SObjectType.Application__c.fields.Position__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Application__c.Candidate__c or Position__c');
        }
        
        // Wykonujemy zapytanie bezpośrednio po sprawdzeniu uprawnień
        List<Application__c> existingApplications = [
            SELECT Id 
            FROM Application__c 
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
        if (!Schema.SObjectType.Application__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Application__c');
        }
        if (!Schema.SObjectType.Application__c.fields.Status__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Application__c.Status__c');
        }
            
        application.Status__c = status;
        update application;
    }
    
    private static void createStatusHistoryRecord(Id applicationId, String status, String comments) {
        // Sprawdzamy uprawnienia do tworzenia przed DML
        if (!Schema.SObjectType.ApplicationStatusHistory__c.isCreateable()) {
            throw new AuraHandledException('Insufficient permissions to create ApplicationStatusHistory__c');
        }
        
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.ApplicationStatusHistory__c.fields.getMap();
        for (String field : new List<String>{'Application__c', 'Status__c', 'Comments__c', 'Change_Date__c'}) {
            if (!fieldMap.get(field).getDescribe().isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create ApplicationStatusHistory__c.' + field);
            }
        }
        
        // Tworzymy rekord
        ApplicationStatusHistory__c history = new ApplicationStatusHistory__c(
            Application__c = applicationId,
            Status__c = status,
            Comments__c = comments,
            Change_Date__c = DateTime.now()
        );
        
        // Wykonujemy operację DML bezpośrednio po sprawdzeniu uprawnień
        insert history;
    }
}