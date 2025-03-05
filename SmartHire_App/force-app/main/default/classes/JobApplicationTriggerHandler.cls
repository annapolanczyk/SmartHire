/**
 * Serwis do obsługi analizy CV
 */
public with sharing class ResumeAnalysisService {

    private static final String CLASS_NAME = 'ResumeAnalysisService';
    
    /**
     * Planuje analizę CV dla nowych aplikacji
     * @param applications lista nowych aplikacji
     */
    public static void scheduleAnalysisForApplications(List<Job_Application__c> applications) {
        // Zbierz ID aplikacji, które wymagają analizy CV
        List<Id> applicationsForAnalysis = new List<Id>();
        
        for (Job_Application__c app : applications) {
            // Dodaj do listy analizy tylko nowe aplikacje
            if (app.Status__c == 'Applied' || app.Status__c == 'Resume Review') {
                applicationsForAnalysis.add(app.Id);
            }
        }
        
        // Jeśli są aplikacje do analizy, zaplanuj zadanie wsadowe
        if (!applicationsForAnalysis.isEmpty()) {
            try {
                // Sprawdź limity przed zaplanowaniem zadania
                if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                    System.enqueueJob(new ResumeAnalysisQueueable(applicationsForAnalysis));
                } else {
                    // Loguj, gdy nie można zaplanować zadania
                    Logger.error(CLASS_NAME, 'scheduleAnalysisForApplications', 
                                'Cannot schedule analysis due to queueable job limits. ' + 
                                'Applications count: ' + applicationsForAnalysis.size(), null);
                }
            } catch (Exception e) {
                Logger.error(CLASS_NAME, 'scheduleAnalysisForApplications', 
                            'Error scheduling CV analysis job', e);
            }
        }
    }
}