/**
 * Klasa do logowania błędów i zdarzeń w aplikacji
 * @author SmartHire Team
 * @date 2025-03-03
 */
public with sharing class Logger {
    public class LogEntry {
        public String className;
        public String methodName;
        public String message;
        public Exception error;
        
        public LogEntry(String className, String methodName, String message) {
            this.className = className;
            this.methodName = methodName;
            this.message = message;
        }
    }
    
    /**
     * Loguje błąd do debugów systemowych
     * @param entry Obiekt zawierający informacje o błędzie
     */
    public static void error(LogEntry entry) {
        System.debug(LoggingLevel.ERROR, entry.className + '.' + entry.methodName + ': ' + entry.message);
        if (entry.error != null) {
            System.debug(LoggingLevel.ERROR, 'Wyjątek: ' + entry.error.getMessage() + '\n' + entry.error.getStackTraceString());
        }
        
        // Implementacja logowania do obiektu niestandardowego zostanie dodana w przyszłych wersjach
    }
    
    /**
     * Loguje informację do debugów systemowych
     * @param entry Obiekt zawierający informacje do zalogowania
     */
    public static void info(LogEntry entry) {
        System.debug(LoggingLevel.INFO, entry.className + '.' + entry.methodName + ': ' + entry.message);
        
        // Implementacja logowania do obiektu niestandardowego zostanie dodana w przyszłych wersjach
    }

    /**
     * Log an error message
     * @param className Name of the class where error occurred
     * @param methodName Name of the method where error occurred
     * @param message Error message
     * @param e Exception object (optional)
     */
    public static void error(String className, String methodName, String message, Exception e) {
        String fullMessage = String.format('Error in {0}.{1}: {2}', 
            new List<String>{ className, methodName, message });
            
        if (e != null) {
            fullMessage += '\nException: ' + e.getMessage() + '\nStack trace: ' + e.getStackTraceString();
        }
        
        // Log to debug logs
        System.debug(LoggingLevel.ERROR, fullMessage);

        try {
            // Sprawdź uprawnienia przed utworzeniem rekordu
            if (!Schema.SObjectType.Error_Log__c.isCreateable()) {
                System.debug(LoggingLevel.WARN, 'Insufficient permissions to create Error_Log__c records.');
                return;
            }
            
            // Sprawdź uprawnienia do poszczególnych pól
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Error_Log__c.fields.getMap();
            for (String field : new List<String>{'Class_Name__c', 'Method_Name__c', 'Message__c', 'Stack_Trace__c', 'Exception_Type__c', 'Log_Time__c'}) {
                if (!fieldMap.get(field).getDescribe().isCreateable()) {
                    System.debug(LoggingLevel.WARN, 'Insufficient permissions to create Error_Log__c.' + field);
                    return;
                }
            }
        
        // Create error log record
        Error_Log__c log = new Error_Log__c(
            Class_Name__c = className,
            Method_Name__c = methodName,
            Message__c = message,
            Stack_Trace__c = e != null ? e.getStackTraceString() : '',
            Exception_Type__c = e != null ? e.getTypeName() : '',
            Log_Time__c = Datetime.now()
        );
        
            insert log;
        } catch (Exception ex) {
            // If we can't insert the log record, at least write to debug logs
            System.debug(LoggingLevel.ERROR, 'Failed to create error log: ' + ex.getMessage());
        }
    }
}