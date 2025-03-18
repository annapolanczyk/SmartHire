/**
 * Skrypt do sprawdzenia i aktualizacji przydziału pojemności dla partycji cache SmartHireCache
 * @author SmartHire Team
 */
System.debug('=== Rozpoczynam sprawdzanie i aktualizację przydziału pojemności Platform Cache ===');

// Nazwa partycji cache
final String CACHE_PARTITION_NAME = 'SmartHireCache';

try {
    // 1. Pobierz informacje o partycji cache
    System.debug('Pobieranie informacji o partycji ' + CACHE_PARTITION_NAME + '...');
    List<PlatformCachePartition> partitions = [
        SELECT Id, DeveloperName, IsDefaultPartition
        FROM PlatformCachePartition
        WHERE DeveloperName = :CACHE_PARTITION_NAME
        LIMIT 1
    ];
    
    if (partitions.isEmpty()) {
        System.debug(LoggingLevel.ERROR, '❌ Partycja ' + CACHE_PARTITION_NAME + ' nie istnieje w organizacji.');
        System.debug('Aby utworzyć partycję, przejdź do Setup > Platform Cache > New Platform Cache Partition.');
        return;
    }
    
    PlatformCachePartition partition = partitions[0];
    System.debug('✅ Znaleziono partycję: ' + partition.DeveloperName + ' (Id: ' + partition.Id + ')');
    
    // 2. Pobierz informacje o typach partycji i przydzielonej pojemności
    List<PlatformCachePartitionType> partitionTypes = [
        SELECT Id, PlatformCachePartitionId, CacheType, AllocatedCapacity
        FROM PlatformCachePartitionType
        WHERE PlatformCachePartitionId = :partition.Id
        ORDER BY CacheType
    ];
    
    if (partitionTypes.isEmpty()) {
        System.debug(LoggingLevel.ERROR, '❌ Nie znaleziono typów partycji dla ' + CACHE_PARTITION_NAME);
        return;
    }
    
    System.debug('Znaleziono ' + partitionTypes.size() + ' typów partycji:');
    
    // 3. Sprawdź przydzieloną pojemność dla każdego typu partycji
    Boolean needsAllocation = false;
    for (PlatformCachePartitionType partType : partitionTypes) {
        System.debug('- Typ: ' + partType.CacheType + ', Przydzielona pojemność: ' + partType.AllocatedCapacity + ' MB');
        
        if (partType.CacheType == 'Organization' && partType.AllocatedCapacity == 0) {
            System.debug(LoggingLevel.WARN, '⚠️ Partycja Organization nie ma przydzielonej pojemności!');
            needsAllocation = true;
        }
    }
    
    // 4. Sprawdź całkowitą dostępną pojemność cache
    System.debug('Sprawdzanie całkowitej dostępnej pojemności cache...');
    
    // 5. Wyświetl instrukcje dotyczące przydzielania pojemności
    if (needsAllocation) {
        System.debug(LoggingLevel.WARN, '⚠️ Partycja ' + CACHE_PARTITION_NAME + ' wymaga przydzielenia pojemności.');
        System.debug('Aby przydzielić pojemność, wykonaj następujące kroki:');
        System.debug('1. Przejdź do Setup > Platform Cache');
        System.debug('2. Kliknij "Edit" obok partycji ' + CACHE_PARTITION_NAME);
        System.debug('3. Przydziel co najmniej 5 MB dla typu Organization Cache');
        System.debug('4. Kliknij "Save"');
    } else {
        System.debug('✅ Partycja ' + CACHE_PARTITION_NAME + ' ma poprawnie przydzieloną pojemność.');
    }
    
    // 6. Sprawdź, czy partycja działa poprawnie
    System.debug('Testowanie działania partycji cache...');
    
    // Test partycji Organization
    Boolean orgCacheWorks = testCachePartition('Organization');
    
    // Test partycji Session
    Boolean sessionCacheWorks = testCachePartition('Session');
    
    // 7. Podsumowanie
    System.debug('=== Podsumowanie ===');
    System.debug('Partycja: ' + CACHE_PARTITION_NAME);
    System.debug('Organization Cache działa: ' + (orgCacheWorks ? '✅ Tak' : '❌ Nie'));
    System.debug('Session Cache działa: ' + (sessionCacheWorks ? '✅ Tak' : '❌ Nie'));
    
    if (!orgCacheWorks && !sessionCacheWorks) {
        System.debug(LoggingLevel.ERROR, '❌ Żaden typ partycji nie działa poprawnie. Sprawdź przydzieloną pojemność i uprawnienia.');
    } else if (!orgCacheWorks) {
        System.debug(LoggingLevel.WARN, '⚠️ Organization Cache nie działa. Aplikacja będzie używać Session Cache jako fallback.');
    } else if (!sessionCacheWorks) {
        System.debug(LoggingLevel.WARN, '⚠️ Session Cache nie działa. Aplikacja będzie używać tylko Organization Cache.');
    } else {
        System.debug('✅ Oba typy partycji działają poprawnie.');
    }
    
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, '❌ Błąd podczas sprawdzania partycji cache: ' + e.getMessage());
    System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
}

System.debug('=== Zakończono sprawdzanie i aktualizację przydziału pojemności Platform Cache ===');

/**
 * Testuje działanie partycji cache
 * @param cacheType Typ partycji (Organization lub Session)
 * @return True jeśli partycja działa poprawnie, False w przeciwnym razie
 */
private Boolean testCachePartition(String cacheType) {
    try {
        System.debug('Testowanie partycji ' + cacheType + '...');
        
        // Generuj unikalny klucz testowy
        String testKey = 'TEST' + String.valueOf(Datetime.now().getTime()).replaceAll('[^a-zA-Z0-9]', '');
        String testValue = 'TestValue' + String.valueOf(Datetime.now().getTime()).replaceAll('[^a-zA-Z0-9]', '');
        
        // Pobierz partycję
        if (cacheType == 'Organization') {
            Cache.OrgPartition cachePart = Cache.Org.getPartition(CACHE_PARTITION_NAME);
            if (cachePart == null) {
                System.debug(LoggingLevel.ERROR, '❌ Nie można uzyskać dostępu do partycji Organization.');
                return false;
            }
            
            // Zapisz dane do cache
            System.debug('Próba zapisu do Organization cache z kluczem: ' + testKey);
            cachePart.put(testKey, testValue, 300); // TTL 5 minut
            
            // Odczytaj dane z cache
            String retrievedValue = (String)cachePart.get(testKey);
            
            if (retrievedValue == null) {
                System.debug(LoggingLevel.ERROR, '❌ Odczyt z Organization cache nie powiódł się. Odczytana wartość jest NULL.');
                return false;
            } else if (retrievedValue.equals(testValue)) {
                System.debug('✅ Test zapisu i odczytu z Organization cache zakończony sukcesem.');
                return true;
            } else {
                System.debug(LoggingLevel.ERROR, '❌ Test zapisu i odczytu z Organization cache NIE powiódł się.');
                System.debug('Oczekiwana wartość: ' + testValue);
                System.debug('Odczytana wartość: ' + retrievedValue);
                return false;
            }
        } else if (cacheType == 'Session') {
            Cache.SessionPartition cachePart = Cache.Session.getPartition(CACHE_PARTITION_NAME);
            if (cachePart == null) {
                System.debug(LoggingLevel.ERROR, '❌ Nie można uzyskać dostępu do partycji Session.');
                return false;
            }
            
            // Zapisz dane do cache
            System.debug('Próba zapisu do Session cache z kluczem: ' + testKey);
            cachePart.put(testKey, testValue, 300); // TTL 5 minut
            
            // Odczytaj dane z cache
            String retrievedValue = (String)cachePart.get(testKey);
            
            if (retrievedValue == null) {
                System.debug(LoggingLevel.ERROR, '❌ Odczyt z Session cache nie powiódł się. Odczytana wartość jest NULL.');
                return false;
            } else if (retrievedValue.equals(testValue)) {
                System.debug('✅ Test zapisu i odczytu z Session cache zakończony sukcesem.');
                return true;
            } else {
                System.debug(LoggingLevel.ERROR, '❌ Test zapisu i odczytu z Session cache NIE powiódł się.');
                System.debug('Oczekiwana wartość: ' + testValue);
                System.debug('Odczytana wartość: ' + retrievedValue);
                return false;
            }
        }
        
        return false;
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, '❌ Błąd podczas testowania partycji ' + cacheType + ': ' + e.getMessage());
        return false;
    }
} 