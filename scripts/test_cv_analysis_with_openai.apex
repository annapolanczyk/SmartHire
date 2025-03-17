/**
 * Skrypt testowy do analizy CV z wykorzystaniem OpenAI
 * @author SmartHire Team
 */
System.debug('=== Rozpoczynam test analizy CV z wykorzystaniem OpenAI ===');

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
        SELECT Id, Name, Required_Skills__c
        FROM Position__c
        LIMIT 1
    ];
    
    Id positionId = positions.isEmpty() ? null : positions[0].Id;
    if (positionId != null) {
        System.debug('Znaleziono stanowisko: ' + positions[0].Name + ' (ID: ' + positionId + ')');
        if (String.isNotBlank(positions[0].Required_Skills__c)) {
            System.debug('Wymagane umiejętności: ' + positions[0].Required_Skills__c);
        } else {
            System.debug('Stanowisko nie ma zdefiniowanych wymaganych umiejętności.');
        }
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
        
        // Wyświetl szczegółowe informacje o umiejętnościach
        if (results.containsKey('Umiejętności techniczne')) {
            Object skills = results.get('Umiejętności techniczne');
            System.debug('Umiejętności techniczne (wartość): ' + skills);
            
            // Jeśli to lista, wyświetl każdy element
            if (skills instanceof List<Object>) {
                List<Object> skillsList = (List<Object>)skills;
                System.debug('Liczba umiejętności: ' + skillsList.size());
                for (Integer i = 0; i < skillsList.size(); i++) {
                    System.debug('Umiejętność ' + (i+1) + ': ' + skillsList[i]);
                }
            }
            // Jeśli to mapa, wyświetl każdy klucz i wartość
            else if (skills instanceof Map<String, Object>) {
                Map<String, Object> skillsMap = (Map<String, Object>)skills;
                System.debug('Liczba kluczy w mapie umiejętności: ' + skillsMap.size());
                for (String key : skillsMap.keySet()) {
                    System.debug('Klucz: ' + key + ', Wartość: ' + skillsMap.get(key));
                }
            }
            // Jeśli to string, sprawdź czy zawiera Apex i LWC
            else if (skills instanceof String) {
                String skillsStr = (String)skills;
                System.debug('Czy umiejętności zawierają "Apex": ' + skillsStr.containsIgnoreCase('Apex'));
                System.debug('Czy umiejętności zawierają "LWC": ' + skillsStr.containsIgnoreCase('LWC'));
            }
        }
        
        // Sprawdź również klucz "skills" (angielska wersja)
        if (results.containsKey('skills')) {
            Object skills = results.get('skills');
            System.debug('skills (wartość): ' + skills);
            
            // Jeśli to lista, wyświetl każdy element
            if (skills instanceof List<Object>) {
                List<Object> skillsList = (List<Object>)skills;
                System.debug('Liczba umiejętności: ' + skillsList.size());
                for (Integer i = 0; i < skillsList.size(); i++) {
                    System.debug('Umiejętność ' + (i+1) + ': ' + skillsList[i]);
                }
            }
        }
        
        // Wyświetl dopasowane umiejętności (matchedSkills)
        if (results.containsKey('matchedSkills')) {
            Object matchedSkills = results.get('matchedSkills');
            System.debug('Dopasowane umiejętności (wartość): ' + matchedSkills);
            
            // Jeśli to lista, wyświetl każdy element
            if (matchedSkills instanceof List<Object>) {
                List<Object> matchedSkillsList = (List<Object>)matchedSkills;
                System.debug('Liczba dopasowanych umiejętności: ' + matchedSkillsList.size());
                for (Integer i = 0; i < matchedSkillsList.size(); i++) {
                    System.debug('Dopasowana umiejętność ' + (i+1) + ': ' + matchedSkillsList[i]);
                }
            }
        }
        
        // Wyświetl brakujące umiejętności (missingSkills)
        if (results.containsKey('missingSkills')) {
            Object missingSkills = results.get('missingSkills');
            System.debug('Brakujące umiejętności (wartość): ' + missingSkills);
            
            // Jeśli to lista, wyświetl każdy element
            if (missingSkills instanceof List<Object>) {
                List<Object> missingSkillsList = (List<Object>)missingSkills;
                System.debug('Liczba brakujących umiejętności: ' + missingSkillsList.size());
                for (Integer i = 0; i < missingSkillsList.size(); i++) {
                    System.debug('Brakująca umiejętność ' + (i+1) + ': ' + missingSkillsList[i]);
                }
            }
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
        
        if (results.containsKey('recommendations')) {
            System.debug('Rekomendacje: ' + results.get('recommendations'));
        }
    } else {
        System.debug(LoggingLevel.ERROR, '❌ Analiza CV zwróciła null');
    }
} catch (Exception e) {
    System.debug(LoggingLevel.ERROR, '❌ Błąd podczas analizy CV: ' + e.getMessage());
    System.debug(LoggingLevel.ERROR, 'Typ błędu: ' + e.getTypeName());
    System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
}

System.debug('=== Zakończono test analizy CV z wykorzystaniem OpenAI ==='); 