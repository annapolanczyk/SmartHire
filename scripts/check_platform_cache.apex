/**
 * Skrypt do sprawdzenia konfiguracji Platform Cache w organizacji Salesforce
 * @author SmartHire Team
 */
System.debug('=== Rozpoczynam sprawdzanie konfiguracji Platform Cache ===');

// 1. Sprawdź dostępne partycje cache
System.debug('Sprawdzanie dostępnych partycji cache...');
Map<String, Cache.OrgPartition> availableOrgPartitions = new Map<String, Cache.OrgPartition>();
Map<String, Cache.SessionPartition> availableSessionPartitions = new Map<String, Cache.SessionPartition>();

// Pobierz wszystkie dostępne partycje
try {
    // Próba bezpośredniego dostępu do partycji SmartHireCache
    System.debug('Próba dostępu do partycji local.SmartHireCache...');
    try {
        Cache.OrgPartition smartHireCache = Cache.Org.getPartition('local.SmartHireCache');
        if (smartHireCache != null) {
            System.debug('✅ Partycja local.SmartHireCache istnieje i jest dostępna.');
            availableOrgPartitions.put('local.SmartHireCache', smartHireCache);
        }
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, '❌ Błąd podczas dostępu do partycji local.SmartHireCache: ' + e.getMessage());
    }
    
    // Próba dostępu do domyślnej partycji
    System.debug('Próba dostępu do domyślnej partycji cache...');
    try {
        Cache.OrgPartition defaultCache = Cache.Org.getPartition('default');
        if (defaultCache != null) {
            System.debug('✅ Domyślna partycja cache istnieje i jest dostępna.');
            availableOrgPartitions.put('default', defaultCache);
        }
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, '❌ Błąd podczas dostępu do domyślnej partycji cache: ' + e.getMessage());
    }
    
    // Próba dostępu do partycji SmartHire
    System.debug('Próba dostępu do partycji SmartHire...');
    try {
        Cache.OrgPartition smartHirePartition = Cache.Org.getPartition('SmartHire');
        if (smartHirePartition != null) {
            System.debug('✅ Partycja SmartHire istnieje i jest dostępna.');
            availableOrgPartitions.put('SmartHire', smartHirePartition);
        }
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, '❌ Błąd podczas dostępu do partycji SmartHire: ' + e.getMessage());
    }
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, 'Błąd podczas pobierania partycji cache: ' + e.getMessage());
    System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
}

// 2. Sprawdź partycję SmartHireCache
System.debug('Sprawdzanie partycji SmartHireCache...');
try {
    // Sprawdź, czy partycja istnieje w organizacji
    Boolean smartHireCacheExists = false;
    String smartHireCachePartitionName = 'local.SmartHireCache';
    
    if (availableOrgPartitions.containsKey(smartHireCachePartitionName)) {
        System.debug('Partycja ' + smartHireCachePartitionName + ' istnieje w organizacji.');
        smartHireCacheExists = true;
        
        // Spróbuj zapisać i odczytać z cache
        Cache.OrgPartition cachePart = availableOrgPartitions.get(smartHireCachePartitionName);
        
        // Generuj unikalny klucz alfanumeryczny
        String testKey = 'TEST' + String.valueOf(Datetime.now().getTime()).replaceAll('[^a-zA-Z0-9]', '');
        String testValue = 'TestValue' + String.valueOf(Datetime.now().getTime()).replaceAll('[^a-zA-Z0-9]', '');
        
        System.debug('Próba zapisu do cache z kluczem: ' + testKey);
        cachePart.put(testKey, testValue, 300); // TTL 5 minut
        
        System.debug('Próba odczytu z cache z kluczem: ' + testKey);
        String retrievedValue = (String)cachePart.get(testKey);
        
        if (retrievedValue == testValue) {
            System.debug('✅ Test zapisu i odczytu z cache zakończony sukcesem.');
        } else {
            System.debug(LoggingLevel.WARN, '❌ Test zapisu i odczytu z cache NIE powiódł się. Odczytana wartość: ' + retrievedValue);
            System.debug('Sprawdzanie, czy partycja ma przydzieloną pojemność...');
        }
    } else {
        System.debug(LoggingLevel.WARN, '❌ Partycja ' + smartHireCachePartitionName + ' NIE istnieje w organizacji.');
        
        // Sprawdź, czy istnieje inna partycja, którą można wykorzystać
        if (!availableOrgPartitions.isEmpty()) {
            System.debug('Dostępne partycje, które można wykorzystać:');
            for (String partitionName : availableOrgPartitions.keySet()) {
                System.debug('- ' + partitionName);
            }
            
            // Spróbuj użyć pierwszej dostępnej partycji
            String firstPartitionName = new List<String>(availableOrgPartitions.keySet())[0];
            System.debug('Próba użycia partycji ' + firstPartitionName + ' jako alternatywy...');
            
            Cache.OrgPartition cachePart = availableOrgPartitions.get(firstPartitionName);
            
            // Generuj unikalny klucz alfanumeryczny
            String testKey = 'TEST' + String.valueOf(Datetime.now().getTime()).replaceAll('[^a-zA-Z0-9]', '');
            String testValue = 'TestValue' + String.valueOf(Datetime.now().getTime()).replaceAll('[^a-zA-Z0-9]', '');
            
            System.debug('Próba zapisu do cache z kluczem: ' + testKey);
            cachePart.put(testKey, testValue, 300); // TTL 5 minut
            
            System.debug('Próba odczytu z cache z kluczem: ' + testKey);
            String retrievedValue = (String)cachePart.get(testKey);
            
            if (retrievedValue == testValue) {
                System.debug('✅ Test zapisu i odczytu z alternatywnej partycji zakończony sukcesem.');
                System.debug('Zalecana zmiana nazwy partycji w kodzie z "local.SmartHireCache" na "' + firstPartitionName + '".');
            } else {
                System.debug(LoggingLevel.WARN, '❌ Test zapisu i odczytu z alternatywnej partycji NIE powiódł się. Odczytana wartość: ' + retrievedValue);
            }
        } else {
            System.debug(LoggingLevel.ERROR, '❌ Nie znaleziono żadnych dostępnych partycji cache w organizacji.');
        }
    }
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, 'Błąd podczas sprawdzania partycji SmartHireCache: ' + e.getMessage());
    System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
}

// 3. Sprawdź limity Platform Cache
System.debug('Sprawdzanie limitów Platform Cache...');
try {
    // Sprawdź limity wywołań API
    System.debug('Limity wywołań API:');
    System.debug('- Limit wywołań API: ' + Limits.getLimitCallouts());
    System.debug('- Wykorzystano wywołań API: ' + Limits.getCallouts());
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, 'Błąd podczas sprawdzania limitów Platform Cache: ' + e.getMessage());
}

// 4. Sugestie dotyczące konfiguracji Platform Cache
System.debug('Sugestie dotyczące konfiguracji Platform Cache:');
if (availableOrgPartitions.isEmpty()) {
    System.debug('1. Platform Cache nie jest skonfigurowany w tej organizacji. Należy zakupić i przydzielić pojemność cache.');
    System.debug('   Przejdź do Setup > Platform Cache > Manage Platform Cache, aby zakupić i przydzielić pojemność cache.');
} else if (!availableOrgPartitions.containsKey('local.SmartHireCache')) {
    System.debug('1. Partycja "local.SmartHireCache" nie istnieje. Należy ją utworzyć i przydzielić jej pojemność.');
    System.debug('   Przejdź do Setup > Platform Cache > Manage Platform Cache, aby utworzyć partycję "local.SmartHireCache".');
    
    if (!availableOrgPartitions.isEmpty()) {
        String firstPartitionName = new List<String>(availableOrgPartitions.keySet())[0];
        System.debug('   Alternatywnie, można zmienić nazwę partycji w kodzie z "local.SmartHireCache" na "' + firstPartitionName + '".');
    }
} else {
    System.debug('1. Partycja "local.SmartHireCache" istnieje, ale mogą wystąpić problemy z jej konfiguracją.');
    System.debug('   Sprawdź, czy partycja ma przydzieloną wystarczającą pojemność w Setup > Platform Cache > Manage Platform Cache.');
}

System.debug('2. Upewnij się, że profil użytkownika ma uprawnienie "Platform Cache" włączone.');
System.debug('   Przejdź do Setup > Users > Profiles > [Profil użytkownika] > System Permissions, aby sprawdzić uprawnienie "Platform Cache".');

System.debug('3. Sprawdź, czy klasa CVAnalysisService używa poprawnej nazwy partycji cache.');
System.debug('   Aktualna nazwa partycji w kodzie to "local.SmartHireCache". Upewnij się, że taka partycja istnieje w organizacji.');

System.debug('=== Zakończono sprawdzanie konfiguracji Platform Cache ===');