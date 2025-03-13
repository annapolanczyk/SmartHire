/**
 * Skrypt testowy do sprawdzenia działania Platform Cache z różnymi formatami kluczy
 * @author SmartHire Team
 */
System.debug('=== Rozpoczynam test Platform Cache z różnymi formatami kluczy ===');

// Nazwa partycji cache
final String CACHE_PARTITION_NAME = 'SmartHireCache';

try {
    // 1. Pobierz partycję cache
    System.debug('Pobieranie partycji cache ' + CACHE_PARTITION_NAME + '...');
    Cache.OrgPartition orgCache = Cache.Org.getPartition(CACHE_PARTITION_NAME);
    
    if (orgCache == null) {
        System.debug(LoggingLevel.ERROR, '❌ Nie można uzyskać dostępu do partycji Organization cache.');
        return;
    }
    
    System.debug('✅ Uzyskano dostęp do partycji Organization cache.');
    
    // 2. Przygotuj różne formaty kluczy do testów
    Map<String, String> testKeys = new Map<String, String>{
        'key_with_underscore' => 'Klucz ze znakiem podkreślenia',
        'key-with-dash' => 'Klucz z myślnikiem',
        'keyWithSpecial@#$' => 'Klucz ze znakami specjalnymi',
        'normalKey123' => 'Klucz alfanumeryczny',
        'CV_069d200000047cZJAAY' => 'Klucz w formacie CV_ID'
    };
    
    // 3. Testuj zapis i odczyt dla każdego klucza
    for (String originalKey : testKeys.keySet()) {
        String testValue = testKeys.get(originalKey);
        
        System.debug('--------------------------------------------------');
        System.debug('Test dla klucza: "' + originalKey + '"');
        
        // Próba bezpośredniego zapisu z oryginalnym kluczem
        try {
            System.debug('Próba bezpośredniego zapisu z kluczem: ' + originalKey);
            orgCache.put(originalKey, testValue, 300);
            System.debug('✅ Zapis bezpośredni udany');
            
            // Próba odczytu
            Object retrievedValue = orgCache.get(originalKey);
            if (retrievedValue != null) {
                System.debug('✅ Odczyt bezpośredni udany: ' + retrievedValue);
            } else {
                System.debug(LoggingLevel.ERROR, '❌ Odczyt bezpośredni nieudany - wartość NULL');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '❌ Błąd podczas bezpośredniego zapisu/odczytu: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Typ błędu: ' + e.getTypeName());
        }
        
        // Sanityzacja klucza
        String sanitizedKey = originalKey.replaceAll('[^a-zA-Z0-9]', '');
        System.debug('Klucz po sanityzacji: "' + sanitizedKey + '"');
        
        // Próba zapisu z sanityzowanym kluczem
        try {
            System.debug('Próba zapisu z sanityzowanym kluczem: ' + sanitizedKey);
            orgCache.put(sanitizedKey, testValue, 300);
            System.debug('✅ Zapis z sanityzowanym kluczem udany');
            
            // Próba odczytu
            Object retrievedValue = orgCache.get(sanitizedKey);
            if (retrievedValue != null) {
                System.debug('✅ Odczyt z sanityzowanym kluczem udany: ' + retrievedValue);
            } else {
                System.debug(LoggingLevel.ERROR, '❌ Odczyt z sanityzowanym kluczem nieudany - wartość NULL');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '❌ Błąd podczas zapisu/odczytu z sanityzowanym kluczem: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Typ błędu: ' + e.getTypeName());
        }
    }
    
    // 4. Test z kluczem używanym w aplikacji
    String cvId = '069d200000047cZJAAY';
    String originalCacheKey = 'CV_' + cvId;
    String sanitizedCacheKey = 'CV' + cvId;
    String testValue = 'Test value for CV';
    
    System.debug('--------------------------------------------------');
    System.debug('Test dla klucza używanego w aplikacji');
    System.debug('Oryginalny klucz: ' + originalCacheKey);
    System.debug('Sanityzowany klucz: ' + sanitizedCacheKey);
    
    // Próba zapisu z oryginalnym kluczem
    try {
        System.debug('Próba zapisu z oryginalnym kluczem: ' + originalCacheKey);
        orgCache.put(originalCacheKey, testValue, 300);
        System.debug('✅ Zapis z oryginalnym kluczem udany');
        
        // Próba odczytu
        Object retrievedValue = orgCache.get(originalCacheKey);
        if (retrievedValue != null) {
            System.debug('✅ Odczyt z oryginalnym kluczem udany: ' + retrievedValue);
        } else {
            System.debug(LoggingLevel.ERROR, '❌ Odczyt z oryginalnym kluczem nieudany - wartość NULL');
        }
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, '❌ Błąd podczas zapisu/odczytu z oryginalnym kluczem: ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, 'Typ błędu: ' + e.getTypeName());
    }
    
    // Próba zapisu z sanityzowanym kluczem
    try {
        System.debug('Próba zapisu z sanityzowanym kluczem: ' + sanitizedCacheKey);
        orgCache.put(sanitizedCacheKey, testValue, 300);
        System.debug('✅ Zapis z sanityzowanym kluczem udany');
        
        // Próba odczytu
        Object retrievedValue = orgCache.get(sanitizedCacheKey);
        if (retrievedValue != null) {
            System.debug('✅ Odczyt z sanityzowanym kluczem udany: ' + retrievedValue);
        } else {
            System.debug(LoggingLevel.ERROR, '❌ Odczyt z sanityzowanym kluczem nieudany - wartość NULL');
        }
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, '❌ Błąd podczas zapisu/odczytu z sanityzowanym kluczem: ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, 'Typ błędu: ' + e.getTypeName());
    }
    
    // 5. Test odczytu z obu kluczy
    System.debug('--------------------------------------------------');
    System.debug('Test odczytu z obu kluczy po zapisie z sanityzowanym kluczem');
    
    // Zapisz wartość z sanityzowanym kluczem
    String uniqueValue = 'Unique value ' + Datetime.now().getTime();
    try {
        orgCache.put(sanitizedCacheKey, uniqueValue, 300);
        System.debug('✅ Zapis z sanityzowanym kluczem udany: ' + uniqueValue);
        
        // Próba odczytu z oryginalnego klucza
        Object retrievedWithOriginal = orgCache.get(originalCacheKey);
        System.debug('Odczyt z oryginalnym kluczem: ' + retrievedWithOriginal);
        
        // Próba odczytu z sanityzowanego klucza
        Object retrievedWithSanitized = orgCache.get(sanitizedCacheKey);
        System.debug('Odczyt z sanityzowanym kluczem: ' + retrievedWithSanitized);
        
        // Sprawdź, czy wartości są takie same
        if (retrievedWithOriginal == retrievedWithSanitized) {
            System.debug('✅ Wartości odczytane z obu kluczy są takie same');
        } else {
            System.debug(LoggingLevel.WARN, '⚠️ Wartości odczytane z obu kluczy są różne');
        }
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, '❌ Błąd podczas testu odczytu z obu kluczy: ' + e.getMessage());
    }
    
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, '❌ Błąd podczas testów: ' + e.getMessage());
    System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
}

System.debug('=== Zakończono test Platform Cache z różnymi formatami kluczy ==='); 