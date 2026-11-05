public class SentimentAnalysisQueueable implements Queueable, Database.AllowsCallouts {
    private List<Id> caseIds;

    public SentimentAnalysisQueueable(List<Id> caseIds) {
        this.caseIds = caseIds;
    }

    public void execute(QueueableContext context) {
        List<Case> casesToUpdate = [SELECT Id, Description, Priority, Subject FROM Case WHERE Id IN :caseIds];
        List<Complaint_Log__c> logsToInsert = new List<Complaint_Log__c>();

        for (Case c : casesToUpdate) {
            Integer calculatedScore = evaluateSentiment(c.Description);
            
            if (calculatedScore >= 8 && c.Priority != 'High') {
                c.Priority = 'High';
            }

            logsToInsert.add(new Complaint_Log__c(
                Case__c = c.Id,
                Sentiment_Score__c = calculatedScore,
                Root_Cause_Category__c = determineCategory(c.Subject)
            ));
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
        if (!logsToInsert.isEmpty()) {
            insert logsToInsert;
        }
    }

    private Integer evaluateSentiment(String text) {
        if (String.isBlank(text)) return 5;
        String lowerText = text.toLowerCase();
        if (lowerText.contains('legal') || lowerText.contains('sue') || lowerText.contains('broken') || lowerText.contains('terrible')) {
            return 9;
        } else if (lowerText.contains('delay') || lowerText.contains('issue') || lowerText.contains('disappointed')) {
            return 6;
        }
        return 3;
    }

    private String determineCategory(String subject) {
        if (String.isBlank(subject)) return 'Service Delivery';
        String lowerSubject = subject.toLowerCase();
        if (lowerSubject.contains('bill') || lowerSubject.contains('charge')) return 'Billing';
        if (lowerSubject.contains('outage') || lowerSubject.contains('down')) return 'System Outage';
        return 'Product Defect';
    }
}