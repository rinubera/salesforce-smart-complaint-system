public class CaseTriggerHandler {

    public void beforeInsert(List<Case> newCases) {
        setInitialSlaAndPriority(newCases, null);
    }

    public void beforeUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        setInitialSlaAndPriority(newCases, oldMap);
        validateCaseClosure(newCases, oldMap);
    }

    public void afterInsert(List<Case> newCases) {
        dispatchSentimentAnalysis(newCases, null);
    }

    public void afterUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        dispatchSentimentAnalysis(newCases, oldMap);
    }

    private void setInitialSlaAndPriority(List<Case> cases, Map<Id, Case> oldMap) {
        for (Case c : cases) {
            if (oldMap == null || c.Type != oldMap.get(c.Id).Type || c.Priority != oldMap.get(c.Id).Priority) {
                if (c.Type == 'Billing Error') {
                    c.Priority = 'High';
                }
            }
        }
    }

    private void validateCaseClosure(List<Case> cases, Map<Id, Case> oldMap) {
        for (Case c : cases) {
            if (c.Status == 'Closed' && oldMap.get(c.Id).Status != 'Closed') {
                if (String.isBlank(c.Reason)) {
                    c.addError('You must specify a Case Reason/Root Cause before closing a complaint.');
                }
            }
        }
    }

    private void dispatchSentimentAnalysis(List<Case> cases, Map<Id, Case> oldMap) {
        List<Id> caseIdsToAnalyze = new List<Id>();
        for (Case c : cases) {
            if (oldMap == null || (c.Description != oldMap.get(c.Id).Description && String.isNotBlank(c.Description))) {
                caseIdsToAnalyze.add(c.Id);
            }
        }
        if (!caseIdsToAnalyze.isEmpty() && !System.isQueueable() && !System.isBatch()) {
            System.enqueueJob(new SentimentAnalysisQueueable(caseIdsToAnalyze));
        }
    }
}