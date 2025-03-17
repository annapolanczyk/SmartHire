/**
 * Prosty skrypt testowy do sprawdzenia dostępu do ContentVersion
 * @author SmartHire Team
 */
System.debug('=== Rozpoczynam prosty test dostępu do ContentVersion ===');

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
    
    // Sprawdź, czy mamy dostęp do ContentVersion z polem VersionData
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
    
    ContentVersion cv = versions[0];
    System.debug('Znaleziono wersję dokumentu CV: ' + cv.Title + ', rozmiar: ' + cv.ContentSize + ' bajtów');
    
    // Sprawdź, czy pole VersionData jest dostępne
    if (cv.VersionData != null) {
        System.debug('✅ Pole VersionData jest dostępne. Rozmiar: ' + cv.VersionData.size() + ' bajtów');
    } else {
        System.debug(LoggingLevel.ERROR, '❌ Pole VersionData jest null.');
    }
    
    // Sprawdź, czy mamy dostęp do partycji cache
    System.debug('Sprawdzam dostęp do partycji cache...');
    Cache.OrgPartition orgCache = Cache.Org.getPartition('SmartHireCache');
    
    if (orgCache != null) {
        System.debug('✅ Dostęp do partycji cache jest poprawny.');
        
        // Spróbuj zapisać i odczytać dane z cache
        String testKey = 'testKey' + Datetime.now().getTime();
        String testValue = 'Test value ' + Datetime.now().getTime();
        
        try {
            orgCache.put(testKey, testValue, 300);
            System.debug('✅ Zapis do cache udany.');
            
            Object retrievedValue = orgCache.get(testKey);
            if (retrievedValue != null && retrievedValue == testValue) {
                System.debug('✅ Odczyt z cache udany. Wartość: ' + retrievedValue);
            } else {
                System.debug(LoggingLevel.ERROR, '❌ Odczyt z cache nieudany lub wartość niezgodna.');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '❌ Błąd podczas operacji na cache: ' + e.getMessage());
        }
    } else {
        System.debug(LoggingLevel.ERROR, '❌ Nie można uzyskać dostępu do partycji cache.');
    }
    
    System.debug('Test zakończony pomyślnie!');
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, '❌ Błąd podczas testu: ' + e.getMessage());
    System.debug(LoggingLevel.ERROR, 'Typ błędu: ' + e.getTypeName());
    System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
}

System.debug('=== Zakończono prosty test dostępu do ContentVersion ==='); 