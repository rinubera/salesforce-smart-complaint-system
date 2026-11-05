public class CaseEscalationScheduler implements Schedulable, Database.Batchable<sObject> {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new CaseEscalationScheduler(), 50);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime threshold = System.now().addHours(-24);
        return Database.getQueryLocator(
            [SELECT Id, OwnerId, Priority, Status, LastModifiedDate, Escalation_Counter__c, Description 
             FROM Case 
             WHERE Status != 'Closed' 
             AND Priority = 'High' 
             AND LastModifiedDate < :threshold]
        );
    }

    public void execute(Database.BatchableContext bc, List<Case> scope) {
        List<Case> casesToEscalate = new List<Case>();
        List<Escalation_Audit_Trail__c> auditTrails = new List<Escalation_Audit_Trail__c>();
        
        Id targetOwnerId;
        List<Group> queues = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'Tier_2_Escalations' LIMIT 1];
        
        if (!queues.isEmpty()) {
            targetOwnerId = queues[0].Id;
        } else {
            targetOwnerId = UserInfo.getUserId(); // Safe fallback for test context or missing queue
        }

        for (Case c : scope) {
            String oldOwner = c.OwnerId;
            c.OwnerId = targetOwnerId;
            c.Escalation_Counter__c = (c.Escalation_Counter__c == null) ? 1 : c.Escalation_Counter__c + 1;
            c.Description = '[AUTOMATED ESCALATION]: Case escalated due to inactivity past threshold.';
            casesToEscalate.add(c);

            auditTrails.add(new Escalation_Audit_Trail__c(
                Case__c = c.Id,
                Previous_Owner__c = String.valueOf(oldOwner),
                New_Owner__c = String.valueOf(targetOwnerId),
                Escalation_Level__c = 'Tier 2',
                Trigger_Reason__c = 'SLA Inactivity Breach (>24 Hours)'
            ));
        }

        if (!casesToEscalate.isEmpty()) {
            update casesToEscalate;
        }
        if (!auditTrails.isEmpty()) {
            insert auditTrails;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Case Escalation Batch Finished Successfully.');
    }
}