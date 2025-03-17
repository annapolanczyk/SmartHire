/**
 * Skrypt testowy do sprawdzenia działania Platform Cache
 * @author SmartHire Team
 */
System.debug('=== Test zapisu i odczytu z Platform Cache ===');

// Nazwa partycji cache
final String CACHE_PARTITION_NAME = 'SmartHireCache';
final Integer CACHE_TTL = 300; // 5 minut

try {
    // Pobierz partycję cache
    System.debug('Próba dostępu do partycji ' + CACHE_PARTITION_NAME + '...');
    Cache.OrgPartition cachePart = Cache.Org.getPartition(CACHE_PARTITION_NAME);
    
    if (cachePart == null) {
        System.debug(LoggingLevel.ERROR, '❌ Partycja ' + CACHE_PARTITION_NAME + ' nie istnieje lub jest niedostępna.');
        return;
    }
    
    System.debug('✅ Partycja ' + CACHE_PARTITION_NAME + ' istnieje i jest dostępna.');
    
    // Generuj unikalny klucz testowy (bez znaków podkreślenia)
    String testKey = 'TEST' + String.valueOf(Datetime.now().getTime()).replaceAll('[^a-zA-Z0-9]', '');
    String testValue = 'TestValue' + String.valueOf(Datetime.now().getTime()).replaceAll('[^a-zA-Z0-9]', '');
    
    // Zapisz dane do cache
    System.debug('Próba zapisu do cache z kluczem: ' + testKey);
    System.debug('Wartość do zapisania: ' + testValue);
    cachePart.put(testKey, testValue, CACHE_TTL);
    
    // Odczytaj dane z cache
    System.debug('Próba odczytu z cache z kluczem: ' + testKey);
    String retrievedValue = (String)cachePart.get(testKey);
    
    if (retrievedValue == null) {
        System.debug(LoggingLevel.ERROR, '❌ Odczyt z cache nie powiódł się. Odczytana wartość jest NULL.');
    } else if (retrievedValue.equals(testValue)) {
        System.debug('✅ Test zapisu i odczytu z cache zakończony sukcesem.');
        System.debug('Odczytana wartość: ' + retrievedValue);
    } else {
        System.debug(LoggingLevel.ERROR, '❌ Test zapisu i odczytu z cache NIE powiódł się.');
        System.debug('Oczekiwana wartość: ' + testValue);
        System.debug('Odczytana wartość: ' + retrievedValue);
    }
    
    // Sprawdź, czy możemy zapisać i odczytać obiekt Map
    System.debug('Test zapisu i odczytu obiektu Map...');
    String mapKey = 'MAP' + String.valueOf(Datetime.now().getTime()).replaceAll('[^a-zA-Z0-9]', '');
    Map<String, Object> testMap = new Map<String, Object>{
        'name' => 'Test User',
        'email' => 'test@example.com',
        'score' => 95.5,
        'isActive' => true,
        'timestamp' => Datetime.now()
    };
    
    System.debug('Próba zapisu obiektu Map do cache z kluczem: ' + mapKey);
    cachePart.put(mapKey, testMap, CACHE_TTL);
    
    System.debug('Próba odczytu obiektu Map z cache z kluczem: ' + mapKey);
    Map<String, Object> retrievedMap = (Map<String, Object>)cachePart.get(mapKey);
    
    if (retrievedMap == null) {
        System.debug(LoggingLevel.ERROR, '❌ Odczyt obiektu Map z cache nie powiódł się. Odczytana wartość jest NULL.');
    } else {
        System.debug('✅ Test zapisu i odczytu obiektu Map z cache zakończony sukcesem.');
        System.debug('Odczytany obiekt Map: ' + retrievedMap);
    }
    
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, '❌ Błąd podczas testowania Platform Cache: ' + e.getMessage());
    System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
}

System.debug('=== Zakończono test Platform Cache ==='); 