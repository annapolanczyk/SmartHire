/**
 * Service class for Position-related operations
 */
public with sharing class PositionService {
    
    private static final String CLASS_NAME = 'PositionService';
    
    private static final List<String> BASIC_FIELDS = new List<String>{
        'Name', 'Department__c', 'Status__c', 'Location__c',
        'Required_Skills__c', 'Salary_Range__c'
    };
    
    // Pole Qualifications__c zostało usunięte, ponieważ używamy Required_Skills__c
    private static final List<String> DETAIL_FIELDS = new List<String>{
        'Description__c'
    };

    /**
     * Get all positions
     * @return List of positions
     */
    public static List<Position__c> getAllPositions() {
        if (!Schema.SObjectType.Position__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Position__c');
        }

        List<Position__c> positions = [SELECT Id, Name, Department__c, Status__c, Location__c,
                                              Required_Skills__c, Salary_Range__c 
                                       FROM Position__c 
                                       ORDER BY Name ASC];

        return positions.isEmpty() ? new List<Position__c>() : positions;
    }
    
    /**
     * Get position by Id
     */
    public static Position__c getPositionById(Id positionId) {
        if (!Schema.SObjectType.Position__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Position__c');
        }

        List<Position__c> positions = [SELECT Id, Name, Department__c, Status__c, Location__c,
                                              Required_Skills__c, Salary_Range__c, Description__c
                                       FROM Position__c 
                                       WHERE Id = :positionId];

        if (positions.isEmpty()) {
            throw new AuraHandledException('Position not found');
        }

        return positions[0];
    }

    /**
     * Create a new position
     */
    public static Id createPosition(Position__c position) {
        if (!Schema.SObjectType.Position__c.isCreateable()) {
            throw new AuraHandledException('Insufficient permissions to create Position__c');
        }

        insert position;
        return position.Id;
    }

    /**
     * Update an existing position
     */
    public static void updatePosition(Position__c position) {
        if (!Schema.SObjectType.Position__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Position__c');
        }

        update position;
    }

    /**
     * Get application statistics for a position
     */
    public static Map<String, Integer> getApplicationStatistics(Id positionId) {
        if (!Schema.SObjectType.Job_Application__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Job_Application__c');
        }

        Map<String, Integer> statistics = new Map<String, Integer>();

        for (AggregateResult ar : [SELECT Status__c, COUNT(Id) countValue 
                                   FROM Job_Application__c 
                                   WHERE Position__c = :positionId 
                                   GROUP BY Status__c]) {
            statistics.put((String)ar.get('Status__c'), (Integer)ar.get('countValue'));
        }

        return statistics;
    }

    /**
     * Get all active positions
     */
    public static List<Position__c> getActivePositions() {
        if (!Schema.SObjectType.Position__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Position__c');
        }

        List<Position__c> positions = [SELECT Id, Name, Department__c, Status__c, Location__c, 
                                              Required_Skills__c, Salary_Range__c 
                                       FROM Position__c 
                                       WHERE Status__c = 'Open' 
                                       ORDER BY CreatedDate DESC];

        return positions.isEmpty() ? new List<Position__c>() : positions;
    }
}