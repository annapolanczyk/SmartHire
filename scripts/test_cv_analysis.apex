/**
 * Skrypt testowy do analizy CV
 * @author SmartHire Team
 */
System.debug('=== Rozpoczynam test analizy CV ===');

try {
    // Znajdź przykładowy dokument CV
    List<ContentDocument> documents = [
        SELECT Id, Title, FileType
        FROM ContentDocument
        WHERE Title LIKE '%CV%' OR Title LIKE '%Resume%'
        ORDER BY LastModifiedDate DESC
        LIMIT 1
    ];
    
    if (documents.isEmpty()) {
        System.debug(LoggingLevel.ERROR, 'Nie znaleziono dokumentów CV. Proszę dodać dokument CV do organizacji.');
        return;
    }
    
    Id contentDocumentId = documents[0].Id;
    System.debug('Znaleziono dokument CV: ' + documents[0].Title + ' (ID: ' + contentDocumentId + ')');
    
    // Znajdź przykładowe stanowisko
    List<Position__c> positions = [
        SELECT Id, Name
        FROM Position__c
        LIMIT 1
    ];
    
    Id positionId = positions.isEmpty() ? null : positions[0].Id;
    if (positionId != null) {
        System.debug('Znaleziono stanowisko: ' + positions[0].Name + ' (ID: ' + positionId + ')');
    } else {
        System.debug('Nie znaleziono stanowisk. Test będzie przeprowadzony bez dopasowania do stanowiska.');
    }
    
    // Sprawdź, czy mamy dostęp do ContentVersion
    List<ContentVersion> versions = [
        SELECT Id, Title, FileType, ContentSize, VersionData
        FROM ContentVersion
        WHERE ContentDocumentId = :contentDocumentId
        AND IsLatest = true
        LIMIT 1
    ];
    
    if (versions.isEmpty()) {
        System.debug(LoggingLevel.ERROR, 'Nie znaleziono wersji dokumentu CV.');
        return;
    }
    
    System.debug('Znaleziono wersję dokumentu CV: ' + versions[0].Title + ', rozmiar: ' + versions[0].ContentSize + ' bajtów');
    
    // Wykonaj analizę CV bezpośrednio na ContentVersion
    System.debug('Rozpoczynam analizę CV używając CVAnalysisHelper...');
    Map<String, Object> results = CVAnalysisHelper.analyzeResume(versions[0], positionId);
    
    // Wyświetl wyniki
    if (results != null) {
        System.debug('✅ Analiza CV zakończona sukcesem!');
        System.debug('Liczba kluczy w wynikach: ' + results.size());
        System.debug('Klucze w wynikach: ' + results.keySet());
        
        // Wyświetl przykładowe dane z wyników
        if (results.containsKey('skills')) {
            System.debug('Umiejętności: ' + results.get('skills'));
        }
        
        if (results.containsKey('education')) {
            System.debug('Wykształcenie: ' + results.get('education'));
        }
        
        if (results.containsKey('experience')) {
            System.debug('Doświadczenie: ' + results.get('experience'));
        }
        
        if (results.containsKey('matchScore')) {
            System.debug('Wynik dopasowania: ' + results.get('matchScore'));
        }
    } else {
        System.debug(LoggingLevel.ERROR, '❌ Analiza CV zwróciła null');
    }
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, '❌ Błąd podczas analizy CV: ' + e.getMessage());
    System.debug(LoggingLevel.ERROR, 'Typ błędu: ' + e.getTypeName());
    System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
}

System.debug('=== Zakończono test analizy CV ==='); 