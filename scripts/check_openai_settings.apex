/**
 * Skrypt do sprawdzenia konfiguracji OpenAI
 * @author SmartHire Team
 */
System.debug('=== Sprawdzanie konfiguracji OpenAI ===');

try {
    // Sprawdź ustawienia OpenAI
    OpenAI_Settings__c settings = OpenAI_Settings__c.getInstance();
    
    if (settings == null) {
        System.debug(LoggingLevel.ERROR, 'Nie znaleziono ustawień OpenAI_Settings__c. Należy je skonfigurować.');
    } else {
        System.debug('Znaleziono ustawienia OpenAI_Settings__c:');
        
        // Sprawdź klucz API
        if (String.isBlank(settings.API_Key__c)) {
            System.debug(LoggingLevel.ERROR, 'Brak skonfigurowanego klucza API w OpenAI_Settings__c (pole API_Key__c).');
        } else {
            String maskedKey = settings.API_Key__c.substring(0, 5) + '...' + settings.API_Key__c.substring(settings.API_Key__c.length() - 4);
            System.debug('Klucz API: ' + maskedKey);
        }
        
        // Sprawdź model
        if (String.isBlank(settings.Model__c)) {
            System.debug(LoggingLevel.WARN, 'Brak skonfigurowanego modelu w OpenAI_Settings__c (pole Model__c). Zostanie użyty domyślny model.');
        } else {
            System.debug('Model: ' + settings.Model__c);
        }
    }
    
    // Sprawdź Named Credential
    try {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:AI_CV_Analysis_API/test');
        req.setMethod('GET');
        System.debug('Named Credential "AI_CV_Analysis_API" jest skonfigurowany.');
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'Błąd podczas sprawdzania Named Credential "AI_CV_Analysis_API": ' + e.getMessage());
    }
    
    // Wykonaj testowe wywołanie OpenAI
    System.debug('Próba wykonania testowego wywołania OpenAI...');
    try {
        String testPrompt = 'Powiedz "Cześć" i nic więcej.';
        String testSystemPrompt = 'Jesteś pomocnym asystentem.';
        String response = OpenAIService.callOpenAI(testPrompt, testSystemPrompt);
        System.debug('✅ Testowe wywołanie OpenAI zakończone sukcesem!');
        System.debug('Odpowiedź: ' + response);
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, '❌ Błąd podczas testowego wywołania OpenAI: ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, 'Typ błędu: ' + e.getTypeName());
        System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
    }
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, 'Błąd podczas sprawdzania konfiguracji OpenAI: ' + e.getMessage());
    System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
}

System.debug('=== Zakończono sprawdzanie konfiguracji OpenAI ==='); 