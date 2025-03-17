/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 03-17-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
// Skrypt do opisania pól obiektu Position__c
Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Position__c.fields.getMap();
System.debug('Fields in Position__c:');
for (String fieldName : fieldMap.keySet()) {
    Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
    System.debug(fieldName + ' - ' + dfr.getType() + ' - ' + dfr.getLabel());
} 