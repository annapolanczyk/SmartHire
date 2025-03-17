/**
 * Skrypt testowy dla JobApplicationObjectTrigger
 * @author SmartHire Team
 */
System.debug('=== Rozpoczynam test JobApplicationObjectTrigger ===');

try {
    // Znajdź przykładowego kandydata
    List<Candidate__c> candidates = [
        SELECT Id, Name
        FROM Candidate__c
        LIMIT 1
    ];
    
    if (candidates.isEmpty()) {
        System.debug(LoggingLevel.ERROR, 'Nie znaleziono kandydatów. Proszę dodać kandydata do organizacji.');
        return;
    }
    
    Id candidateId = candidates[0].Id;
    System.debug('Znaleziono kandydata: ' + candidates[0].Name + ' (ID: ' + candidateId + ')');
    
    // Znajdź przykładowe stanowisko
    List<Position__c> positions = [
        SELECT Id, Name
        FROM Position__c
        LIMIT 1
    ];
    
    if (positions.isEmpty()) {
        System.debug(LoggingLevel.ERROR, 'Nie znaleziono stanowisk. Proszę dodać stanowisko do organizacji.');
        return;
    }
    
    Id positionId = positions[0].Id;
    System.debug('Znaleziono stanowisko: ' + positions[0].Name + ' (ID: ' + positionId + ')');
    
    // Utwórz nową aplikację o pracę
    Job_Application__c app = new Job_Application__c(
        Candidate__c = candidateId,
        Position__c = positionId,
        Status__c = 'New',
        Application_Date__c = Date.today()
    );
    
    System.debug('Tworzę nową aplikację o pracę...');
    insert app;
    
    System.debug('✅ Aplikacja o pracę utworzona pomyślnie: ' + app.Id);
    
    // Pobierz utworzoną aplikację
    Job_Application__c createdApp = [
        SELECT Id, Name, Candidate__c, Position__c, Status__c, Application_Date__c
        FROM Job_Application__c
        WHERE Id = :app.Id
    ];
    
    System.debug('Szczegóły utworzonej aplikacji:');
    System.debug('- ID: ' + createdApp.Id);
    System.debug('- Nazwa: ' + createdApp.Name);
    System.debug('- Kandydat: ' + createdApp.Candidate__c);
    System.debug('- Stanowisko: ' + createdApp.Position__c);
    System.debug('- Status: ' + createdApp.Status__c);
    System.debug('- Data aplikacji: ' + createdApp.Application_Date__c);
    
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, '❌ Błąd podczas testu: ' + e.getMessage());
    System.debug(LoggingLevel.ERROR, 'Typ błędu: ' + e.getTypeName());
    System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
}

System.debug('=== Zakończono test JobApplicationObjectTrigger ==='); 