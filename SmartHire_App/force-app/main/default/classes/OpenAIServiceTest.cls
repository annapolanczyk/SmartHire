/**
 * Klasa testowa dla OpenAIService
 * @author SmartHire Team
 * @date 2025-03-03
 */
@isTest
private class OpenAIServiceTest {
    
    // Przykładowa odpowiedź z OpenAI
    private static final String MOCK_RESPONSE = '{"id":"chatcmpl-123","object":"chat.completion","created":1677652288,"model":"gpt-4","choices":[{"index":0,"message":{"role":"assistant","content":"{\\"skills\\":[\\"Java\\",\\"Apex\\",\\"Salesforce\\",\\"API Integration\\"],\\"workExperience\\":\\"<p>Senior Developer at Acme Corp (2018-2023)</p>\\",\\"education\\":\\"<p>Computer Science, Stanford University (2014-2018)</p>\\",\\"languages\\":[\\"English\\",\\"Spanish\\"],\\"certifications\\":[\\"Salesforce Certified Developer\\"],\\"matchScore\\":85,\\"skillsMatchScore\\":90,\\"experienceMatchScore\\":80,\\"recommendations\\":\\"<p>Strong technical profile with relevant experience.</p>\\"}"},"finish_reason":"stop"}],"usage":{"prompt_tokens":55,"completion_tokens":114,"total_tokens":169}}';
    
    /**
     * Test konfiguracji niestandardowych ustawień
     */
    @isTest
    static void testCustomSettings() {
        // Przygotowanie danych testowych
        OpenAI_Settings__c settings = new OpenAI_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            API_Key__c = 'test-api-key-12345',
            Model__c = 'gpt-4'
        );
        insert settings;
        
        // Test metod prywatnych przez refleksję
        Test.startTest();
        
        // Wywołaj metodę prywatną getOpenAIApiKey() za pomocą refleksji
        Type openAIServiceType = Type.forName('OpenAIService');
        Object openAIServiceInstance = openAIServiceType.newInstance();
        
        // Możemy użyć publicznej metody, która wewnętrznie wywołuje prywatną getOpenAIApiKey
        Test.setMock(HttpCalloutMock.class, new OpenAIMockCallout());
        
        try {
            // Próba wywołania callOpenAI dla sprawdzenia, czy klucz API jest pobierany
            OpenAIService.callOpenAI('Test prompt', 'Test system prompt');
        } catch (Exception e) {
            // Oczekujemy pomyślnego pobrania klucza API, więc jeśli wystąpi wyjątek,
            // powinien być to wyjątek związany z wywołaniem HTTP, a nie z brakiem klucza API
            System.assert(!(e.getMessage().contains('Brak skonfigurowanego klucza API OpenAI')), 
                         'Powinien znaleźć klucz API z niestandardowych ustawień');
        }
        
        Test.stopTest();
    }
    
    /**
     * Test wywołania API OpenAI
     */
    @isTest
    static void testCallOpenAI() {
        // Przygotowanie danych testowych
        OpenAI_Settings__c settings = new OpenAI_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            API_Key__c = 'test-api-key-12345',
            Model__c = 'gpt-4'
        );
        insert settings;
        
        // Konfiguracja mock callout
        Test.setMock(HttpCalloutMock.class, new OpenAIMockCallout());
        
        Test.startTest();
        
        // Wywołanie metody do testowania
        String response = OpenAIService.callOpenAI('Test prompt', 'Test system prompt');
        
        Test.stopTest();
        
        // Asercje
        System.assertNotEquals(null, response, 'Odpowiedź nie powinna być null');
        System.assert(response.contains('skills'), 'Odpowiedź powinna zawierać dane o umiejętnościach');
        System.assert(response.contains('matchScore'), 'Odpowiedź powinna zawierać ocenę dopasowania');
    }
    
    /**
     * Test reakcji na błędy API
     */
    @isTest
    static void testErrorHandling() {
        // Przygotowanie danych testowych
        OpenAI_Settings__c settings = new OpenAI_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            API_Key__c = 'test-api-key-12345',
            Model__c = 'gpt-4'
        );
        insert settings;
        
        // Konfiguracja mock callout dla błędu 401
        Test.setMock(HttpCalloutMock.class, new OpenAIErrorMockCallout(401));
        
        Test.startTest();
        
        // Sprawdź, czy metoda zgłasza odpowiedni wyjątek
        try {
            OpenAIService.callOpenAI('Test prompt', 'Test system prompt');
            System.assert(false, 'Powinien zgłosić wyjątek dla błędu 401');
        } catch (OpenAIService.OpenAIException e) {
            System.assert(e.getMessage().contains('Nieprawidłowy klucz API'), 
                         'Komunikat błędu powinien zawierać informację o nieprawidłowym kluczu API');
        }
        
        // Test dla błędu 429
        Test.setMock(HttpCalloutMock.class, new OpenAIErrorMockCallout(429));
        
        try {
            OpenAIService.callOpenAI('Test prompt', 'Test system prompt');
            System.assert(false, 'Powinien zgłosić wyjątek dla błędu 429');
        } catch (OpenAIService.OpenAIException e) {
            System.assert(e.getMessage().contains('Przekroczono limit zapytań'), 
                         'Komunikat błędu powinien zawierać informację o przekroczonym limicie');
        }
        
        Test.stopTest();
    }
    
    /**
     * Klasa Mock dla pomyślnych odpowiedzi OpenAI
     */
    private class OpenAIMockCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(MOCK_RESPONSE);
            res.setStatusCode(200);
            return res;
        }
    }
    
    /**
     * Klasa Mock dla błędów OpenAI
     */
    private class OpenAIErrorMockCallout implements HttpCalloutMock {
        private Integer statusCode;
        
        public OpenAIErrorMockCallout(Integer statusCode) {
            this.statusCode = statusCode;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (statusCode == 401) {
                res.setBody('{"error":{"message":"Incorrect API key provided","type":"invalid_request_error","param":null,"code":"invalid_api_key"}}');
            } else if (statusCode == 429) {
                res.setBody('{"error":{"message":"Rate limit reached for requests","type":"requests","param":null,"code":null}}');
            } else {
                res.setBody('{"error":{"message":"Something went wrong","type":"server_error","param":null,"code":null}}');
            }
            
            res.setStatusCode(statusCode);
            return res;
        }
    }
}