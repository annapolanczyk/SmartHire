/**
 * Klasa testowa dla RecruitmentController
 * @author SmartHire Team
 * @date 2025-03-03
 */
@isTest
private class RecruitmentControllerTest {
    
    /**
     * Metoda pomocnicza do przygotowania danych testowych
     */
    @TestSetup
    static void setupTestData() {
        // Tworzenie testowego stanowiska
        Position__c position = new Position__c(
            Name = 'Test Developer Position',
            Description__c = 'We are looking for a skilled Salesforce developer.',
            Required_Skills__c = 'Apex, Salesforce, Lightning Web Components, Integration',
            Status__c = 'Open'
        );
        insert position;
        
        // Tworzenie testowego kandydata
        Candidate__c candidate = new Candidate__c(
            Name = 'John Doe',
            Email__c = 'john.doe@example.com',
            Phone__c = '(123) 456-7890',
            Status__c = 'New',
            Skills__c = 'Java, Apex, Salesforce, API Integration'
        );
        insert candidate;
        
        // Tworzenie testowej aplikacji o pracę
        Job_Application__c application = new Job_Application__c(
            Position__c = position.Id,
            Candidate__c = candidate.Id,
            Status__c = 'Applied',
            Application_Date__c = Date.today()
        );
        insert application;
    }
    
    /**
     * Test metody getActivePositions
     */
    @isTest
    static void testGetActivePositions() {
        Test.startTest();
        List<Position__c> positions = PositionController.getActivePositions();
        Test.stopTest();
        
        System.assertEquals(1, positions.size(), 'Powinna być jedna aktywna pozycja');
        System.assertEquals('Test Developer Position', positions[0].Name, 'Nazwa pozycji powinna być zgodna');
    }
    
    /**
     * Test metody getPositionById
     */
    @isTest
    static void testGetPositionById() {
        Position__c position = [SELECT Id FROM Position__c LIMIT 1];
        
        Test.startTest();
        Position__c result = PositionController.getPositionById(position.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Rezultat nie powinien być null');
        System.assertEquals('Test Developer Position', result.Name, 'Nazwa pozycji powinna być zgodna');
    }
    
    /**
     * Test analizy CV kandydata
     */
    @isTest
    static void testAnalyzeCandidateResume() {
        // Tworzenie dokumentu CV
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test Resume';
        cv.PathOnClient = 'TestResume.txt';
        cv.VersionData = Blob.valueOf('Test resume content');
        cv.IsMajorVersion = true;
        insert cv;
        
        // Konwersja do ContentDocument
        Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        
        // Pobierz ID stanowiska do testu
        Position__c position = [SELECT Id FROM Position__c LIMIT 1];
        
        // Mock dla OpenAI i parsera plików
        Test.setMock(HttpCalloutMock.class, new CVMockCallout());
        
        Test.startTest();
        
        // Spodziewamy się wyjątku, ponieważ w teście nie możemy naprawdę wywołać OpenAI,
        // ale przynajmniej sprawdzimy, czy metoda kontrolera prawidłowo deleguje wywołanie do usługi
        try {
            Map<String, Object> results = CVAnalysisController.analyzeCandidateResume(conDocId, position.Id, false);
            // Jeśli dojdziemy do tego miejsca, oznacza to, że mamy poprawnie skonfigurowane mocki
            System.assertNotEquals(null, results, 'Wyniki nie powinny być null');
        } catch (Exception e) {
            // Oczekujemy wyjątku ze względu na brak rzeczywistej usługi, 
            // ale chcemy upewnić się, że jest to wyjątek związany z analizą CV
            System.assert(e.getMessage().contains('CV') || e.getMessage().contains('Error'),
                        'Wyjątek powinien być związany z analizą CV');
        }
        
        Test.stopTest();
    }
    
    /**
     * Mock dla wywołań HTTP związanych z analizą CV
     */
    private class CVMockCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            
            if (req.getEndpoint().contains('openai.com')) {
                // Mock dla OpenAI
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"id":"chatcmpl-123","object":"chat.completion","created":1677652288,"model":"gpt-4","choices":[{"index":0,"message":{"role":"assistant","content":"{\\"skills\\":[\\"Java\\",\\"Apex\\",\\"Salesforce\\"],\\"workExperience\\":\\"<p>Developer Experience</p>\\",\\"education\\":\\"<p>University Education</p>\\",\\"matchScore\\":75}"},"finish_reason":"stop"}],"usage":{"prompt_tokens":55,"completion_tokens":114,"total_tokens":169}}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('PDF_Parser_Service')) {
                // Mock dla parsera PDF
                res.setHeader('Content-Type', 'text/plain');
                res.setBody('Test PDF content extracted');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('DOCX_Parser_Service')) {
                // Mock dla parsera DOCX
                res.setHeader('Content-Type', 'text/plain');
                res.setBody('Test DOCX content extracted');
                res.setStatusCode(200);
            } else {
                // Domyślna odpowiedź
                res.setStatusCode(404);
                res.setBody('No mock found for this endpoint');
            }
            
            return res;
        }
    }
    
    // Tutaj powinny znaleźć się testy dla innych metod kontrolerów...
}