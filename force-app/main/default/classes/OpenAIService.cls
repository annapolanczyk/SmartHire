/**
 * Klasa do integracji z OpenAI API z użyciem Named Credential i Custom Setting.
 */
public with sharing class OpenAIService {
    // DeveloperName Named Credential (z Setup)
    private static final String NAMED_CREDENTIAL = 'AI_CV_Analysis_API';
    // Ścieżka do endpointu OpenAI
    private static final String ENDPOINT_PATH = '/v1/chat/completions';
    // Maksymalna liczba tokenów w zapytaniu
    private static final Integer MAX_TOKENS = 4000;
    
    /**
     * Wysyła zapytanie do OpenAI (model GPT) i zwraca odpowiedź w postaci String.
     * @param prompt - Treść pytania od użytkownika
     * @param systemPrompt - Dodatkowy kontekst (roli systemu)
     * @return Odpowiedź modelu OpenAI
     */
    public static String callOpenAI(String prompt, String systemPrompt) {
        try {
            // Sprawdź uprawnienia
            validateOpenAISettingsAccess();
            
            // 1. Pobranie klucza API z Custom Setting (Hierarchy)
            OpenAI_Settings__c setting = OpenAI_Settings__c.getInstance();
            if (setting == null || String.isBlank(setting.API_Key__c)) {
                throw new OpenAIException('Brak skonfigurowanego klucza API w OpenAI_Settings__c (pole API_Key__c).');
            }
            
            // 2. Przygotowanie ciała zapytania (zgodnie z dokumentacją OpenAI)
            Map<String, Object> requestBody = new Map<String, Object>{
                'model' => 'gpt-3.5-turbo', // lub gpt-4, jeśli masz dostęp
                'messages' => new List<Object>{
                    new Map<String, String>{
                        'role' => 'system',
                        'content' => systemPrompt
                    },
                    new Map<String, String>{
                        'role' => 'user',
                        'content' => prompt
                    }
                },
                'max_tokens' => MAX_TOKENS,
                'temperature' => 0.5
            };
            
            // 3. Tworzymy obiekt HttpRequest
            HttpRequest req = new HttpRequest();
            // Używamy Named Credential + ścieżkę endpointu
            req.setEndpoint('callout:' + NAMED_CREDENTIAL + ENDPOINT_PATH);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            // Dokładamy nagłówek Authorization z kluczem pobranym z Custom Setting
            req.setHeader('Authorization', 'Bearer ' + setting.API_Key__c);
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(120000); // 2 minuty (120s) na callout
            
            // 4. (Opcjonalnie) sprawdzenie limitów callout
            checkGovernorLimits('CALLOUT');
            
            // 5. Wysyłamy zapytanie
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // 6. Obsługa odpowiedzi
            if (res.getStatusCode() == 200) {
                // Parsujemy JSON
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> choices = (List<Object>) responseMap.get('choices');
                if (choices != null && !choices.isEmpty()) {
                    Map<String, Object> choice = (Map<String, Object>) choices[0];
                    Map<String, Object> message = (Map<String, Object>) choice.get('message');
                    if (message != null) {
                        return (String) message.get('content');
                    }
                }
                throw new OpenAIException('Nieprawidłowa struktura odpowiedzi z OpenAI (brak "message.content").');
            } else {
                // Logowanie błędu
                System.debug(LoggingLevel.ERROR, 
                    'OpenAIService.callOpenAI: Błąd OpenAI API: ' + 
                    res.getStatusCode() + ' - ' + res.getBody()
                );
                // Obsługa typowych kodów błędów
                if (res.getStatusCode() == 429) {
                    throw new OpenAIException('Przekroczono limit zapytań do OpenAI. Spróbuj ponownie później.');
                } else if (res.getStatusCode() == 401) {
                    throw new OpenAIException('Nieprawidłowy lub wygasły klucz API OpenAI.');
                } else {
                    throw new OpenAIException('Błąd podczas wywoływania OpenAI API: ' + res.getStatusCode());
                }
            }
        } catch (System.CalloutException e) {
            System.debug(LoggingLevel.ERROR, 
                'OpenAIService.callOpenAI: Wyjątek podczas wywoływania OpenAI API: ' + e.getMessage()
            );
            throw new OpenAIException('Nie można połączyć się z OpenAI API: ' + e.getMessage());
        }
    }
    
    /**
     * (Opcjonalne) Sprawdzenie limitów wywołań zewnętrznych (calloutów)
     */
    private static void checkGovernorLimits(String operationType) {
        if (operationType == 'CALLOUT') {
            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                throw new OpenAIException('Osiągnięto maksymalny limit calloutów. Spróbuj ponownie później.');
            }
        }
    }
    
    /**
     * Sprawdza uprawnienia dostępu do ustawień OpenAI
     */
    private static void validateOpenAISettingsAccess() {
        try {
            SecurityUtils.checkReadAccess(OpenAI_Settings__c.SObjectType, 
                new List<String>{'API_Key__c'});
        } catch (SecurityUtils.SecurityException e) {
            throw new SecurityException('Insufficient permissions to access OpenAI settings: ' + e.getMessage());
        }
    }
    
    /**
     * Niestandardowy wyjątek dla błędów OpenAI
     */
    public class OpenAIException extends Exception {}
}