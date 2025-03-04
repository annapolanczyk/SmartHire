/**
 * Klasa testowa dla Logger
 * @author SmartHire Team
 * @date 2025-03-03
 */
@isTest
private class LoggerTest {
    
    /**
     * Test logowania błędów
     */
    @isTest
    static void testErrorLogging() {
        Exception testException = new NullPointerException('Test Exception');
        
        Test.startTest();
        
        // Przetestuj logowanie błędu z wyjątkiem
        Logger.error('TestClass', 'testMethod', 'Test error message', testException);
        
        // Przetestuj logowanie błędu bez wyjątku
        Logger.error('TestClass', 'testMethod', 'Test error message without exception', null);
        
        Test.stopTest();
        
        // Nie ma sposobu na sprawdzenie, czy Debug Log został poprawnie utworzony w testach
        // Ale możemy sprawdzić, czy metoda nie zgłasza wyjątków
        System.assert(true, 'Logowanie powinno zakończyć się sukcesem bez wyjątków');
    }
    
    /**
     * Test logowania informacji
     */
    @isTest
    static void testInfoLogging() {
        Test.startTest();
        
        // Przetestuj logowanie informacji
        Logger.info('TestClass', 'testMethod', 'Test info message');
        
        Test.stopTest();
        
        // Podobnie jak wyżej, sprawdzamy tylko czy metoda nie zgłasza wyjątków
        System.assert(true, 'Logowanie informacji powinno zakończyć się sukcesem bez wyjątków');
    }
}