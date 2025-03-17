/**
 * Class representing the CandidateConversionHistory__c custom object
 * Used to track candidate conversion history
 */
public with sharing class CandidateConversionHistory {
    
    /**
     * Custom object fields:
     * - Candidate__c: Lookup to Candidate__c
     * - Conversion_Date__c: DateTime when conversion occurred
     * - Type__c: String representing conversion type (Contact, User, Employee)
     * - Related_Record__c: ID of the created record
     */
    
    /**
     * Create a new conversion history record
     * @param candidateId Candidate Id
     * @param type Conversion type
     * @param relatedRecordId Related record Id
     * @return Id of the created history record
     */
    public static Id createHistoryRecord(Id candidateId, String type, Id relatedRecordId) {
        // Check permissions
        if (!Schema.SObjectType.CandidateConversionHistory__c.isCreateable()) {
            throw new AuraHandledException('Insufficient permissions to create CandidateConversionHistory__c');
        }
        
        // Check field permissions
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.CandidateConversionHistory__c.fields.getMap();
        for (String field : new List<String>{'Candidate__c', 'Conversion_Date__c', 'Type__c', 'Related_Record__c'}) {
            if (!fieldMap.get(field).getDescribe().isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create CandidateConversionHistory__c.' + field);
            }
        }
        
        // Create history record
        CandidateConversionHistory__c history = new CandidateConversionHistory__c(
            Candidate__c = candidateId,
            Conversion_Date__c = DateTime.now(),
            Type__c = type,
            Related_Record__c = relatedRecordId
        );
        
        insert history;
        return history.Id;
    }
    
    /**
     * Get conversion history for a candidate
     * @param candidateId Candidate Id
     * @return List of conversion history records
     */
    public static List<CandidateConversionHistory__c> getHistoryForCandidate(Id candidateId) {
        // Check permissions
        if (!Schema.SObjectType.CandidateConversionHistory__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access CandidateConversionHistory__c');
        }
        
        // Check field permissions
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.CandidateConversionHistory__c.fields.getMap();
        for (String field : new List<String>{'Candidate__c', 'Conversion_Date__c', 'Type__c', 'Related_Record__c'}) {
            if (!fieldMap.get(field).getDescribe().isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access CandidateConversionHistory__c.' + field);
            }
        }
        
        // Query history records
        return [SELECT Id, Conversion_Date__c, Type__c, Related_Record__c 
                FROM CandidateConversionHistory__c 
                WHERE Candidate__c = :candidateId 
                ORDER BY Conversion_Date__c DESC];
    }
} 