@IsTest
private class CaseTriggerHandlerTest {

    @IsTest
    static void testCaseInsertionAndSentimentQueueable() {
        Test.startTest();
        Case testCase = new Case(
            Subject = 'Billing dispute over invoice charge',
            Description = 'I am extremely unhappy, this service is terrible and I will sue!',
            Status = 'New',
            Origin = 'Web'
        );
        insert testCase;
        Test.stopTest(); // Flushes async queueable job

        Case insertedCase = [SELECT Id, Priority FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('High', insertedCase.Priority, 'Priority should be escalated to High due to negative sentiment.');

        Complaint_Log__c log = [SELECT Sentiment_Score__c, Root_Cause_Category__c FROM Complaint_Log__c WHERE Case__c = :testCase.Id];
        System.assertNotEquals(null, log, 'A complaint log should be generated.');
        System.assertEquals(9, log.Sentiment_Score__c, 'Sentiment score should reflect critical urgency.');
        System.assertEquals('Billing', log.Root_Cause_Category__c, 'Root cause category should be mapped correctly.');
    }

    @IsTest
    static void testClosureValidation() {
        Case testCase = new Case(
            Subject = 'General inquiry',
            Description = 'Just asking a question.',
            Status = 'New',
            Origin = 'Phone'
        );
        insert testCase;

        testCase.Status = 'Closed';
        testCase.Reason = null; // Blank reason triggers validation rule error

        Test.startTest();
        try {
            update testCase;
            System.assert(false, 'Expected validation exception on close without reason.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('You must specify a Case Reason'), 'Error message should match validation criteria.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testBatchEscalationScheduler() {
        Case oldCase = new Case(
            Subject = 'System Outage Issue',
            Description = 'Server is down completely.',
            Priority = 'High',
            Status = 'New',
            Origin = 'Web'
        );
        insert oldCase;

        Test.startTest();
        CaseEscalationScheduler scheduler = new CaseEscalationScheduler();
        Database.executeBatch(scheduler, 10);
        Test.stopTest();

        Case updatedCase = [SELECT Id, Escalation_Counter__c FROM Case WHERE Id = :oldCase.Id];
        System.assertEquals(1, updatedCase.Escalation_Counter__c, 'Escalation counter should increment.');
    }
}