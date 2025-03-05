/**
 * Trigger for Job_Application__c object
 */
trigger JobApplicationTrigger on Job_Application__c (before insert, before update, before delete, 
                                                     after insert, after update, after delete, after undelete) {
    
    // Initialize the trigger handler
    JobApplicationTriggerHandler handler = new JobApplicationTriggerHandler();
    
    // Log trigger execution
    Logger.info('JobApplicationTrigger', 'execute', 'Trigger executed for ' + Trigger.operationType);
    
    // Route to the appropriate handler method based on trigger context
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            handler.onBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.onBeforeUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            handler.onBeforeDelete(Trigger.old);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            handler.onAfterInsert(Trigger.new);
            
            // Schedule CV analysis for new applications
            ResumeAnalysisService.scheduleAnalysisForApplications(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.onAfterUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            handler.onAfterDelete(Trigger.old);
        } else if (Trigger.isUndelete) {
            handler.onAfterUndelete(Trigger.new);
        }
    }
}