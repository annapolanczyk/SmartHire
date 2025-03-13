/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 03-13-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
// Skrypt do weryfikacji klucza API Google Vision
System.debug('=== Rozpoczynam weryfikację klucza API Google Vision ===');

// Pobierz ustawienia Google Vision API
Google_Vision_API_Settings__c settings = Google_Vision_API_Settings__c.getInstance();
if (settings == null || String.isBlank(settings.Vision_API_Key__c)) {
    System.debug(LoggingLevel.ERROR, 'Brak skonfigurowanego klucza API dla Google Vision');
    return;
}

System.debug('Klucz API Google Vision jest skonfigurowany: ' + settings.Vision_API_Key__c.substring(0, 5) + '...');

// Przygotuj zapytanie do Google Vision API
HttpRequest req = new HttpRequest();
String endpoint = 'https://vision.googleapis.com/v1/images:annotate?key=' + settings.Vision_API_Key__c;
req.setEndpoint(endpoint);
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setTimeout(30000);

// Przygotuj proste zapytanie testowe
Map<String, Object> requestBody = new Map<String, Object>{
    'requests' => new List<Object>{
        new Map<String, Object>{
            'image' => new Map<String, Object>{
                'content' => 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' // 1x1 pixel PNG
            },
            'features' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'TEXT_DETECTION',
                    'maxResults' => 1
                }
            }
        }
    }
};

req.setBody(JSON.serialize(requestBody));

System.debug('Wysyłam zapytanie testowe do Google Vision API...');

try {
    Http http = new Http();
    HttpResponse res = http.send(req);
    
    System.debug('Kod statusu odpowiedzi: ' + res.getStatusCode());
    
    if (res.getStatusCode() == 200) {
        System.debug('✅ Klucz API Google Vision działa poprawnie!');
        System.debug('Odpowiedź: ' + res.getBody().substring(0, Math.min(200, res.getBody().length())) + '...');
    } else if (res.getStatusCode() == 400) {
        System.debug(LoggingLevel.ERROR, '❌ Błąd w zapytaniu do Google Vision API: ' + res.getBody());
    } else if (res.getStatusCode() == 401 || res.getStatusCode() == 403) {
        System.debug(LoggingLevel.ERROR, '❌ Błąd autoryzacji Google Vision API. Klucz API jest nieprawidłowy: ' + res.getBody());
    } else {
        System.debug(LoggingLevel.ERROR, '❌ Błąd Google Vision API. Kod statusu: ' + res.getStatusCode() + ', Odpowiedź: ' + res.getBody());
    }
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, '❌ Wyjątek podczas wywołania Google Vision API: ' + e.getMessage());
    System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
}

System.debug('=== Zakończono weryfikację klucza API Google Vision ==='); 