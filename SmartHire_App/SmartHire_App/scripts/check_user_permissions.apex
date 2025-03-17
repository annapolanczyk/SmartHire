/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 03-13-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
// Skrypt do sprawdzenia uprawnień użytkownika do wykonywania wywołań API i dostępu do obiektów
System.debug('=== Rozpoczynam sprawdzanie uprawnień użytkownika ===');

// Pobierz informacje o bieżącym użytkowniku
Id currentUserId = UserInfo.getUserId();
User currentUser = [SELECT Id, Name, Profile.Name, IsActive FROM User WHERE Id = :currentUserId];
System.debug('Bieżący użytkownik: ' + currentUser.Name + ' (Profil: ' + currentUser.Profile.Name + ')');

// Sprawdź uprawnienia do wykonywania wywołań API
System.debug('Sprawdzanie uprawnień do wykonywania wywołań API...');

// 1. Sprawdź limity wywołań API
System.debug('Limit wywołań API: ' + Limits.getLimitCallouts() + ' / Wykorzystano: ' + Limits.getCallouts());

// 2. Sprawdź uprawnienia do obiektu Google_Vision_API_Settings__c
System.debug('Sprawdzanie uprawnień do obiektu Google_Vision_API_Settings__c...');
Schema.DescribeSObjectResult settingsDescribe = Google_Vision_API_Settings__c.SObjectType.getDescribe();
System.debug('Uprawnienia do Google_Vision_API_Settings__c:');
System.debug('- Dostęp do odczytu: ' + settingsDescribe.isAccessible());
System.debug('- Dostęp do tworzenia: ' + settingsDescribe.isCreateable());
System.debug('- Dostęp do aktualizacji: ' + settingsDescribe.isUpdateable());
System.debug('- Dostęp do usuwania: ' + settingsDescribe.isDeletable());

// 3. Sprawdź uprawnienia do pola Vision_API_Key__c
System.debug('Sprawdzanie uprawnień do pola Vision_API_Key__c...');
Schema.DescribeFieldResult apiKeyFieldDescribe = Google_Vision_API_Settings__c.Vision_API_Key__c.getDescribe();
System.debug('Uprawnienia do pola Vision_API_Key__c:');
System.debug('- Dostęp do odczytu: ' + apiKeyFieldDescribe.isAccessible());
System.debug('- Dostęp do aktualizacji: ' + apiKeyFieldDescribe.isUpdateable());

// 4. Sprawdź uprawnienia do obiektu ContentVersion
System.debug('Sprawdzanie uprawnień do obiektu ContentVersion...');
Schema.DescribeSObjectResult contentVersionDescribe = ContentVersion.SObjectType.getDescribe();
System.debug('Uprawnienia do ContentVersion:');
System.debug('- Dostęp do odczytu: ' + contentVersionDescribe.isAccessible());
System.debug('- Dostęp do tworzenia: ' + contentVersionDescribe.isCreateable());
System.debug('- Dostęp do aktualizacji: ' + contentVersionDescribe.isUpdateable());
System.debug('- Dostęp do usuwania: ' + contentVersionDescribe.isDeletable());

// 5. Sprawdź uprawnienia do pola VersionData w ContentVersion
System.debug('Sprawdzanie uprawnień do pola VersionData w ContentVersion...');
Schema.DescribeFieldResult versionDataFieldDescribe = ContentVersion.VersionData.getDescribe();
System.debug('Uprawnienia do pola VersionData:');
System.debug('- Dostęp do odczytu: ' + versionDataFieldDescribe.isAccessible());
System.debug('- Dostęp do aktualizacji: ' + versionDataFieldDescribe.isUpdateable());

// 6. Sprawdź Remote Site Settings
System.debug('Sprawdzanie Remote Site Settings...');
try {
    // Nie możemy bezpośrednio zapytać o Remote Site Settings przez SOQL, więc sprawdzamy, czy możemy wykonać wywołanie
    HttpRequest req = new HttpRequest();
    req.setEndpoint('https://vision.googleapis.com/v1/images:annotate?key=test');
    req.setMethod('GET');
    req.setTimeout(1000);
    
    Http http = new Http();
    try {
        HttpResponse res = http.send(req);
        System.debug('Test połączenia z Google Vision API: Kod statusu: ' + res.getStatusCode());
        System.debug('Remote Site Setting dla vision.googleapis.com jest skonfigurowany poprawnie.');
    } catch (System.CalloutException e) {
        if (e.getMessage().contains('Unauthorized endpoint')) {
            System.debug(LoggingLevel.ERROR, 'Remote Site Setting dla vision.googleapis.com NIE jest skonfigurowany poprawnie. Błąd: ' + e.getMessage());
        } else {
            System.debug('Remote Site Setting jest skonfigurowany, ale wystąpił inny błąd: ' + e.getMessage());
        }
    }
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, 'Błąd podczas sprawdzania Remote Site Settings: ' + e.getMessage());
}

// 7. Sprawdź uprawnienia do Cache Partition
System.debug('Sprawdzanie uprawnień do Cache Partition...');
try {
    Cache.OrgPartition cachePart = Cache.Org.getPartition('local.SmartHireCache');
    if (cachePart != null) {
        System.debug('Cache Partition "local.SmartHireCache" jest dostępny.');
        
        // Spróbuj zapisać i odczytać z cache
        String testKey = 'TEST' + String.valueOf(Datetime.now().getTime()).replaceAll('[^a-zA-Z0-9]', '');
        String testValue = 'TestValue' + String.valueOf(Datetime.now().getTime()).replaceAll('[^a-zA-Z0-9]', '');
        
        System.debug('Próba zapisu do cache z kluczem: ' + testKey);
        cachePart.put(testKey, testValue, 300); // TTL 5 minut
        
        System.debug('Próba odczytu z cache z kluczem: ' + testKey);
        String retrievedValue = (String)cachePart.get(testKey);
        
        if (retrievedValue == testValue) {
            System.debug('Test zapisu i odczytu z cache zakończony sukcesem.');
        } else {
            System.debug(LoggingLevel.WARN, 'Test zapisu i odczytu z cache NIE powiódł się. Odczytana wartość: ' + retrievedValue);
        }
    } else {
        System.debug(LoggingLevel.ERROR, 'Cache Partition "local.SmartHireCache" NIE jest dostępny.');
    }
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, 'Błąd podczas sprawdzania Cache Partition: ' + e.getMessage());
    System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
}

System.debug('=== Zakończono sprawdzanie uprawnień użytkownika ==='); 