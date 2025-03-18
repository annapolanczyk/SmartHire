/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 03-17-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
// Skrypt do sprawdzenia pól obiektu AiAnalysisResult__c
try {
    // Sprawdź, czy obiekt istnieje
    System.debug('Sprawdzanie, czy obiekt AiAnalysisResult__c istnieje...');
    Schema.SObjectType aiAnalysisType = Schema.getGlobalDescribe().get('AiAnalysisResult__c');
    
    if (aiAnalysisType == null) {
        System.debug('Obiekt AiAnalysisResult__c nie istnieje w organizacji!');
        return;
    }
    
    System.debug('Obiekt AiAnalysisResult__c istnieje. Sprawdzanie dostępnych pól...');
    
    // Pobierz mapę pól
    Map<String, Schema.SObjectField> fieldMap = aiAnalysisType.getDescribe().fields.getMap();
    
    // Wyświetl dostępne pola
    System.debug('Dostępne pola dla obiektu AiAnalysisResult__c:');
    for (String fieldName : fieldMap.keySet()) {
        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
        System.debug('Pole: ' + fieldName + ', Label: ' + fieldDescribe.getLabel() + ', Typ: ' + fieldDescribe.getType());
    }
    
    // Spróbuj utworzyć testowy rekord
    System.debug('Próba utworzenia testowego rekordu...');
    AiAnalysisResult__c testRecord = new AiAnalysisResult__c();
    
    // Wstaw rekord
    insert testRecord;
    
    System.debug('Utworzono testowy rekord AiAnalysisResult__c z ID: ' + testRecord.Id);
} catch (Exception e) {
    System.debug('Wystąpił błąd: ' + e.getMessage());
    System.debug('Typ błędu: ' + e.getTypeName());
    System.debug('Stack trace: ' + e.getStackTraceString());
} 