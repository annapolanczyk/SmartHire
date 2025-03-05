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
        if (applications == null || applications.isEmpty()) {
            Logger.warn(CLASS_NAME, 'scheduleAnalysisForApplications', 'No applications provided for analysis.');
            return;
        }

        // Zbierz ID aplikacji, które wymagają analizy CV
        List<Id> applicationsForAnalysis = new List<Id>();

        for (Job_Application__c app : applications) {
            if (app.Status__c != null && (app.Status__c.equalsIgnoreCase('Applied') || app.Status__c.equalsIgnoreCase('Resume Review'))) {
                applicationsForAnalysis.add(app.Id);
            }
        }

        if (applicationsForAnalysis.isEmpty()) {
            Logger.info(CLASS_NAME, 'scheduleAnalysisForApplications', 'No applications require resume analysis.');
            return;
        }

        try {
            // Sprawdź limit kolejki przed zaplanowaniem zadania
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                System.enqueueJob(new ResumeAnalysisQueueable(applicationsForAnalysis));
                Logger.info(CLASS_NAME, 'scheduleAnalysisForApplications', 'Queued CV analysis for ' + applicationsForAnalysis.size() + ' applications.');
            } else {
                Logger.error(CLASS_NAME, 'scheduleAnalysisForApplications', 
                             'Cannot schedule analysis due to queueable job limits. Applications count: ' + applicationsForAnalysis.size(), null);
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'scheduleAnalysisForApplications', 'Error scheduling CV analysis job', e);
        }
    }
}
