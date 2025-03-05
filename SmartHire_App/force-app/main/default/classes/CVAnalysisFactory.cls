/**
 * Factory dla różnych implementacji serwisów analizy CV
 * @author SmartHire Team
 * @date 2025-03-04
 */
public class CVAnalysisFactory {
    
    // Typy analizatorów CV
    public enum AnalyzerType {
        OPENAI,
        EINSTEIN,
        CUSTOM
    }
    
    /**
     * Interfejs dla analizatorów CV
     */
    public interface ICVAnalyzer {
        Map<String, Object> analyzeResume(String resumeText, String jobDescription, List<String> requiredSkills);
    }
    
    /**
     * Tworzy instancję analizatora CV wybranego typu
     * @param type Typ analizatora do utworzenia
     * @return Instancja analizatora
     */
    public static ICVAnalyzer getAnalyzer(AnalyzerType type) {
        switch on type {
            when OPENAI {
                return new OpenAICVAnalyzer();
            }
            when EINSTEIN {
                return new EinsteinCVAnalyzer();
            }
            when CUSTOM {
                return new CustomCVAnalyzer();
            }
            when else {
                // Domyślnie zwróć OpenAI
                return new OpenAICVAnalyzer();
            }
        }
    }
    
    /**
     * Implementacja analizatora CV używającego OpenAI
     */
    private class OpenAICVAnalyzer implements ICVAnalyzer {
        public Map<String, Object> analyzeResume(String resumeText, String jobDescription, List<String> requiredSkills) {
            // Przygotuj kontekst systemowy
            String systemPrompt = 'Jesteś ekspertem w dziedzinie HR i rekrutacji, specjalizującym się w analizie CV. ' +
                'Twoim zadaniem jest analiza przesłanego CV i wyodrębnienie kluczowych informacji. ' +
                'Zwróć wyniki w formacie JSON z następującymi sekcjami: ' +
                '1. skills (tablica wykrytych umiejętności) ' +
                '2. workExperience (sformatowany tekst HTML z doświadczeniem zawodowym) ' +
                '3. education (sformatowany tekst HTML z wykształceniem) ' +
                '4. languages (tablica znanych języków) ' +
                '5. certifications (tablica certyfikatów) ';
            
            // Dodaj informacje o stanowisku, jeśli są dostępne
            if (String.isNotBlank(jobDescription)) {
                systemPrompt += 'Dodatkowo oceń dopasowanie CV do opisu stanowiska, dodając następujące sekcje: ' +
                    '6. matchScore (liczba od 0 do 100 określająca ogólne dopasowanie) ' +
                    '7. skillsMatchScore (liczba od 0 do 100 określająca dopasowanie umiejętności) ' +
                    '8. experienceMatchScore (liczba od 0 do 100 określająca dopasowanie doświadczenia) ' +
                    '9. recommendations (tekst HTML z rekomendacjami dla rekrutera) ';
            }
            
            // Przygotuj zapytanie
            String prompt = 'Poniżej znajduje się tekst CV do analizy:\n\n' + resumeText;
            
            // Dodaj opis stanowiska, jeśli jest dostępny
            if (String.isNotBlank(jobDescription)) {
                prompt += '\n\nOpis stanowiska:\n\n' + jobDescription;
            }
            
            // Dodaj wymagane umiejętności, jeśli są dostępne
            if (requiredSkills != null && !requiredSkills.isEmpty()) {
                prompt += '\n\nWymagane umiejętności:\n\n' + String.join(requiredSkills, ', ');
            }
            
            // Wywołaj OpenAI API
            String response = OpenAIService.callOpenAI(prompt, systemPrompt);
            
            // Przetwórz odpowiedź JSON
            try {
                // Ekstrakcja bloku JSON z odpowiedzi
                Pattern p = Pattern.compile('\\{[\\s\\S]*\\}');
                Matcher m = p.matcher(response);
                if (m.find()) {
                    String jsonStr = m.group(0);
                    Map<String, Object> results = (Map<String, Object>)JSON.deserializeUntyped(jsonStr);
                    return results;
                } else {
                    throw new OpenAIService.OpenAIException('Nie można znaleźć prawidłowej odpowiedzi JSON');
                }
            } catch (Exception e) {
                Logger.error('OpenAICVAnalyzer', 'analyzeResume', 'Błąd przetwarzania odpowiedzi', e);
                throw new OpenAIService.OpenAIException('Błąd przetwarzania odpowiedzi: ' + e.getMessage());
            }
        }
    }
    
    /**
     * Implementacja analizatora CV używającego Einstein
     */
    private class EinsteinCVAnalyzer implements ICVAnalyzer {
        public Map<String, Object> analyzeResume(String resumeText, String jobDescription, List<String> requiredSkills) {
            // Przygotowanie zapytania do API Einstein
            Map<String, Object> requestBody = new Map<String, Object>{
                'document' => resumeText,
                'jobDescription' => jobDescription,
                'requiredSkills' => requiredSkills
            };
            
            // Wywołanie API Einstein
            // W rzeczywistej implementacji należy użyć odpowiedniego endpointu i autentykacji
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Einstein_NLP_API/v2/language/analyze');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + getEinsteinToken());
            req.setBody(JSON.serialize(requestBody));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                // Parsowanie wyników z API Einstein
                Map<String, Object> apiResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                return apiResponse;
            } else {
                throw new AuraHandledException('Error calling Einstein API: ' + res.getStatusCode() + ' ' + res.getStatus());
            }
        }
        
        private String getEinsteinToken() {
            // Implementacja pobierania tokenu dla Einstein API
            return 'sample_token';
        }
    }
    
    /**
     * Implementacja własnego analizatora CV
     */
    private class CustomCVAnalyzer implements ICVAnalyzer {
        public Map<String, Object> analyzeResume(String resumeText, String jobDescription, List<String> requiredSkills) {
            // Prosta implementacja własnej analizy CV
            Map<String, Object> results = new Map<String, Object>();
            
            // Wykrywanie umiejętności (prosta implementacja)
            List<String> detectedSkills = new List<String>();
            if (requiredSkills != null) {
                for (String skill : requiredSkills) {
                    if (resumeText.toLowerCase().contains(skill.toLowerCase())) {
                        detectedSkills.add(skill);
                    }
                }
            }
            results.put('skills', detectedSkills);
            
            // Prosta analiza dopasowania
            if (requiredSkills != null && !requiredSkills.isEmpty()) {
                Decimal matchPercentage = ((Decimal)detectedSkills.size() / requiredSkills.size()) * 100;
                results.put('matchScore', matchPercentage.setScale(1));
            }
            
            return results;
        }
    }
}