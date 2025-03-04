/**
 * Service class for Application-related operations
 */
public with sharing class ApplicationService {
    
    /**
     * Get applications for a position
     * @param positionId Position Id
     * @return List of applications
     */
    public static List<Application__c> getApplicationsByPosition(Id positionId) {
        // Sprawdzenie uprawnień na poziomie obiektu
        if (!Schema.SObjectType.Application__c.getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Application__c');
        }
        
        // Sprawdzenie uprawnień na poziomie pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Application__c.fields.getMap();
        if (!fieldMap.get('Name').getDescribe().isAccessible() ||
            !fieldMap.get('Candidate__c').getDescribe().isAccessible() ||
            !fieldMap.get('Position__c').getDescribe().isAccessible() ||
            !fieldMap.get('Status__c').getDescribe().isAccessible() ||
            !fieldMap.get('Application_Date__c').getDescribe().isAccessible() ||
            !fieldMap.get('Last_Modified_Date__c').getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access required Application__c fields');
        }
        
        return [SELECT Id, Name, Candidate__c, Candidate__r.Name, Position__c, Position__r.Name,
                       Status__c, Application_Date__c, Last_Modified_Date__c 
                FROM Application__c 
                WHERE Position__c = :positionId 
                ORDER BY Application_Date__c DESC];
    }
    
    /**
     * Get applications for a candidate
     * @param candidateId Candidate Id
     * @return List of applications
     */
    public static List<Application__c> getApplicationsByCandidate(Id candidateId) {
        // Sprawdzenie uprawnień na poziomie obiektu
        if (!Schema.SObjectType.Application__c.getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Application__c');
        }
        
        // Sprawdzenie uprawnień na poziomie pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Application__c.fields.getMap();
        if (!fieldMap.get('Name').getDescribe().isAccessible() ||
            !fieldMap.get('Candidate__c').getDescribe().isAccessible() ||
            !fieldMap.get('Position__c').getDescribe().isAccessible() ||
            !fieldMap.get('Status__c').getDescribe().isAccessible() ||
            !fieldMap.get('Application_Date__c').getDescribe().isAccessible() ||
            !fieldMap.get('Last_Modified_Date__c').getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access required Application__c fields');
        }
        
        return [SELECT Id, Name, Candidate__c, Candidate__r.Name, Position__c, Position__r.Name,
                       Status__c, Application_Date__c, Last_Modified_Date__c 
                FROM Application__c 
                WHERE Candidate__c = :candidateId 
                ORDER BY Application_Date__c DESC];
    }
    
    /**
     * Get application by Id
     * @param applicationId Application Id
     * @return Application details
     */
    public static Application__c getApplicationById(Id applicationId) {
        // Sprawdzenie uprawnień na poziomie obiektu
        if (!Schema.SObjectType.Application__c.getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Application__c');
        }
        
        // Sprawdzenie uprawnień na poziomie pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Application__c.fields.getMap();
        if (!fieldMap.get('Name').getDescribe().isAccessible() ||
            !fieldMap.get('Candidate__c').getDescribe().isAccessible() ||
            !fieldMap.get('Position__c').getDescribe().isAccessible() ||
            !fieldMap.get('Status__c').getDescribe().isAccessible() ||
            !fieldMap.get('Application_Date__c').getDescribe().isAccessible() ||
            !fieldMap.get('Last_Modified_Date__c').getDescribe().isAccessible() ||
            !fieldMap.get('Cover_Letter__c').getDescribe().isAccessible() ||
            !fieldMap.get('Resume__c').getDescribe().isAccessible() ||
            !fieldMap.get('Notes__c').getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access required Application__c fields');
        }
        
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
    }
    
    /**
     * Create a new application
     * @param application Application to create
     * @return Id of the created application
     */
    public static Id createApplication(Application__c application) {
        // Sprawdzenie uprawnień na poziomie obiektu
        if (!Schema.SObjectType.Application__c.getDescribe().isCreateable()) {
            throw new SecurityException('Insufficient permissions to create Application__c');
        }
        
        // Sprawdzenie uprawnień na poziomie pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Application__c.fields.getMap();
        if (!fieldMap.get('Candidate__c').getDescribe().isCreateable() ||
            !fieldMap.get('Position__c').getDescribe().isCreateable() ||
            !fieldMap.get('Status__c').getDescribe().isCreateable() ||
            !fieldMap.get('Application_Date__c').getDescribe().isCreateable()) {
            throw new SecurityException('Insufficient permissions to create required Application__c fields');
        }
        
        // Sprawdzenie uprawnień na poziomie obiektu dla zapytania SOQL
        if (!Schema.SObjectType.Application__c.getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Application__c');
        }
        
        // Check if application already exists
        List<Application__c> existingApplications = [
            SELECT Id 
            FROM Application__c 
            WHERE Candidate__c = :application.Candidate__c 
            AND Position__c = :application.Position__c
        ];
        
        if (!existingApplications.isEmpty()) {
            throw new AuraHandledException('Candidate has already applied for this position');
        }
        
        // Set default values if not provided
        if (application.Application_Date__c == null) {
            application.Application_Date__c = Date.today();
        }
        
        if (String.isBlank(application.Status__c)) {
            application.Status__c = 'Applied';
        }
        
        insert application;
        
        // Create initial status history record
        createStatusHistoryRecord(application.Id, application.Status__c, 'Initial application');
        
        return application.Id;
    }
    
    /**
     * Update application status
     * @param applicationId Application Id
     * @param status New status
     * @param comments Optional comments
     */
    public static void updateApplicationStatus(Id applicationId, String status, String comments) {
        // Sprawdzenie uprawnień na poziomie obiektu
        if (!Schema.SObjectType.Application__c.getDescribe().isUpdateable()) {
            throw new SecurityException('Insufficient permissions to update Application__c');
        }
        
        // Sprawdzenie uprawnień na poziomie pól
        if (!Schema.SObjectType.Application__c.fields.Status__c.getDescribe().isUpdateable()) {
            throw new SecurityException('Insufficient permissions to update Status__c field');
        }
        
        Application__c application = getApplicationById(applicationId);
        
        // Only update if status has changed
        if (application.Status__c != status) {
            application.Status__c = status;
            update application;
            
            // Create status history record
            createStatusHistoryRecord(applicationId, status, comments);
        }
    }
    
    /**
     * Create status history record
     * @param applicationId Application Id
     * @param status Status
     * @param comments Comments
     */
    private static void createStatusHistoryRecord(Id applicationId, String status, String comments) {
        // Sprawdzenie uprawnień na poziomie obiektu
        if (!Schema.SObjectType.ApplicationStatusHistory__c.getDescribe().isCreateable()) {
            throw new SecurityException('Insufficient permissions to create ApplicationStatusHistory__c');
        }
        
        // Sprawdzenie uprawnień na poziomie pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.ApplicationStatusHistory__c.fields.getMap();
        if (!fieldMap.get('Application__c').getDescribe().isCreateable() ||
            !fieldMap.get('Status__c').getDescribe().isCreateable() ||
            !fieldMap.get('Comments__c').getDescribe().isCreateable() ||
            !fieldMap.get('Change_Date__c').getDescribe().isCreateable()) {
            throw new SecurityException('Insufficient permissions to create required ApplicationStatusHistory__c fields');
        }
        
        ApplicationStatusHistory__c history = new ApplicationStatusHistory__c(
            Application__c = applicationId,
            Status__c = status,
            Comments__c = comments,
            Change_Date__c = DateTime.now()
        );
        
        insert history;
    }
    
    /**
     * Get application history
     * @param applicationId Application Id
     * @return List of status history records
     */
    public static List<ApplicationStatusHistory__c> getApplicationHistory(Id applicationId) {
        // Sprawdzenie uprawnień na poziomie obiektu
        if (!Schema.SObjectType.ApplicationStatusHistory__c.getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access ApplicationStatusHistory__c');
        }
        
        // Sprawdzenie uprawnień na poziomie pól
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.ApplicationStatusHistory__c.fields.getMap();
        if (!fieldMap.get('Status__c').getDescribe().isAccessible() ||
            !fieldMap.get('Comments__c').getDescribe().isAccessible() ||
            !fieldMap.get('Change_Date__c').getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to access required ApplicationStatusHistory__c fields');
        }
        
        return [SELECT Id, Status__c, Comments__c, Change_Date__c, CreatedBy.Name 
                FROM ApplicationStatusHistory__c 
                WHERE Application__c = :applicationId 
                ORDER BY Change_Date__c DESC];
    }
} 