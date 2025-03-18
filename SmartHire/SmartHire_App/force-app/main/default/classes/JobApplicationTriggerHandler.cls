/**
 * @description       : Handler class for Job Application triggers
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 03-05-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class JobApplicationTriggerHandler {
    
    private static final String CLASS_NAME = 'JobApplicationTriggerHandler';
    
    // Metoda obsługująca logikę przed wstawieniem nowych rekordów
    public void onBeforeInsert(List<Job_Application__c> newList) {
        Logger.info(CLASS_NAME, 'onBeforeInsert', 'Trigger executed.');
        // Dodaj tutaj logikę, np. walidacje lub uzupełnianie pól
    }
    
    // Metoda obsługująca logikę przed aktualizacją rekordów
    public void onBeforeUpdate(List<Job_Application__c> newList, Map<Id, Job_Application__c> oldMap) {
        Logger.info(CLASS_NAME, 'onBeforeUpdate', 'Trigger executed.');
        // Dodaj tutaj logikę przed aktualizacją
    }
    
    // Metoda obsługująca logikę przed usunięciem rekordów
    public void onBeforeDelete(List<Job_Application__c> oldList) {
        Logger.info(CLASS_NAME, 'onBeforeDelete', 'Trigger executed.');
        // Dodaj tutaj logikę przed usunięciem
    }
    
    // Metoda obsługująca logikę po wstawieniu nowych rekordów
    public void onAfterInsert(List<Job_Application__c> newList) {
        Logger.info(CLASS_NAME, 'onAfterInsert', 'Trigger executed.');
        // Dodaj tutaj logikę po wstawieniu rekordów
    }
    
    // Metoda obsługująca logikę po aktualizacji rekordów
    public void onAfterUpdate(List<Job_Application__c> newList, Map<Id, Job_Application__c> oldMap) {
        Logger.info(CLASS_NAME, 'onAfterUpdate', 'Trigger executed.');
        // Dodaj tutaj logikę po aktualizacji rekordów
    }
    
    // Metoda obsługująca logikę po usunięciu rekordów
    public void onAfterDelete(List<Job_Application__c> oldList) {
        Logger.info(CLASS_NAME, 'onAfterDelete', 'Trigger executed.');
        // Dodaj tutaj logikę po usunięciu rekordów
    }
    
    // Metoda obsługująca logikę po przywróceniu rekordów (undelete)
    public void onAfterUndelete(List<Job_Application__c> newList) {
        Logger.info(CLASS_NAME, 'onAfterUndelete', 'Trigger executed.');
        // Dodaj tutaj logikę po przywróceniu rekordów
    }
}