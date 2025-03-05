/**
 * Service class for Position-related operations
 */
public with sharing class PositionService {
    
    private static final String CLASS_NAME = 'PositionService';
    
    private static final List<String> BASIC_FIELDS = new List<String>{
        'Name', 'Department__c', 'Status__c', 'Location__c',
        'Required_Skills__c', 'Salary_Range__c'
    };
    
    private static final List<String> DETAIL_FIELDS = new List<String>{
        'Description__c', 'Responsibilities__c', 'Qualifications__c'
    };
    
    /**
     * Get all positions
     * @return List of positions
     */
    public static List<Position__c> getAllPositions() {
        try {
            // Sprawdzamy uprawnienia dla Position__c
            if (!Schema.SObjectType.Position__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Position__c');
            }
            
            // Sprawdzamy dostęp do pól
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Position__c.fields.getMap();
            for (String field : BASIC_FIELDS) {
                if (!fieldMap.get(field).getDescribe().isAccessible()) {
                    throw new AuraHandledException('Insufficient permissions to access Position__c.' + field);
                }
            }
            
            return [SELECT Id, Name, Department__c, Status__c, Location__c,
                          Required_Skills__c, Salary_Range__c 
                   FROM Position__c 
                   ORDER BY Name ASC];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getAllPositions', 'Error retrieving positions', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get position by Id
     * @param positionId Position Id
     * @return Position details
     */
    public static Position__c getPositionById(Id positionId) {
        try {
            // Sprawdzamy uprawnienia dla Position__c
            if (!Schema.SObjectType.Position__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Position__c');
            }
            
            // Sprawdzamy dostęp do pól
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Position__c.fields.getMap();
            List<String> allFields = new List<String>();
            allFields.addAll(BASIC_FIELDS);
            allFields.addAll(DETAIL_FIELDS);
            
            for (String field : allFields) {
                if (!fieldMap.get(field).getDescribe().isAccessible()) {
                    throw new AuraHandledException('Insufficient permissions to access Position__c.' + field);
                }
            }
            
            List<Position__c> positions = [SELECT Id, Name, Department__c, Status__c, Location__c,
                                                Required_Skills__c, Salary_Range__c, Description__c,
                                                Responsibilities__c, Qualifications__c 
                                         FROM Position__c 
                                         WHERE Id = :positionId];
            
            if (positions.isEmpty()) {
                throw new AuraHandledException('Position not found');
            }
            
            return positions[0];
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getPositionById', 'Error retrieving position: ' + positionId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Create a new position
     * @param position Position to create
     * @return Id of the created position
     */
    public static Id createPosition(Position__c position) {
        try {
            // Sprawdzamy uprawnienia dla Position__c
            if (!Schema.SObjectType.Position__c.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Position__c');
            }
            
            // Sprawdzamy dostęp do pól
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Position__c.fields.getMap();
            List<String> allFields = new List<String>();
            allFields.addAll(BASIC_FIELDS);
            allFields.addAll(DETAIL_FIELDS);
            
            for (String field : allFields) {
                if (!fieldMap.get(field).getDescribe().isCreateable()) {
                    throw new AuraHandledException('Insufficient permissions to create Position__c.' + field);
                }
            }
            
            insert position;
            return position.Id;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'createPosition', 'Error creating position', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Update an existing position
     * @param position Position to update
     */
    public static void updatePosition(Position__c position) {
        try {
            // Sprawdzamy uprawnienia dla Position__c
            if (!Schema.SObjectType.Position__c.isUpdateable()) {
                throw new AuraHandledException('Insufficient permissions to update Position__c');
            }
            
            // Sprawdzamy dostęp do pól
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Position__c.fields.getMap();
            List<String> allFields = new List<String>();
            allFields.addAll(BASIC_FIELDS);
            allFields.addAll(DETAIL_FIELDS);
            
            for (String field : allFields) {
                if (!fieldMap.get(field).getDescribe().isUpdateable()) {
                    throw new AuraHandledException('Insufficient permissions to update Position__c.' + field);
                }
            }
            
            update position;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'updatePosition', 'Error updating position: ' + position.Id, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get application statistics for a position
     * @param positionId Position Id
     * @return Map of status to count
     */
    public static Map<String, Integer> getApplicationStatistics(Id positionId) {
        try {
            // Sprawdzamy uprawnienia dla Application__c
            if (!Schema.SObjectType.Application__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Application__c');
            }
            
            // Sprawdzamy dostęp do pól
            if (!Schema.SObjectType.Application__c.fields.Status__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Application__c.Status__c');
            }
            
            Map<String, Integer> statistics = new Map<String, Integer>();
            
            for (AggregateResult ar : [SELECT Status__c, COUNT(Id) countValue 
                                     FROM Application__c 
                                     WHERE Position__c = :positionId 
                                     GROUP BY Status__c]) {
                statistics.put((String)ar.get('Status__c'), (Integer)ar.get('countValue'));
            }
            
            return statistics;
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'getApplicationStatistics', 'Error getting statistics for position: ' + positionId, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
}