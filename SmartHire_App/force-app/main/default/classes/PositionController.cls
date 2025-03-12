/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 03-05-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class PositionController {  // ✅ Dodajemy brakującą deklarację klasy

    /**
     * Get all active positions
     * @return List of active positions
     */
    @AuraEnabled(cacheable=true)
    public static List<Position__c> getActivePositions() {
        return PositionService.getActivePositions();
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
}