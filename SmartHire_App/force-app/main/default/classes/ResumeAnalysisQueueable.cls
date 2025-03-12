/**
 * Klasa Queueable do asynchronicznej analizy CV
 * @author SmartHire Team
 * @date 2025-03-04
 */
public class ResumeAnalysisQueueable implements Queueable, Database.AllowsCallouts {
    
    private static final String CLASS_NAME = 'ResumeAnalysisQueueable';
    private List<Id> applicationIds;
    
    public ResumeAnalysisQueueable(List<Id> applicationIds) {
        this.applicationIds = applicationIds;
    }
    
    public void execute(QueueableContext context) {
        Integer maxToProcess = Math.min(applicationIds.size(), 5);
        List<Id> currentBatch = new List<Id>();

        for (Integer i = 0; i < maxToProcess; i++) {
            currentBatch.add(applicationIds[i]);
        }

        processApplications(currentBatch);
        
        // Jeśli zostały jeszcze aplikacje, zaplanuj kolejne zadanie
        if (applicationIds.size() > maxToProcess) {
            List<Id> remainingApplications = new List<Id>();
            for (Integer i = maxToProcess; i < applicationIds.size(); i++) {
                remainingApplications.add(applicationIds[i]);
            } 

            Integer queueableJobsRunning = Limits.getQueueableJobs();
            Integer queueableJobsLimit = Limits.getLimitQueueableJobs();

            if (queueableJobsRunning < queueableJobsLimit) {
                System.enqueueJob(new ResumeAnalysisQueueable(remainingApplications));
            } else {
                Logger.warn(CLASS_NAME, 'execute', 
                    'Limit kolejki osiągnięty. Nie przetworzono ' + remainingApplications.size() + ' aplikacji.');
            }
        }
    }
    
    private void processApplications(List<Id> appIds) {
        try {
            SecurityUtils.checkReadAccess(Job_Application__c.SObjectType, 
                new List<String>{'Id', 'Candidate__c', 'Position__c', 'Status__c'});
            SecurityUtils.checkReadAccess(ContentDocumentLink.SObjectType, 
                new List<String>{'ContentDocumentId', 'ContentDocument.Title', 'ContentDocument.FileType', 'ContentDocument.CreatedDate'});
            SecurityUtils.checkUpdateAccess(Job_Application__c.SObjectType, 
                new List<String>{'Status__c'});

            // 🔹 **Poprawione zapytanie SOQL - usuwa filtr Title**
            List<Job_Application__c> applications = [
                SELECT Id, Candidate__c, Position__c, 
                       (SELECT ContentDocumentId FROM ContentDocumentLinks)
                FROM Job_Application__c
                WHERE Id IN :appIds
            ];

            for (Job_Application__c app : applications) {
                try {
                    // 🔹 **Dodajemy debugowanie liczby znalezionych dokumentów**
                    System.debug('🔍 Application ID: ' + app.Id + ', Found ContentDocumentLinks: ' + 
                        (app.ContentDocumentLinks != null ? app.ContentDocumentLinks.size() : 0));

                    if (app.ContentDocumentLinks == null || app.ContentDocumentLinks.isEmpty()) {
                        Logger.warn(CLASS_NAME, 'processApplications', 'Brak CV dla aplikacji: ' + app.Id);
                        continue;
                    }

                    Id contentDocumentId = app.ContentDocumentLinks[0].ContentDocumentId;
                    
                    System.debug('📄 Processing CV for application: ' + app.Id + ', ContentDocumentId: ' + contentDocumentId);
                    
                    Map<String, Object> analysisResults = CVAnalysisService.analyzeCandidateResume(
                        contentDocumentId, app.Position__c, false
                    );

                    CVAnalysisService.createRecruiterTaskFromAnalysis(app.Id, analysisResults);

                    try { 
                        app.Status__c = 'Evaluation';
                        update app;
                        System.debug('✅ Status updated to Evaluation for: ' + app.Id);
                    } catch (Exception updateEx) {
                        Logger.error(CLASS_NAME, 'processApplications', 
                            'Błąd podczas aktualizacji statusu aplikacji: ' + app.Id, updateEx);
                    }
                } catch (Exception e) {
                    Logger.error(CLASS_NAME, 'processApplications', 
                        'Błąd podczas przetwarzania aplikacji: ' + app.Id, e);
                }
            }
        } catch (Exception e) {
            Logger.error(CLASS_NAME, 'processApplications', 'Błąd podczas przetwarzania aplikacji', e);
        }
    }
}