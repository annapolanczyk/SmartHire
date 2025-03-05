/**
 * Klasa testowa dla SecurityUtils
 * @author SmartHire Team
 * @date 2025-03-03
 */
@isTest
private class SecurityUtilsTest {
    
    /**
     * Test sprawdzania uprawnień do odczytu
     */
    @isTest
    static void testCheckReadAccess() {
        Test.startTest();
        
        // Test dla obiektu, do którego użytkownik ma dostęp
        try {
            SecurityUtils.checkReadAccess(
                Account.getSObjectType(), 
                new List<String>{'Name', 'Industry', 'Phone'}
            );
            // Jeśli nie zostanie zgłoszony wyjątek, test jest pomyślny
            System.assert(true, 'Użytkownik powinien mieć uprawnienia do odczytu konta');
        } catch (SecurityUtils.SecurityException e) {
            System.assert(false, 'Nie powinien zostać zgłoszony wyjątek: ' + e.getMessage());
        }
        
        // Test dla nieistniejącego pola
        try {
            SecurityUtils.checkReadAccess(
                Account.getSObjectType(), 
                new List<String>{'Name', 'NonExistentField'}
            );
            System.assert(false, 'Powinien zostać zgłoszony wyjątek dla nieistniejącego pola');
        } catch (SecurityUtils.SecurityException e) {
            System.assert(e.getMessage().contains('Pole nie istnieje'), 
                         'Wyjątek powinien zawierać informację o nieistniejącym polu');
        }
        
        Test.stopTest();
    }
    
    /**
     * Test sprawdzania uprawnień do tworzenia
     */
    @isTest
    static void testCheckCreateAccess() {
        Test.startTest();
        
        // Test dla obiektu, do którego użytkownik ma dostęp
        try {
            SecurityUtils.checkCreateAccess(
                Account.getSObjectType(), 
                new List<String>{'Name', 'Industry', 'Phone'}
            );
            // Jeśli nie zostanie zgłoszony wyjątek, test jest pomyślny
            System.assert(true, 'Użytkownik powinien mieć uprawnienia do tworzenia konta');
        } catch (SecurityUtils.SecurityException e) {
            System.assert(false, 'Nie powinien zostać zgłoszony wyjątek: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    /**
     * Test sprawdzania uprawnień do aktualizacji
     */
    @isTest
    static void testCheckUpdateAccess() {
        Test.startTest();
        
        // Test dla obiektu, do którego użytkownik ma dostęp
        try {
            SecurityUtils.checkUpdateAccess(
                Account.getSObjectType(), 
                new List<String>{'Name', 'Industry', 'Phone'}
            );
            // Jeśli nie zostanie zgłoszony wyjątek, test jest pomyślny
            System.assert(true, 'Użytkownik powinien mieć uprawnienia do aktualizacji konta');
        } catch (SecurityUtils.SecurityException e) {
            System.assert(false, 'Nie powinien zostać zgłoszony wyjątek: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    /**
     * Test sprawdzania uprawnień do usuwania
     */
    @isTest
    static void testCheckDeleteAccess() {
        Test.startTest();
        
        // Test dla obiektu, do którego użytkownik ma dostęp
        try {
            SecurityUtils.checkDeleteAccess(Account.getSObjectType());
            // Jeśli nie zostanie zgłoszony wyjątek, test jest pomyślny
            System.assert(true, 'Użytkownik powinien mieć uprawnienia do usuwania konta');
        } catch (SecurityUtils.SecurityException e) {
            System.assert(false, 'Nie powinien zostać zgłoszony wyjątek: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    /**
     * Test wyjątku bezpieczeństwa
     */
    @isTest
    static void testSecurityException() {
        SecurityUtils.SecurityException secEx = new SecurityUtils.SecurityException('Test exception');
        System.assertEquals('Test exception', secEx.getMessage(), 'Wiadomość wyjątku powinna być zgodna');
    }
}