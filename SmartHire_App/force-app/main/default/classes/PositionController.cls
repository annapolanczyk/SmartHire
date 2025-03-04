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
        try {
            return PositionService.getActivePositions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get position by Id
     * @param positionId Position Id
     * @return Position details
     */
    @AuraEnabled(cacheable=true)
    public static Position__c getPositionById(Id positionId) {
        try {
            return PositionService.getPositionById(positionId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Create a new position
     * @param position Position to create
     * @return Id of the created position
     */
    @AuraEnabled
    public static Id createPosition(Position__c position) {
        try {
            return PositionService.createPosition(position);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Update an existing position
     * @param position Position to update
     */
    @AuraEnabled
    public static void updatePosition(Position__c position) {
        try {
            PositionService.updatePosition(position);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Get application statistics for a position
     * @param positionId Position Id
     * @return Map of status to count
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getApplicationStatistics(Id positionId) {
        try {
            return PositionService.getApplicationStatistics(positionId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
} 