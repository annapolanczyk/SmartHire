/**
 * Klasa pomocnicza do centralnego zarządzania uprawnieniami i zabezpieczeniami
 * @author SmartHire Team
 * @date 2025-03-03
 */
public with sharing class SecurityUtils {
    
    /**
     * Sprawdza uprawnienia do odczytu obiektu i jego pól
     * @param objectType Typ obiektu do sprawdzenia
     * @param fields Lista pól do sprawdzenia
     * @throws SecurityException jeśli użytkownik nie ma wymaganych uprawnień
     */
    public static void checkReadAccess(SObjectType objectType, List<String> fields) {
        // Sprawdź uprawnienia na poziomie obiektu
        if (!objectType.getDescribe().isAccessible()) {
            throw new SecurityException('Nie masz uprawnień do odczytu obiektów typu: ' + objectType.getDescribe().getLabel());
        }
        
        // Sprawdź uprawnienia na poziomie pola
        Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
        for (String fieldName : fields) {
            if (!fieldMap.containsKey(fieldName)) {
                throw new SecurityException('Pole nie istnieje: ' + fieldName);
            }
            if (!fieldMap.get(fieldName).getDescribe().isAccessible()) {
                throw new SecurityException('Nie masz uprawnień do odczytu pola: ' + fieldName);
            }
        }
    }
    
    /**
     * Sprawdza uprawnienia do tworzenia obiektu i jego pól
     * @param objectType Typ obiektu do sprawdzenia
     * @param fields Lista pól do sprawdzenia
     * @throws SecurityException jeśli użytkownik nie ma wymaganych uprawnień
     */
    public static void checkCreateAccess(SObjectType objectType, List<String> fields) {
        // Sprawdź uprawnienia na poziomie obiektu
        if (!objectType.getDescribe().isCreateable()) {
            throw new SecurityException('Nie masz uprawnień do tworzenia obiektów typu: ' + objectType.getDescribe().getLabel());
        }
        
        // Sprawdź uprawnienia na poziomie pola
        Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
        for (String fieldName : fields) {
            if (!fieldMap.containsKey(fieldName)) {
                throw new SecurityException('Pole nie istnieje: ' + fieldName);
            }
            if (!fieldMap.get(fieldName).getDescribe().isCreateable()) {
                throw new SecurityException('Nie masz uprawnień do tworzenia pola: ' + fieldName);
            }
        }
    }
    
    /**
     * Sprawdza uprawnienia do aktualizacji obiektu i jego pól
     * @param objectType Typ obiektu do sprawdzenia
     * @param fields Lista pól do sprawdzenia
     * @throws SecurityException jeśli użytkownik nie ma wymaganych uprawnień
     */
    public static void checkUpdateAccess(SObjectType objectType, List<String> fields) {
        // Sprawdź uprawnienia na poziomie obiektu
        if (!objectType.getDescribe().isUpdateable()) {
            throw new SecurityException('Nie masz uprawnień do aktualizacji obiektów typu: ' + objectType.getDescribe().getLabel());
        }
        
        // Sprawdź uprawnienia na poziomie pola
        Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
        for (String fieldName : fields) {
            if (!fieldMap.containsKey(fieldName)) {
                throw new SecurityException('Pole nie istnieje: ' + fieldName);
            }
            if (!fieldMap.get(fieldName).getDescribe().isUpdateable()) {
                throw new SecurityException('Nie masz uprawnień do aktualizacji pola: ' + fieldName);
            }
        }
    }
    
    /**
     * Sprawdza uprawnienia do usuwania obiektu
     * @param objectType Typ obiektu do sprawdzenia
     * @throws SecurityException jeśli użytkownik nie ma wymaganych uprawnień
     */
    public static void checkDeleteAccess(SObjectType objectType) {
        // Sprawdź uprawnienia na poziomie obiektu
        if (!objectType.getDescribe().isDeletable()) {
            throw new SecurityException('Nie masz uprawnień do usuwania obiektów typu: ' + objectType.getDescribe().getLabel());
        }
    }
    
    /**
     * Niestandardowy wyjątek do obsługi problemów z bezpieczeństwem
     */
    public class SecurityException extends Exception {}
}