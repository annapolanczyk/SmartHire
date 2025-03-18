/**
 * Klasa do logowania błędów i zdarzeń w aplikacji
 * @author SmartHire Team
 * @date 2025-03-03
 */
public with sharing class Logger {
    
    /**
     * Log an error message
     * @param logEntry Obiekt zawierający informacje o błędzie
     */
    public static void error(LogEntry logEntry) {
        String fullMessage = String.format('Error in {0}.{1}: {2}', 
            new List<String>{ logEntry.className, logEntry.methodName, logEntry.message });
            
        if (logEntry.error != null) {
            fullMessage += '\nException: ' + logEntry.error.getMessage() + '\nStack trace: ' + logEntry.error.getStackTraceString();
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
                Class_Name__c = logEntry.className,
                Method_Name__c = logEntry.methodName,
                Message__c = logEntry.message,
                Stack_Trace__c = logEntry.error != null ? logEntry.error.getStackTraceString() : '',
                Exception_Type__c = logEntry.error != null ? logEntry.error.getTypeName() : '',
                Log_Time__c = Datetime.now()
            );
        
            // Użyj Database.DMLOptions z jawnie ustawioną opcją sprawdzania uprawnień
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
            dmlOptions.OptAllOrNone = true;
            
            // Wykonaj operację DML z obsługą błędów
            Database.SaveResult result = Database.insert(log, dmlOptions);
            if (!result.isSuccess()) {
                System.debug(LoggingLevel.ERROR, 'Failed to create error log: ' + result.getErrors()[0].getMessage());
            }
        } catch (Exception ex) {
            // If we can't insert the log record, at least write to debug logs
            System.debug(LoggingLevel.ERROR, 'Failed to create error log: ' + ex.getMessage());
        }
    }
    
    /**
     * Log an error message with just the message
     * @param message Error message
     */
    public static void error(String message) {
        String className = 'Unknown';
        String methodName = 'Unknown';
        
        // Get stack trace to determine calling class and method
        try {
            throw new DmlException();
        } catch (Exception e) {
            String stackTrace = e.getStackTraceString();
            List<String> stackLines = stackTrace.split('\n');
            if (stackLines.size() > 1) {
                String callerLine = stackLines[1]; // Index 1 is the caller of this method
                List<String> parts = callerLine.split('\\.');
                if (parts.size() >= 2) {
                    className = parts[parts.size() - 2];
                    methodName = parts[parts.size() - 1].split(':')[0];
                }
            }
        }
        
        LogEntry logEntry = new LogEntry(className, methodName, message);
        error(logEntry);
    }
    
    /**
     * Log an error message with message and exception
     * @param message Error message
     * @param e Exception object
     */
    public static void error(String message, Exception e) {
        String className = 'Unknown';
        String methodName = 'Unknown';
        
        // Get stack trace to determine calling class and method
        try {
            throw new DmlException();
        } catch (Exception ex) {
            String stackTrace = ex.getStackTraceString();
            List<String> stackLines = stackTrace.split('\n');
            if (stackLines.size() > 1) {
                String callerLine = stackLines[1]; // Index 1 is the caller of this method
                List<String> parts = callerLine.split('\\.');
                if (parts.size() >= 2) {
                    className = parts[parts.size() - 2];
                    methodName = parts[parts.size() - 1].split(':')[0];
                }
            }
        }
        
        LogEntry logEntry = new LogEntry(className, methodName, message);
        logEntry.error = e;
        error(logEntry);
    }
    
    /**
     * Log a warning message
     * @param className Name of the class
     * @param methodName Name of the method
     * @param message Warning message
     */
    public static void warn(String className, String methodName, String message) {
        String fullMessage = String.format('Warning in {0}.{1}: {2}', 
            new List<String>{ className, methodName, message });
        
        // Log to debug logs
        System.debug(LoggingLevel.WARN, fullMessage);
    }
    
    /**
     * Log a warning message with just the message
     * @param message Warning message
     */
    public static void warn(String message) {
        String className = 'Unknown';
        String methodName = 'Unknown';
        
        // Get stack trace to determine calling class and method
        try {
            throw new DmlException();
        } catch (Exception e) {
            String stackTrace = e.getStackTraceString();
            List<String> stackLines = stackTrace.split('\n');
            if (stackLines.size() > 1) {
                String callerLine = stackLines[1]; // Index 1 is the caller of this method
                List<String> parts = callerLine.split('\\.');
                if (parts.size() >= 2) {
                    className = parts[parts.size() - 2];
                    methodName = parts[parts.size() - 1].split(':')[0];
                }
            }
        }
        
        warn(className, methodName, message);
    }
    
    /**
     * Log an info message
     * @param className Name of the class
     * @param methodName Name of the method
     * @param message Info message
     */
    public static void info(String className, String methodName, String message) {
        String fullMessage = String.format('Info from {0}.{1}: {2}', 
            new List<String>{ className, methodName, message });
        
        // Log to debug logs
        System.debug(LoggingLevel.INFO, fullMessage);
    }
    
    /**
     * Log a simple info message (deprecated, use the three-parameter version)
     * @param message Info message
     */
    public static void info(String message) {
        System.debug(LoggingLevel.INFO, message);
    }
    
    // Helper class for storing log entry information
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
     * Loguje informację do debugów systemowych
     * @param entry Obiekt zawierający informacje do zalogowania
     */
    public static void info(LogEntry entry) {
        info(entry.className, entry.methodName, entry.message);
    }
    
    /**
     * Log an error message with class name, method name, message and exception
     * @param className Name of the class where error occurred
     * @param methodName Name of the method where error occurred
     * @param message Error message
     * @param e Exception object (optional)
     * @deprecated Ta metoda ma zbyt wiele parametrów. Zamiast niej użyj error(LogEntry), gdzie LogEntry działa jako DTO (Data Transfer Object).
     * Przykład: Logger.error(new LogEntry('ClassName', 'methodName', 'Error message')); 
     * Lub z wyjątkiem: LogEntry entry = new LogEntry('ClassName', 'methodName', 'Error message'); entry.error = e; Logger.error(entry);
     */
    public static void error(String className, String methodName, String message, Exception e) {
        LogEntry logEntry = new LogEntry(className, methodName, message);
        logEntry.error = e;
        error(logEntry);
    }
}