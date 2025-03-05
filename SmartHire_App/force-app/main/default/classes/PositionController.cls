/**
 * Controller for Position-related operations
 */
public with sharing class PositionController {
    
    /**
     * Get all active positions
     * @return List of active positions
     */
    @AuraEnabled(cacheable=true)
    public static List<Position__c> getActivePositions() {
        return PositionService.getActivePositions(); // ❌ Usunięto zbędny try-catch
    }
    
    /**
     * Get position by Id
     * @param positionId Position Id
     * @return Position details
     */
    @AuraEnabled(cacheable=true)
    public static Position__c getPositionById(Id positionId) {
        return PositionService.getPositionById(positionId);
    }
    
    /**
     * Create a new position
     * @param position Position to create
     * @return Id of the created position
     */
    @AuraEnabled
    public static Id createPosition(Position__c position) {
        return PositionService.createPosition(position);
    }
    
    /**
     * Update an existing position
     * @param position Position to update
     */
    @AuraEnabled
    public static void updatePosition(Position__c position) {
        PositionService.updatePosition(position);
    }
    
    /**
     * Get application statistics for a position
     * @param positionId Position Id
     * @return Map of status to count
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getApplicationStatistics(Id positionId) {
        return PositionService.getApplicationStatistics(positionId);
    }
}
