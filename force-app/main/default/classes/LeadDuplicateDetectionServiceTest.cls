@isTest
private class LeadDuplicateDetectionServiceTest {
    @isTest
    static void testNormalizedEmailAndPhoneMatchLeadsAndContactsWithoutMutation() {
        Lead existingLead = new Lead(
            LastName = 'Existing Lead',
            Company = 'Example Co',
            Email = 'person@example.com',
            Phone = '4155550100',
            MobilePhone = '4155550199'
        );
        insert existingLead;

        Contact existingContact = new Contact(
            LastName = 'Existing Contact',
            Email = 'other@example.com',
            Phone = '2125550100',
            MobilePhone = '2125550199'
        );
        insert existingContact;

        Lead candidate = new Lead(
            Email = '  PERSON@Example.com  ',
            Phone = '(212) 555-0100',
            MobilePhone = '212 (555) 0199'
        );

        Test.startTest();
        List<LeadDuplicateDetectionService.LeadMatch> matches =
            LeadDuplicateDetectionService.findMatches(new List<Lead>{ candidate });
        Test.stopTest();

        LeadDuplicateDetectionService.LeadMatch leadMatch = findMatch(matches, existingLead.Id);
        LeadDuplicateDetectionService.LeadMatch contactMatch = findMatch(matches, existingContact.Id);
        System.assertNotEquals(null, leadMatch, 'A case- and whitespace-normalized email should match another Lead.');
        System.assert(leadMatch.matchedFields.contains('Email'), 'The Lead result should identify Email as the matched field.');
        System.assertNotEquals(null, contactMatch, 'Formatted phone values should match the corresponding Contact fields.');
        System.assert(contactMatch.matchedFields.contains('Phone'), 'The Contact result should identify Phone as matched.');
        System.assert(contactMatch.matchedFields.contains('MobilePhone'), 'The Contact result should identify Mobile Phone as matched.');

        Lead unchangedLead = [SELECT Email, Phone, MobilePhone FROM Lead WHERE Id = :existingLead.Id];
        Contact unchangedContact = [SELECT Email, Phone, MobilePhone FROM Contact WHERE Id = :existingContact.Id];
        System.assertEquals('person@example.com', unchangedLead.Email, 'Matching must not modify the existing Lead email.');
        System.assertEquals('4155550100', unchangedLead.Phone, 'Matching must not modify the existing Lead phone.');
        System.assertEquals('4155550199', unchangedLead.MobilePhone, 'Matching must not modify the existing Lead mobile phone.');
        System.assertEquals('other@example.com', unchangedContact.Email, 'Matching must not modify the existing Contact email.');
        System.assertEquals('2125550100', unchangedContact.Phone, 'Matching must not modify the existing Contact phone.');
        System.assertEquals('2125550199', unchangedContact.MobilePhone, 'Matching must not modify the existing Contact mobile phone.');
    }

    @isTest
    static void testBlankValuesNoMatchSelfExclusionAndCountryCodeDigits() {
        Lead existingLead = new Lead(
            LastName = 'Self Lead',
            Company = 'Example Co',
            Email = 'self@example.com',
            Phone = '+1 (415) 555-0100'
        );
        insert existingLead;

        Contact differentCountryCode = new Contact(
            LastName = 'Country Code Contact',
            Phone = '+44 (415) 555-0100'
        );
        insert differentCountryCode;

        List<LeadDuplicateDetectionService.LeadMatch> selfMatches =
            LeadDuplicateDetectionService.findMatches(new List<Lead>{
                new Lead(Id = existingLead.Id, Email = 'SELF@example.com', Phone = '1-415-555-0100')
            });
        System.assertEquals(0, selfMatches.size(), 'The current Lead must be excluded from its own results.');

        List<LeadDuplicateDetectionService.LeadMatch> blankMatches =
            LeadDuplicateDetectionService.findMatches(new List<Lead>{ new Lead(Email = '  ') });
        System.assertEquals(0, blankMatches.size(), 'Blank email by itself must not produce a duplicate result.');

        List<LeadDuplicateDetectionService.LeadMatch> noMatch =
            LeadDuplicateDetectionService.findMatches(new List<Lead>{
                new Lead(Email = 'absent@example.com', Phone = '9995550100', MobilePhone = '9995550199')
            });
        System.assertEquals(0, noMatch.size(), 'Values without an existing match must produce no results.');

        List<LeadDuplicateDetectionService.LeadMatch> differentDigits =
            LeadDuplicateDetectionService.findMatches(new List<Lead>{ new Lead(Phone = '415-555-0100') });
        System.assertEquals(0, differentDigits.size(), 'Phone comparison must preserve country-code digits and compare exactly.');

        System.assertEquals(0, LeadDuplicateDetectionService.findMatches(null).size(), 'A null candidate list must be handled safely.');
        System.assertEquals(0, LeadDuplicateDetectionService.findMatches(new List<Lead>{ null }).size(), 'A null candidate entry must be handled safely.');
        System.assertEquals(0, LeadDuplicateDetectionService.findMatchesForChangedLeads(null, null).size(), 'Null update candidates must be handled safely.');
    }

    @isTest
    static void testPhoneMatchWorksWhenEmailIsBlank() {
        Contact existingContact = new Contact(LastName = 'Phone Contact', Phone = '6505550100');
        insert existingContact;

        List<LeadDuplicateDetectionService.LeadMatch> matches =
            LeadDuplicateDetectionService.findMatches(new List<Lead>{ new Lead(Phone = '(650) 555-0100') });

        System.assertEquals(1, matches.size(), 'A matching nonblank phone must warn independently of blank email.');
        System.assertEquals(existingContact.Id, matches[0].recordId, 'The phone match should identify the accessible Contact.');
        System.assert(matches[0].matchedFields.contains('Phone'), 'The result should identify Phone as the matched field.');
    }

    @isTest
    static void testChangedFieldFilteringAndLeadUpdateTriggerPaths() {
        Contact target = new Contact(LastName = 'Update Target', Email = 'updated@example.com', Phone = '3035550100');
        insert target;
        Lead candidate = new Lead(LastName = 'Update Candidate', Company = 'Example Co', Email = 'before@example.com');
        insert candidate;

        Lead prior = new Lead(Id = candidate.Id, Email = 'before@example.com', Phone = null, MobilePhone = null);
        Lead changed = new Lead(Id = candidate.Id, Email = ' UPDATED@example.com ', Phone = null, MobilePhone = null);
        List<LeadDuplicateDetectionService.LeadMatch> changedMatches =
            LeadDuplicateDetectionService.findMatchesForChangedLeads(
                new List<Lead>{ changed }, new Map<Id, Lead>{ candidate.Id => prior }
            );
        System.assertEquals(1, changedMatches.size(), 'A changed email should find its normalized Contact match.');
        System.assertEquals(target.Id, changedMatches[0].recordId, 'The changed-field result should identify the matching Contact.');

        List<LeadDuplicateDetectionService.LeadMatch> unchangedMatches =
            LeadDuplicateDetectionService.findMatchesForChangedLeads(
                new List<Lead>{ prior }, new Map<Id, Lead>{ candidate.Id => prior }
            );
        System.assertEquals(0, unchangedMatches.size(), 'Unchanged Email, Phone, and MobilePhone should not be checked.');

        candidate.Email = 'updated@example.com';
        update candidate;
        candidate.Description = 'Unrelated field update';
        update candidate;

        Lead updatedCandidate = [SELECT Email, Description FROM Lead WHERE Id = :candidate.Id];
        Contact unchangedTarget = [SELECT Email, Phone FROM Contact WHERE Id = :target.Id];
        System.assertEquals('updated@example.com', updatedCandidate.Email, 'A relevant update should still save the candidate Lead.');
        System.assertEquals('Unrelated field update', updatedCandidate.Description, 'An unrelated update should save normally.');
        System.assertEquals('updated@example.com', unchangedTarget.Email, 'Duplicate checking must not change the matching Contact.');
        System.assertEquals('3035550100', unchangedTarget.Phone, 'Duplicate checking must not change the matching Contact phone.');
    }

    @isTest
    static void testBulk200CandidatesAndInsertTrigger() {
        List<Contact> contacts = new List<Contact>();
        List<Lead> candidates = new List<Lead>();
        for (Integer index = 0; index < 200; index++) {
            String suffix = String.valueOf(index).leftPad(4, '0');
            String digits = '202555' + suffix;
            contacts.add(new Contact(LastName = 'Bulk Contact ' + suffix, Phone = digits));
            candidates.add(new Lead(
                LastName = 'Bulk Lead ' + suffix,
                Company = 'Example Co',
                Phone = '(202) 555-' + suffix
            ));
        }
        insert contacts;

        Test.startTest();
        insert candidates;
        List<LeadDuplicateDetectionService.LeadMatch> matches = LeadDuplicateDetectionService.findMatches(candidates);
        Test.stopTest();

        System.assertEquals(200, matches.size(), 'Bulk matching should return one Contact match for each of 200 candidates.');
        System.assertEquals(200, [SELECT count() FROM Lead WHERE LastName LIKE 'Bulk Lead%'], 'The after-insert trigger should allow every candidate to save.');
        System.assertEquals(200, [SELECT count() FROM Contact WHERE LastName LIKE 'Bulk Contact%'], 'Bulk matching must not delete existing Contacts.');
    }

    @isTest
    static void testMatchesAreLimitedToRecordsVisibleInRunAsContext() {
        User runningUser = new User(
            Alias = 'duptest',
            Email = 'duplicate.tester@example.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Duplicate Tester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            ProfileId = UserInfo.getProfileId(),
            Username = 'duplicate.tester.' + UserInfo.getOrganizationId() + '.' + System.now().getTime() + '@example.test'
        );
        insert runningUser;

        System.runAs(runningUser) {
            Contact visibleContact = new Contact(LastName = 'Visible Contact', Email = 'visible@example.com');
            insert visibleContact;

            List<LeadDuplicateDetectionService.LeadMatch> matches =
                LeadDuplicateDetectionService.findMatches(new List<Lead>{ new Lead(Email = 'VISIBLE@example.com') });

            System.assertEquals(1, matches.size(), 'The current user should receive an accessible matching Contact.');
            System.assertEquals(visibleContact.Id, matches[0].recordId, 'The service should return the accessible Contact identifier.');
            System.assertEquals('Contact', matches[0].recordType, 'The service should identify the visible result type.');
        }
    }

    private static LeadDuplicateDetectionService.LeadMatch findMatch(
        List<LeadDuplicateDetectionService.LeadMatch> matches,
        Id recordId
    ) {
        for (LeadDuplicateDetectionService.LeadMatch match : matches) {
            if (match.recordId == recordId) {
                return match;
            }
        }
        return null;
    }
}
