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
            // Prepare system context
            String systemPrompt = 'You are an expert in HR and recruitment, specializing in resume analysis. ' +
                'Your task is to analyze the submitted resume and extract key information. ' +
                'Return the results in JSON format with the following sections: ' +
                '1. skills (array of detected skills) ' +
                '2. workExperience (HTML formatted text with work experience) ' +
                '3. education (HTML formatted text with education) ' +
                '4. languages (array of known languages) ' +
                '5. certifications (array of certifications) ';
            
            // Add position information if available
            if (String.isNotBlank(jobDescription)) {
                systemPrompt += 'Additionally, evaluate the resume\'s match to the position description, adding the following sections: ' +
                    '6. matchScore (number from 0 to 100 indicating overall match) ' +
                    '7. skillsMatchScore (number from 0 to 100 indicating skills match) ' +
                    '8. experienceMatchScore (number from 0 to 100 indicating experience match) ' +
                    '9. recommendations (HTML text with recommendations for the recruiter) ';
            }
            
            // Prepare the prompt
            String prompt = 'Below is the resume text to analyze:\n\n' + resumeText;
            
            // Add job description if available
            if (String.isNotBlank(jobDescription)) {
                prompt += '\n\nPosition description:\n\n' + jobDescription;
            }
            
            // Add required skills if available
            if (requiredSkills != null && !requiredSkills.isEmpty()) {
                prompt += '\n\nRequired skills:\n\n' + String.join(requiredSkills, ', ');
            }
            
            // Call OpenAI API
            String response = OpenAIService.callOpenAI(prompt, systemPrompt);
            
            // Process JSON response
            try {
                // Extract JSON block from response
                Pattern p = Pattern.compile('\\{[\\s\\S]*\\}');
                Matcher m = p.matcher(response);
                if (m.find()) {
                    String jsonStr = m.group(0);
                    Map<String, Object> results = (Map<String, Object>)JSON.deserializeUntyped(jsonStr);
                    return results;
                } else {
                    throw new OpenAIService.OpenAIException('Could not find valid JSON response');
                }
            } catch (Exception e) {
                Logger.error('OpenAICVAnalyzer', 'analyzeResume', 'Error processing response', e);
                throw new OpenAIService.OpenAIException('Error processing response: ' + e.getMessage());
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