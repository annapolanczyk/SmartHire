/**
 * Handler dla triggera Application__c
 * Implementuje automatyczną analizę CV po utworzeniu aplikacji
 * @author SmartHire Team
 * @date 2025-03-04
 */
public class JobApplicationTriggerHandler {
    
    /**
     * Obsługa zdarzenia before insert
     */
    public void onBeforeInsert(List<Application__c> newApplications) {
        // Walidacja przed wstawieniem
        validateApplications(newApplications);
    }
    
    /**
     * Obsługa zdarzenia before update
     */
    public void onBeforeUpdate(List<Application__c> newApplications, Map<Id, Application__c> oldApplicationsMap) {
        // Walidacja przed aktualizacją
        validateUpdates(newApplications, oldApplicationsMap);
    }
    
    /**
     * Obsługa zdarzenia before delete
     */
    public void onBeforeDelete(List<Application__c> oldApplications) {
        // Walidacja przed usunięciem (np. czy użytkownik ma uprawnienia)
        validateDeletions(oldApplications);
    }
    
    /**
     * Obsługa zdarzenia after insert
     */
    public void onAfterInsert(List<Application__c> newApplications) {
        // Inicjacja automatycznej analizy CV dla nowych aplikacji
        scheduleResumeAnalysisForNewApplications(newApplications);
    }
    
    /**
     * Obsługa zdarzenia after update
     */
    public void onAfterUpdate(List<Application__c> newApplications, Map<Id, Application__c> oldApplicationsMap) {
        // Logika po aktualizacji (np. powiadomienie o zmianie statusu)
        processStatusChanges(newApplications, oldApplicationsMap);
    }
    
    /**
     * Obsługa zdarzenia after delete
     */
    public void onAfterDelete(List<Application__c> oldApplications) {
        // Logika po usunięciu
    }
    
    /**
     * Obsługa zdarzenia after undelete
     */
    public void onAfterUndelete(List<Application__c> newApplications) {
        // Logika po przywróceniu
    }
    
    /**
     * Waliduje nowe aplikacje
     */
    private void validateApplications(List<Application__c> applications) {
        Set<Id> candidateIds = new Set<Id>();
        Set<Id> positionIds = new Set<Id>();
        
        for (Application__c app : applications) {
            candidateIds.add(app.Candidate__c);
            positionIds.add(app.Position__c);
        }
        
        // Sprawdź, czy stanowiska są aktywne
        Map<Id, Position__c> positions = new Map<Id, Position__c>([
            SELECT Id, Status__c 
            FROM Position__c 
            WHERE Id IN :positionIds
        ]);
        
        // Sprawdź, czy kandydaci są aktywni
        Map<Id, Candidate__c> candidates = new Map<Id, Candidate__c>([
            SELECT Id, Status__c 
            FROM Candidate__c 
            WHERE Id IN :candidateIds
        ]);
        
        // Sprawdź, czy aplikacje nie są duplikatami
        Set<String> candidatePositionPairs = new Set<String>();
        List<Application__c> existingApplications = [
            SELECT Id, Candidate__c, Position__c 
            FROM Application__c 
            WHERE Candidate__c IN :candidateIds 
            AND Position__c IN :positionIds
        ];
        
        for (Application__c app : existingApplications) {
            candidatePositionPairs.add(app.Candidate__c + '-' + app.Position__c);
        }
        
        // Walidacja
        for (Application__c app : applications) {
            // Sprawdź status stanowiska
            Position__c position = positions.get(app.Position__c);
            if (position != null && position.Status__c != 'Open') {
                app.addError('Nie można złożyć aplikacji na zamknięte stanowisko');
            }
            
            // Sprawdź status kandydata
            Candidate__c candidate = candidates.get(app.Candidate__c);
            if (candidate != null && candidate.Status__c == 'Inactive') {
                app.addError('Nieaktywny kandydat nie może złożyć aplikacji');
            }
            
            // Sprawdź duplikaty
            if (candidatePositionPairs.contains(app.Candidate__c + '-' + app.Position__c)) {
                app.addError('Kandydat już złożył aplikację na to stanowisko');
            }
        }
    }
    
    /**
     * Waliduje aktualizacje aplikacji
     */
    private void validateUpdates(List<Application__c> newApplications, Map<Id, Application__c> oldApplicationsMap) {
        for (Application__c app : newApplications) {
            Application__c oldApp = oldApplicationsMap.get(app.Id);
            
            // Przykładowa walidacja: nie można zmienić kandydata w istniejącej aplikacji
            if (app.Candidate__c != oldApp.Candidate__c) {
                app.Candidate__c = oldApp.Candidate__c;
                app.addError('Nie można zmienić kandydata w istniejącej aplikacji');
            }
            
            // Przykładowa walidacja: nie można zmienić stanowiska w istniejącej aplikacji
            if (app.Position__c != oldApp.Position__c) {
                app.Position__c = oldApp.Position__c;
                app.addError('Nie można zmienić stanowiska w istniejącej aplikacji');
            }
        }
    }
    
    /**
     * Waliduje usuwanie aplikacji
     */
    private void validateDeletions(List<Application__c> oldApplications) {
        for (Application__c app : oldApplications) {
            // Przykładowa walidacja: nie można usunąć aplikacji w określonych statusach
            if (app.Status__c == 'Hired' || app.Status__c == 'Offer Extended') {
                app.addError('Nie można usunąć aplikacji w statusie ' + app.Status__c);
            }
        }
    }
    
    /**
     * Planuje analizę CV dla nowych aplikacji
     */
    private void scheduleResumeAnalysisForNewApplications(List<Application__c> newApplications) {
        // Zbierz ID aplikacji, które wymagają analizy CV
        List<Id> applicationsForAnalysis = new List<Id>();
        
        for (Application__c app : newApplications) {
            // Dodaj do listy analizy tylko nowe aplikacje
            if (app.Status__c == 'Applied' || app.Status__c == 'Resume Review') {
                applicationsForAnalysis.add(app.Id);
            }
        }
        
        // Jeśli są aplikacje do analizy, zaplanuj zadanie wsadowe
        if (!applicationsForAnalysis.isEmpty()) {
            // W rzeczywistym scenariuszu, używalibyśmy Queueable lub Batch Apex
            // do asynchronicznego przetwarzania analizy CV
            System.enqueueJob(new ResumeAnalysisQueueable(applicationsForAnalysis));
        }
    }
    
    /**
     * Przetwarza zmiany statusów aplikacji
     */
    private void processStatusChanges(List<Application__c> newApplications, Map<Id, Application__c> oldApplicationsMap) {
        List<Task> tasksToCreate = new List<Task>();
        
        for (Application__c app : newApplications) {
            Application__c oldApp = oldApplicationsMap.get(app.Id);
            
            // Jeśli status się zmienił
            if (app.Status__c != oldApp.Status__c) {
                // Utwórz zadanie dla rekordera na podstawie nowego statusu
                Task newTask = new Task();
                newTask.Subject = 'Status aplikacji zaktualizowany: ' + app.Status__c;
                newTask.Description = 'Aplikacja dla kandydata została zaktualizowana z ' + 
                                     oldApp.Status__c + ' na ' + app.Status__c;
                newTask.WhatId = app.Id;
                newTask.Status = 'Not Started';
                newTask.Priority = 'Normal';
                newTask.ActivityDate = Date.today().addDays(1);
                
                if (app.Assigned_Reviewer__c != null) {
                    newTask.OwnerId = app.Assigned_Reviewer__c;
                }
                
                tasksToCreate.add(newTask);
            }
        }
        
        // Wstaw zadania (jeśli są)
        if (!tasksToCreate.isEmpty()) {
            insert tasksToCreate;
        }
    }
}