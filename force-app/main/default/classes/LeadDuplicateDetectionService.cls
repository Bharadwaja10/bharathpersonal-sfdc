public with sharing class LeadDuplicateDetectionService {
    private static Boolean triggerCheckInProgress = false;

    /** Entry point for the Lead trigger with transaction-level recursion protection. */
    public static void checkFromTrigger(List<Lead> candidates, Map<Id, Lead> priorValuesById) {
        if (triggerCheckInProgress || candidates == null || candidates.isEmpty()) {
            return;
        }

        triggerCheckInProgress = true;
        try {
            if (priorValuesById == null) {
                findMatches(candidates);
            } else {
                findMatchesForChangedLeads(candidates, priorValuesById);
            }
        } finally {
            triggerCheckInProgress = false;
        }
    }

    public class LeadMatch {
        @AuraEnabled public Id candidateLeadId { get; private set; }
        @AuraEnabled public Id recordId { get; private set; }
        @AuraEnabled public String recordType { get; private set; }
        @AuraEnabled public String recordName { get; private set; }
        @AuraEnabled public List<String> matchedFields { get; private set; }

        public LeadMatch(Id candidateLeadId, Id recordId, String recordType, String recordName, Set<String> matchedFields) {
            this.candidateLeadId = candidateLeadId;
            this.recordId = recordId;
            this.recordType = recordType;
            this.recordName = recordName;
            this.matchedFields = new List<String>(matchedFields);
            this.matchedFields.sort();
        }
    }

    private class CandidateValues {
        Id leadId;
        Set<String> keys = new Set<String>();

        CandidateValues(Lead candidate, Lead priorValue) {
            leadId = candidate.Id;
            if (priorValue == null || hasFieldChanged(candidate.Email, priorValue.Email)) {
                addKey(keys, 'Email', normalizeEmail(candidate.Email));
            }
            if (priorValue == null || hasFieldChanged(candidate.Phone, priorValue.Phone)) {
                addKey(keys, 'Phone', normalizePhone(candidate.Phone));
            }
            if (priorValue == null || hasFieldChanged(candidate.MobilePhone, priorValue.MobilePhone)) {
                addKey(keys, 'MobilePhone', normalizePhone(candidate.MobilePhone));
            }
        }
    }

    /**
     * Find visible Leads and Contacts that match candidate Leads. Pass new Leads for insert
     * candidates; callers handling updates can use findMatchesForChangedLeads instead.
     */
    public static List<LeadMatch> findMatches(List<Lead> candidates) {
        return findMatchesInternal(candidates, null);
    }

    /** Find matches only for update candidates whose Email, Phone, or MobilePhone changed. */
    public static List<LeadMatch> findMatchesForChangedLeads(List<Lead> candidates, Map<Id, Lead> priorValuesById) {
        return findMatchesInternal(candidates, priorValuesById);
    }

    public static String normalizeEmail(String value) {
        return String.isBlank(value) ? null : value.trim().toLowerCase();
    }

    public static String normalizePhone(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String digitsOnly = value.replaceAll('[^0-9]', '');
        return String.isBlank(digitsOnly) ? null : digitsOnly;
    }

    private static List<LeadMatch> findMatchesInternal(List<Lead> candidates, Map<Id, Lead> priorValuesById) {
        List<LeadMatch> matches = new List<LeadMatch>();
        if (candidates == null || candidates.isEmpty()) {
            return matches;
        }

        List<CandidateValues> candidateValues = new List<CandidateValues>();
        Set<String> requestedKeys = new Set<String>();
        for (Lead candidate : candidates) {
            if (candidate == null) {
                continue;
            }
            Lead priorValue = priorValuesById == null || candidate.Id == null
                ? null
                : priorValuesById.get(candidate.Id);
            CandidateValues values = new CandidateValues(candidate, priorValue);
            if (!values.keys.isEmpty()) {
                candidateValues.add(values);
                requestedKeys.addAll(values.keys);
            }
        }
        if (requestedKeys.isEmpty()) {
            return matches;
        }

        // Formatting cannot be normalized in SOQL. Query only records visible to this user,
        // then compare normalized values in memory so punctuation and surrounding spaces match exactly.
        Map<String, Map<Id, LeadMatch>> visibleMatchesByKey = new Map<String, Map<Id, LeadMatch>>();
        for (Lead existingLead : [
            SELECT Id, Name, Email, Phone, MobilePhone
            FROM Lead
            WITH USER_MODE
        ]) {
            addVisibleRecord(visibleMatchesByKey, requestedKeys, existingLead.Id, 'Lead', existingLead.Name,
                existingLead.Email, existingLead.Phone, existingLead.MobilePhone);
        }
        for (Contact existingContact : [
            SELECT Id, Name, Email, Phone, MobilePhone
            FROM Contact
            WITH USER_MODE
        ]) {
            addVisibleRecord(visibleMatchesByKey, requestedKeys, existingContact.Id, 'Contact', existingContact.Name,
                existingContact.Email, existingContact.Phone, existingContact.MobilePhone);
        }

        for (CandidateValues values : candidateValues) {
            Map<Id, LeadMatch> candidateMatches = new Map<Id, LeadMatch>();
            for (String key : values.keys) {
                Map<Id, LeadMatch> recordsForKey = visibleMatchesByKey.get(key);
                if (recordsForKey == null) {
                    continue;
                }
                for (Id existingId : recordsForKey.keySet()) {
                    if (existingId == values.leadId) {
                        continue;
                    }
                    LeadMatch existingMatch = recordsForKey.get(existingId);
                    LeadMatch candidateMatch = candidateMatches.get(existingId);
                    if (candidateMatch == null) {
                        candidateMatch = new LeadMatch(values.leadId, existingMatch.recordId,
                            existingMatch.recordType, existingMatch.recordName, new Set<String>());
                        candidateMatches.put(existingId, candidateMatch);
                    }
                    candidateMatch.matchedFields.addAll(existingMatch.matchedFields);
                }
            }
            matches.addAll(candidateMatches.values());
        }
        return matches;
    }

    private static void addVisibleRecord(
        Map<String, Map<Id, LeadMatch>> visibleMatchesByKey,
        Set<String> requestedKeys,
        Id recordId,
        String recordType,
        String recordName,
        String email,
        String phone,
        String mobilePhone
    ) {
        addRecordField(visibleMatchesByKey, requestedKeys, recordId, recordType, recordName,
            'Email', normalizeEmail(email));
        addRecordField(visibleMatchesByKey, requestedKeys, recordId, recordType, recordName,
            'Phone', normalizePhone(phone));
        addRecordField(visibleMatchesByKey, requestedKeys, recordId, recordType, recordName,
            'MobilePhone', normalizePhone(mobilePhone));
    }

    private static void addRecordField(
        Map<String, Map<Id, LeadMatch>> visibleMatchesByKey,
        Set<String> requestedKeys,
        Id recordId,
        String recordType,
        String recordName,
        String fieldName,
        String normalizedValue
    ) {
        if (normalizedValue == null) {
            return;
        }
        String key = fieldName + ':' + normalizedValue;
        if (!requestedKeys.contains(key)) {
            return;
        }
        if (!visibleMatchesByKey.containsKey(key)) {
            visibleMatchesByKey.put(key, new Map<Id, LeadMatch>());
        }
        Map<Id, LeadMatch> recordsForKey = visibleMatchesByKey.get(key);
        LeadMatch recordMatch = recordsForKey.get(recordId);
        if (recordMatch == null) {
            recordMatch = new LeadMatch(null, recordId, recordType, recordName, new Set<String>());
            recordsForKey.put(recordId, recordMatch);
        }
        recordMatch.matchedFields.add(fieldName);
    }

    public static Boolean hasFieldChanged(String currentValue, String priorValue) {
        return currentValue == null ? priorValue != null : !currentValue.equals(priorValue);
    }

    private static void addKey(Set<String> keys, String fieldName, String normalizedValue) {
        if (normalizedValue != null) {
            keys.add(fieldName + ':' + normalizedValue);
        }
    }
}
