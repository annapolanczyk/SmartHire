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
        // Przetwarzaj nie więcej niż 5 aplikacji w jednym wywołaniu 
        // (ze względu na limity calloutów)
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
            
            // Sprawdź limity przed zaplanowaniem kolejnego zadania
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                System.enqueueJob(new ResumeAnalysisQueueable(remainingApplications));
            } else {
                // Loguj, że nie wszystkie aplikacje zostały przetworzone
                Logger.error(CLASS_NAME, 'execute', 
                    'Nie wszystkie aplikacje zostały przetworzone ze względu na limity. ' +
                    'Pozostało ' + remainingApplications.size() + ' aplikacji.', null);
            }
        }
    }
    
    private void processApplications(List<Id> appIds) {
        try {
            // Validate CRUD permissions
            SecurityUtils.checkReadAccess(Job_Application__c.SObjectType, 
                new List<String>{'Id', 'Candidate__c', 'Position__c', 'Status__c'});
            SecurityUtils.checkReadAccess(ContentDocumentLink.SObjectType, 
                new List<String>{'ContentDocumentId', 'ContentDocument.Title', 'ContentDocument.FileType', 'ContentDocument.CreatedDate'});
            SecurityUtils.checkUpdateAccess(Job_Application__c.SObjectType, 
                new List<String>{'Status__c'});
            
            // Get application data with related CV documents
            List<Job_Application__c> applications = [
                SELECT Id, Candidate__c, Position__c, 
                       (SELECT ContentDocumentId FROM ContentDocumentLinks WHERE 
                        ContentDocument.Title LIKE '%CV%' OR 
                        ContentDocument.Title LIKE '%Resume%' OR
                        ContentDocument.FileType IN ('PDF', 'DOCX', 'DOC', 'TXT')
                        ORDER BY ContentDocument.CreatedDate DESC LIMIT 1)
                FROM Job_Application__c
                WHERE Id IN :appIds
            ];
            
            for (Job_Application__c app : applications) {
                try {
                    // Jeśli znaleziono dokument CV
                    if (!app.ContentDocumentLinks.isEmpty()) {
                        Id contentDocumentId = app.ContentDocumentLinks[0].ContentDocumentId;
                        
                        // Analizuj CV
                        Map<String, Object> analysisResults = CVAnalysisService.analyzeCandidateResume(
                            contentDocumentId, app.Position__c, false
                        );
                        
                        // Utwórz zadanie z wynikami analizy
                        CVAnalysisService.createRecruiterTaskFromAnalysis(app.Id, analysisResults);
                        
                        // Aktualizuj status aplikacji
                        try { 
                            app.Status__c = 'Evaluation';
                            update app;
                        } catch (Exception updateEx) {
                            Logger.error(CLASS_NAME, 'processApplications', 
                                'Błąd podczas aktualizacji statusu aplikacji: ' + app.Id, updateEx);
                        }
                    } else {
                        // Loguj brak dokumentu CV
                        Logger.error(CLASS_NAME, 'processApplications', 
                            'Nie znaleziono dokumentu CV dla aplikacji: ' + app.Id, null);
                    }
                } catch (Exception e) {
                    // Loguj błąd przetwarzania pojedynczej aplikacji
                    Logger.error(CLASS_NAME, 'processApplications', 
                        'Błąd podczas przetwarzania aplikacji: ' + app.Id, e);
                }
            }
        } catch (Exception e) {
            // Loguj błąd ogólny
            Logger.error(CLASS_NAME, 'processApplications', 
                'Błąd podczas przetwarzania aplikacji', e);
        }
    }
}