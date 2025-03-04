/**
 * Service class for Position-related operations
 */
public with sharing class PositionService {
    
    /**
     * Get all active positions
     * @return List of active positions
     */
    public static List<Position__c> getActivePositions() {
        if (!Schema.SObjectType.Position__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Position__c');
        }
        
        return [SELECT Id, Name, Department__c, Location__c, Status__c, 
                       Job_Description__c, Required_Skills__c, Salary_Range__c 
                FROM Position__c 
                WHERE Status__c = 'Open' 
                ORDER BY CreatedDate DESC];
    }
    
    /**
     * Get position by Id
     * @param positionId Position Id
     * @return Position details
     */
    public static Position__c getPositionById(Id positionId) {
        if (!Schema.SObjectType.Position__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Position__c');
        }
        
        List<Position__c> positions = [SELECT Id, Name, Department__c, Location__c, Status__c, 
                                              Job_Description__c, Required_Skills__c, Salary_Range__c 
                                       FROM Position__c 
                                       WHERE Id = :positionId];
        
        if (positions.isEmpty()) {
            throw new AuraHandledException('Position not found');
        }
        
        return positions[0];
    }
    
    /**
     * Create a new position
     * @param position Position to create
     * @return Id of the created position
     */
    public static Id createPosition(Position__c position) {
        if (!Schema.SObjectType.Position__c.isCreateable()) {
            throw new SecurityException('Insufficient permissions to create Position__c');
        }
        
        insert position;
        return position.Id;
    }
    
    /**
     * Update an existing position
     * @param position Position to update
     */
    public static void updatePosition(Position__c position) {
        if (!Schema.SObjectType.Position__c.isUpdateable()) {
            throw new SecurityException('Insufficient permissions to update Position__c');
        }
        
        update position;
    }
    
    /**
     * Get application statistics for a position
     * @param positionId Position Id
     * @return Map of status to count
     */
    public static Map<String, Integer> getApplicationStatistics(Id positionId) {
        if (!Schema.SObjectType.Application__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Application__c');
        }
        
        Map<String, Integer> statistics = new Map<String, Integer>();
        
        for (AggregateResult ar : [SELECT Status__c, COUNT(Id) countValue 
                                  FROM Application__c 
                                  WHERE Position__c = :positionId 
                                  GROUP BY Status__c]) {
            statistics.put((String)ar.get('Status__c'), (Integer)ar.get('countValue'));
        }
        
        return statistics;
    }
}