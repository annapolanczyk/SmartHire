/**
 * Klasa pomocnicza do centralnego zarządzania uprawnieniami i zabezpieczeniami
 * @author SmartHire Team
 * @date 2025-03-03
 */
public with sharing class SecurityUtils {
    
    /**
     * Check if the current user has read access to the specified object and fields
     * @param objectType The SObject type to check
     * @param fields List of field API names to check
     */
    public static void checkReadAccess(Schema.SObjectType objectType, List<String> fields) {
        Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
        if (!objectDescribe.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access ' + objectDescribe.getName());
        }
        
        Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
        for (String field : fields) {
            if (!fieldMap.get(field).getDescribe().isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access ' + objectDescribe.getName() + '.' + field);
            }
        }
    }
    
    /**
     * Check if the current user has create access to the specified object and fields
     * @param objectType The SObject type to check
     * @param fields List of field API names to check
     */
    public static void checkCreateAccess(Schema.SObjectType objectType, List<String> fields) {
        Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
        if (!objectDescribe.isCreateable()) {
            throw new AuraHandledException('Insufficient permissions to create ' + objectDescribe.getName());
        }
        
        Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
        for (String field : fields) {
            if (!fieldMap.get(field).getDescribe().isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create ' + objectDescribe.getName() + '.' + field);
            }
        }
    }
    
    /**
     * Check if the current user has update access to the specified object and fields
     * @param objectType The SObject type to check
     * @param fields List of field API names to check
     */
    public static void checkUpdateAccess(Schema.SObjectType objectType, List<String> fields) {
        Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
        if (!objectDescribe.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update ' + objectDescribe.getName());
        }
        
        Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
        for (String field : fields) {
            if (!fieldMap.get(field).getDescribe().isUpdateable()) {
                throw new AuraHandledException('Insufficient permissions to update ' + objectDescribe.getName() + '.' + field);
            }
        }
    }
    
    /**
     * Check if the current user has delete access to the specified object
     * @param objectType The SObject type to check
     */
    public static void checkDeleteAccess(Schema.SObjectType objectType) {
        Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
        if (!objectDescribe.isDeletable()) {
            throw new AuraHandledException('Insufficient permissions to delete ' + objectDescribe.getName());
        }
    }
    
    /**
     * Sprawdza uprawnienia do odczytu konkretnych pól obiektu
     * @param objectType Typ obiektu do sprawdzenia
     * @param fieldApiNames Lista nazw API pól do sprawdzenia
     * @param accessType Typ dostępu (READ, CREATE, UPDATE)
     * @throws SecurityException jeśli użytkownik nie ma wymaganych uprawnień
     */
    public static void checkFieldAccess(SObjectType objectType, List<String> fieldApiNames, String accessType) {
        Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
        
        for (String fieldName : fieldApiNames) {
            if (!fieldMap.containsKey(fieldName)) {
                throw new SecurityException('Pole nie istnieje: ' + fieldName);
            }
            
            Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
            Boolean hasAccess = false;
            
            switch on accessType.toUpperCase() {
                when 'READ' {
                    hasAccess = fieldDescribe.isAccessible();
                }
                when 'CREATE' {
                    hasAccess = fieldDescribe.isCreateable();
                }
                when 'UPDATE' {
                    hasAccess = fieldDescribe.isUpdateable();
                }
                when else {
                    throw new SecurityException('Nieprawidłowy typ dostępu: ' + accessType);
                }
            }
            
            if (!hasAccess) {
                throw new SecurityException('Brak uprawnień do ' + accessType + ' dla pola: ' + fieldName);
            }
        }
    }
    
    /**
     * Niestandardowy wyjątek do obsługi problemów z bezpieczeństwem
     */
    public class SecurityException extends Exception {}
}