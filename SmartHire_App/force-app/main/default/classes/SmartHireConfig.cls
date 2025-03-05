/**
 * Singleton dla zarządzania konfiguracją aplikacji SmartHire
 * @author SmartHire Team
 * @date 2025-03-04
 */
public class SmartHireConfig {
    
    // Instancja singletona
    private static SmartHireConfig instance;
    
    // Cache konfiguracji
    private Map<String, Object> configCache;
    
    // Prywatny konstruktor uniemożliwiający bezpośrednie tworzenie instancji
    private SmartHireConfig() {
        loadConfiguration();
    }
    
    /**
     * Pobiera instancję konfiguratora
     * @return Instancja singletona SmartHireConfig
     */
    public static SmartHireConfig getInstance() {
        if (instance == null) {
            instance = new SmartHireConfig();
        }
        return instance;
    }
    
    /**
     * Pobiera wartość konfiguracyjną dla danego klucza
     * @param key Klucz konfiguracji
     * @return Wartość konfiguracji
     */
    public Object getConfigValue(String key) {
        return configCache.get(key);
    }
    
    /**
     * Pobiera wartość konfiguracyjną dla danego klucza z domyślną wartością w przypadku braku
     * @param key Klucz konfiguracji
     * @param defaultValue Domyślna wartość
     * @return Wartość konfiguracji lub wartość domyślna
     */
    public Object getConfigValue(String key, Object defaultValue) {
        return configCache.containsKey(key) ? configCache.get(key) : defaultValue;
    }
    
    /**
     * Pobiera typ analizatora CV do użycia
     * @return Typ analizatora CV
     */
    public CVAnalysisFactory.AnalyzerType getCVAnalyzerType() {
        String analyzerType = (String)getConfigValue('CVAnalyzerType', 'OPENAI');
        return CVAnalysisFactory.AnalyzerType.valueOf(analyzerType);
    }
    
    /**
     * Sprawdza, czy buforowanie analizy CV jest włączone
     * @return True, jeśli buforowanie jest włączone
     */
    public Boolean isCVAnalysisCachingEnabled() {
        return (Boolean)getConfigValue('CVAnalysisCachingEnabled', true);
    }
    
    /**
     * Pobiera czas wygaśnięcia buforowania analizy CV w sekundach
     * @return Czas wygaśnięcia w sekundach
     */
    public Integer getCVAnalysisCacheExpirationSeconds() {
        return (Integer)getConfigValue('CVAnalysisCacheExpirationSeconds', 86400); // 24 godziny
    }
    
    /**
     * Ładuje konfigurację z niestandardowych metadanych
     */
    private void loadConfiguration() {
        configCache = new Map<String, Object>();
        
        // Pobierz ustawienia z Custom Metadata Type
        List<SmartHire_Setting__mdt> settings = [
            SELECT DeveloperName, Value__c, Type__c
            FROM SmartHire_Setting__mdt
            WHERE IsActive__c = true
        ];
        
        for (SmartHire_Setting__mdt setting : settings) {
            // Konwertuj wartość na odpowiedni typ
            Object typedValue;
            
            switch on setting.Type__c {
                when 'String' {
                    typedValue = setting.Value__c;
                }
                when 'Integer' {
                    typedValue = Integer.valueOf(setting.Value__c);
                }
                when 'Decimal' {
                    typedValue = Decimal.valueOf(setting.Value__c);
                }
                when 'Boolean' {
                    typedValue = Boolean.valueOf(setting.Value__c);
                }
                when else {
                    typedValue = setting.Value__c;
                }
            }
            
            configCache.put(setting.DeveloperName, typedValue);
        }
    }
    
    /**
     * Odświeża konfigurację (np. po aktualizacji ustawień)
     */
    public void refreshConfiguration() {
        loadConfiguration();
    }
}