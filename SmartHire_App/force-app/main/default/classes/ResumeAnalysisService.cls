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

        System.debug('🔍 [ResumeAnalysisService] Processing applications: ' + applications.size());

        for (Job_Application__c app : applications) {
            System.debug('📝 Checking application: ' + app.Id + ', Status: ' + app.Status__c);

            // Sprawdzenie, czy status nie jest pusty i czy pasuje do warunków analizy
            if (String.isNotBlank(app.Status__c) && 
                (app.Status__c.equalsIgnoreCase('Applied') || app.Status__c.equalsIgnoreCase('Resume Review'))) {
                
                System.debug('✅ Application PASSES filter: ' + app.Id);
                applicationsForAnalysis.add(app.Id);
            } else {
                System.debug('❌ Application DOES NOT pass filter: ' + app.Id);
            }
        }

        if (applicationsForAnalysis.isEmpty()) {
            Logger.info(CLASS_NAME, 'scheduleAnalysisForApplications', 'No applications require resume analysis.');
            return;
        }

        try {
            // Sprawdź limit kolejki przed zaplanowaniem zadania
            Integer queueableJobsRunning = Limits.getQueueableJobs();
            Integer queueableJobsLimit = Limits.getLimitQueueableJobs();
            System.debug('📊 Queueable Jobs: ' + queueableJobsRunning + '/' + queueableJobsLimit);

            if (queueableJobsRunning < queueableJobsLimit) {
                System.enqueueJob(new ResumeAnalysisQueueable(applicationsForAnalysis));
                Logger.info(CLASS_NAME, 'scheduleAnalysisForApplications', 
                            'Queued CV analysis for ' + applicationsForAnalysis.size() + ' applications.');
            } else {
                Logger.warn(CLASS_NAME, 'scheduleAnalysisForApplications', 
                            'Cannot schedule analysis due to queueable job limits. Applications count: ' 
                            + applicationsForAnalysis.size());
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'scheduleAnalysisForApplications', 'Error scheduling CV analysis job', e);
            System.debug('⚠ ERROR scheduling CV analysis: ' + e.getMessage());
        }
    }
}