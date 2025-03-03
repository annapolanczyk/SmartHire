/**
 * Service class to handle Position related operations
 */
public with sharing class PositionService {
    
    /**
     * Get all active positions
     * @return List of active positions
     */
    public static List<Position__c> getActivePositions() {
        return [
            SELECT Id, Name, Description__c, Location__c, Department__c, Status__c, 
                   Hiring_Manager__c, Hiring_Manager__r.Name, Close_Date__c
            FROM Position__c
            WHERE Status__c = 'Open'
            ORDER BY CreatedDate DESC
        ];
    }
    
    /**
     * Get position details by Id
     * @param positionId Position Id
     * @return Position details
     */
    public static Position__c getPositionById(Id positionId) {
        List<Position__c> positions = [
            SELECT Id, Name, Description__c, Location__c, Department__c, Status__c, 
                   Hiring_Manager__c, Hiring_Manager__r.Name, Close_Date__c,
                   (SELECT Id, Name, Status__c FROM Job_Applications__r)
            FROM Position__c
            WHERE Id = :positionId
        ];
        
        if (positions.isEmpty()) {
            throw new AuraHandledException('Position not found');
        }
        
        return positions[0];
    }
    
    /**
     * Create a new position
     * @param position Position to create
     * @return Created position Id
     */
    public static Id createPosition(Position__c position) {
        try {
            // Check CRUD permissions
            if (!Schema.sObjectType.Position__c.isCreateable()) {
                throw new AuraHandledException('You don\'t have permission to create positions');
            }
            
            insert position;
            return position.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating position: ' + e.getMessage());
        }
    }
    
    /**
     * Update a position
     * @param position Position to update
     */
    public static void updatePosition(Position__c position) {
        try {
            // Check CRUD permissions
            if (!Schema.sObjectType.Position__c.isUpdateable()) {
                throw new AuraHandledException('You don\'t have permission to update positions');
            }
            
            update position;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating position: ' + e.getMessage());
        }
    }
    
    /**
     * Get application statistics for a position
     * @param positionId Position Id
     * @return Map with statistics
     */
    public static Map<String, Integer> getApplicationStatistics(Id positionId) {
        Map<String, Integer> statistics = new Map<String, Integer>();
        
        // Query for applications by status
        AggregateResult[] results = [
            SELECT Status__c, COUNT(Id) total
            FROM Job_Application__c 
            WHERE Position__c = :positionId
            GROUP BY Status__c
        ];
        
        // Initialize with zero counts
        statistics.put('Applied', 0);
        statistics.put('Resume Review', 0);
        statistics.put('Phone Screen', 0);
        statistics.put('Interview', 0);
        statistics.put('Evaluation', 0);
        statistics.put('Offer Extended', 0);
        statistics.put('Hired', 0);
        statistics.put('Rejected', 0);
        statistics.put('Total', 0);
        
        Integer total = 0;
        
        // Populate actual counts
        for (AggregateResult ar : results) {
            String status = (String)ar.get('Status__c');
            Integer count = (Integer)ar.get('total');
            statistics.put(status, count);
            total += count;
        }
        
        statistics.put('Total', total);
        
        return statistics;
    }
}