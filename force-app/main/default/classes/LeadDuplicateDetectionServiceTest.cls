@isTest
private class LeadDuplicateDetectionServiceTest {
    private static Lead newLead(String lastName, String email, String phone, String mobilePhone) {
        return new Lead(
            LastName = lastName,
            Company = 'Example Company',
            Email = email,
            Phone = phone,
            MobilePhone = mobilePhone
        );
    }

    @isTest
    static void detectsLeadEmailAndBothLeadPhoneFields() {
        Lead existingLead = newLead('Existing Lead', 'existing.lead@example.test', '4155550101', '4155550102');
        insert existingLead;

        List<Lead> candidates = new List<Lead>{
            newLead('Email Match', '  EXISTING.LEAD@example.test  ', null, null),
            newLead('Phone Match', null, ' 4155550101 ', null),
            newLead('Mobile Match', null, null, ' 4155550102 ')
        };

        Test.startTest();
        List<Boolean> duplicateFlags = LeadDuplicateDetectionService.findPotentialDuplicates(candidates);
        Test.stopTest();

        System.assertEquals(3, duplicateFlags.size(), 'The service should return one generic indicator per input Lead.');
        System.assertEquals(true, duplicateFlags[0], 'Email matching should ignore case and surrounding spaces.');
        System.assertEquals(true, duplicateFlags[1], 'Lead Phone should be compared after trimming whitespace.');
        System.assertEquals(true, duplicateFlags[2], 'Lead MobilePhone should be compared after trimming whitespace.');
    }

    @isTest
    static void detectsContactEmailAndEveryInScopeContactPhoneField() {
        Contact existingContact = new Contact(
            LastName = 'Existing Contact',
            Email = 'known.contact@example.test',
            Phone = '2125551001',
            MobilePhone = '2125551002',
            HomePhone = '2125551003',
            OtherPhone = '2125551004',
            AssistantPhone = '2125551005'
        );
        insert existingContact;

        List<Lead> candidates = new List<Lead>{
            newLead('Email Match', '  KNOWN.CONTACT@example.test  ', null, null),
            newLead('Phone Match', null, ' 2125551001 ', null),
            newLead('Mobile Match', null, null, ' 2125551002 '),
            newLead('Home Match', null, ' 2125551003 ', null),
            newLead('Other Match', null, ' 2125551004 ', null),
            newLead('Assistant Match', null, ' 2125551005 ', null)
        };

        Test.startTest();
        List<Boolean> duplicateFlags = LeadDuplicateDetectionService.findPotentialDuplicates(candidates);
        Test.stopTest();

        System.assertEquals(6, duplicateFlags.size(), 'The service should return one generic indicator per input Lead.');
        for (Integer i = 0; i < duplicateFlags.size(); i++) {
            System.assertEquals(true, duplicateFlags[i], 'Each documented Contact field should identify a match at index ' + i + '.');
        }
    }

    @isTest
    static void blankValuesNoMatchAndSelfMatchDoNotFlag() {
        Lead existingLead = newLead('Only Lead', 'self.only@example.test', '6505550199', null);
        insert existingLead;
        existingLead = [SELECT Id, LastName, Company, Email, Phone, MobilePhone FROM Lead WHERE Id = :existingLead.Id];

        List<Lead> candidates = new List<Lead>{
            newLead('Unmatched', 'nobody@example.test', '6505550000', null),
            newLead('Blank Email', '   ', null, null),
            existingLead
        };

        Test.startTest();
        List<Boolean> duplicateFlags = LeadDuplicateDetectionService.findPotentialDuplicates(candidates);
        List<Boolean> nullListFlags = LeadDuplicateDetectionService.findPotentialDuplicates(null);
        List<Boolean> nullEntryFlags = LeadDuplicateDetectionService.findPotentialDuplicates(new List<Lead>{ null });
        Test.stopTest();

        System.assertEquals(false, duplicateFlags[0], 'A Lead with no matching email or phone should not be flagged.');
        System.assertEquals(false, duplicateFlags[1], 'A blank email without a populated phone should not be flagged.');
        System.assertEquals(false, duplicateFlags[2], 'A Lead must not match itself.');
        System.assertEquals(0, nullListFlags.size(), 'A null input list should return an empty result.');
        System.assertEquals(1, nullEntryFlags.size(), 'A null entry should retain its position in the result.');
        System.assertEquals(false, nullEntryFlags[0], 'A null entry should not be flagged.');
    }

    @isTest
    static void bulkInputsReturnOneFlagPerLead() {
        insert newLead('Bulk Existing', 'bulk.match@example.test', null, null);

        List<Lead> bulkCandidates = new List<Lead>();
        for (Integer i = 0; i < 200; i++) {
            bulkCandidates.add(newLead('Bulk Candidate ' + i, 'bulk.match@example.test', null, null));
        }

        Test.startTest();
        List<Boolean> duplicateFlags = LeadDuplicateDetectionService.findPotentialDuplicates(bulkCandidates);
        Test.stopTest();

        System.assertEquals(200, duplicateFlags.size(), 'A bulk call should preserve all 200 input positions.');
        for (Integer i = 0; i < duplicateFlags.size(); i++) {
            System.assertEquals(true, duplicateFlags[i], 'Each candidate should be flagged against the matching Lead at index ' + i + '.');
        }
    }

    @isTest
    static void duplicateCheckDoesNotModifyExistingRecordsAndTriggerAllowsInsert() {
        Lead originalLead = newLead('Unchanged Lead', 'trigger.match@example.test', '3035550111', null);
        insert originalLead;
        Contact originalContact = new Contact(
            LastName = 'Unchanged Contact',
            Email = 'unchanged.contact@example.test',
            Phone = '3035550112'
        );
        insert originalContact;

        Integer leadCountBeforeCheck = [SELECT COUNT() FROM Lead];
        Integer contactCountBeforeCheck = [SELECT COUNT() FROM Contact];

        Test.startTest();
        List<Boolean> flags = LeadDuplicateDetectionService.findPotentialDuplicates(
            new List<Lead>{ newLead('Would Match Contact', 'unchanged.contact@example.test', null, null) }
        );
        Test.stopTest();

        System.assertEquals(true, flags[0], 'The service should return only a generic indication for a Contact match.');
        System.assertEquals(leadCountBeforeCheck, [SELECT COUNT() FROM Lead], 'Checking for a match must not create a Lead.');
        System.assertEquals(contactCountBeforeCheck, [SELECT COUNT() FROM Contact], 'Checking for a match must not create or change a Contact.');

        Lead allowedDuplicate = newLead('Allowed Duplicate', 'trigger.match@example.test', null, null);
        insert allowedDuplicate;

        Lead reloadedLead = [SELECT LastName, Email, Phone FROM Lead WHERE Id = :originalLead.Id];
        Contact reloadedContact = [SELECT LastName, Email, Phone FROM Contact WHERE Id = :originalContact.Id];
        Integer leadCountAfterInsert = [SELECT COUNT() FROM Lead];

        System.assertEquals(leadCountBeforeCheck + 1, leadCountAfterInsert, 'The Lead trigger should allow the new Lead to be saved after a duplicate indication.');
        System.assertEquals('Unchanged Lead', reloadedLead.LastName, 'Duplicate detection must not change an existing Lead.');
        System.assertEquals('trigger.match@example.test', reloadedLead.Email, 'Duplicate detection must preserve the existing Lead email.');
        System.assertEquals('3035550111', reloadedLead.Phone, 'Duplicate detection must preserve the existing Lead phone.');
        System.assertEquals('Unchanged Contact', reloadedContact.LastName, 'Duplicate detection must not change an existing Contact.');
        System.assertEquals('unchanged.contact@example.test', reloadedContact.Email, 'Duplicate detection must preserve the existing Contact email.');
        System.assertEquals('3035550112', reloadedContact.Phone, 'Duplicate detection must preserve the existing Contact phone.');
    }
}
