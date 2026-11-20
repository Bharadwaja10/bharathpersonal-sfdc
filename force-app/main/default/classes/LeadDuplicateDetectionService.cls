public with sharing class LeadDuplicateDetectionService {
    /**
     * Returns one generic duplicate indicator for each supplied Lead, in the same order.
     * Candidate record fields and identifiers are used only inside this service and are
     * never returned to callers.
     */
    public static List<Boolean> findPotentialDuplicates(List<Lead> leadsToCheck) {
        List<Boolean> duplicateFlags = new List<Boolean>();
        Map<String, Set<Integer>> emailIndexes = new Map<String, Set<Integer>>();
        Map<String, Set<Integer>> phoneIndexes = new Map<String, Set<Integer>>();

        if (leadsToCheck == null || leadsToCheck.isEmpty()) {
            return duplicateFlags;
        }

        for (Integer i = 0; i < leadsToCheck.size(); i++) {
            duplicateFlags.add(false);
            Lead inputLead = leadsToCheck[i];
            if (inputLead == null) {
                continue;
            }

            addIndex(emailIndexes, normalize(inputLead.Email), i);
            addIndex(phoneIndexes, normalize(inputLead.Phone), i);
            addIndex(phoneIndexes, normalize(inputLead.MobilePhone), i);
        }

        if (emailIndexes.isEmpty() && phoneIndexes.isEmpty()) {
            return duplicateFlags;
        }

        List<Lead> matchingLeads = queryMatchingLeads(emailIndexes.keySet(), phoneIndexes.keySet());
        for (Lead candidate : matchingLeads) {
            markLeadMatch(candidate.Id, normalize(candidate.Email), emailIndexes,
                duplicateFlags, leadsToCheck);
            markLeadMatch(candidate.Id, normalize(candidate.Phone), phoneIndexes,
                duplicateFlags, leadsToCheck);
            markLeadMatch(candidate.Id, normalize(candidate.MobilePhone), phoneIndexes,
                duplicateFlags, leadsToCheck);
        }

        List<Contact> matchingContacts = queryMatchingContacts(emailIndexes.keySet(), phoneIndexes.keySet());
        for (Contact candidate : matchingContacts) {
            markContactMatch(normalize(candidate.Email), emailIndexes, duplicateFlags);
            markContactMatch(normalize(candidate.Phone), phoneIndexes, duplicateFlags);
            markContactMatch(normalize(candidate.MobilePhone), phoneIndexes, duplicateFlags);
            markContactMatch(normalize(candidate.HomePhone), phoneIndexes, duplicateFlags);
            markContactMatch(normalize(candidate.OtherPhone), phoneIndexes, duplicateFlags);
            markContactMatch(normalize(candidate.AssistantPhone), phoneIndexes, duplicateFlags);
        }

        return duplicateFlags;
    }

    private static void addIndex(Map<String, Set<Integer>> indexes, String value, Integer inputIndex) {
        if (value == null) {
            return;
        }
        if (!indexes.containsKey(value)) {
            indexes.put(value, new Set<Integer>());
        }
        indexes.get(value).add(inputIndex);
    }

    private static String normalize(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String normalizedValue = value.trim().toLowerCase();
        return String.isBlank(normalizedValue) ? null : normalizedValue;
    }

    private static List<Lead> queryMatchingLeads(Set<String> emailValues, Set<String> phoneValues) {
        List<String> predicates = new List<String>();
        Map<String, Object> bindValues = new Map<String, Object>();
        addPredicates('Email', emailValues, predicates, bindValues);
        addPredicates('Phone', phoneValues, predicates, bindValues);
        addPredicates('MobilePhone', phoneValues, predicates, bindValues);

        if (predicates.isEmpty()) {
            return new List<Lead>();
        }

        String queryText = 'SELECT Id, Email, Phone, MobilePhone FROM Lead WHERE (' +
            String.join(predicates, ' OR ') + ')';
        return (List<Lead>) Database.queryWithBinds(queryText, bindValues, AccessLevel.USER_MODE);
    }

    private static List<Contact> queryMatchingContacts(Set<String> emailValues, Set<String> phoneValues) {
        List<String> predicates = new List<String>();
        Map<String, Object> bindValues = new Map<String, Object>();
        addPredicates('Email', emailValues, predicates, bindValues);
        addPredicates('Phone', phoneValues, predicates, bindValues);
        addPredicates('MobilePhone', phoneValues, predicates, bindValues);
        addPredicates('HomePhone', phoneValues, predicates, bindValues);
        addPredicates('OtherPhone', phoneValues, predicates, bindValues);
        addPredicates('AssistantPhone', phoneValues, predicates, bindValues);

        if (predicates.isEmpty()) {
            return new List<Contact>();
        }

        String queryText = 'SELECT Id, Email, Phone, MobilePhone, HomePhone, OtherPhone, AssistantPhone ' +
            'FROM Contact WHERE (' + String.join(predicates, ' OR ') + ')';
        return (List<Contact>) Database.queryWithBinds(queryText, bindValues, AccessLevel.USER_MODE);
    }

    private static void addPredicates(
        String fieldName,
        Set<String> values,
        List<String> predicates,
        Map<String, Object> bindValues
    ) {
        for (String value : values) {
            String bindName = 'matchValue' + bindValues.size();
            predicates.add(fieldName + ' LIKE :' + bindName);
            bindValues.put(bindName, '%' + value + '%');
        }
    }

    private static void markLeadMatch(
        Id candidateId,
        String candidateValue,
        Map<String, Set<Integer>> indexes,
        List<Boolean> duplicateFlags,
        List<Lead> leadsToCheck
    ) {
        if (candidateValue == null || !indexes.containsKey(candidateValue)) {
            return;
        }
        for (Integer inputIndex : indexes.get(candidateValue)) {
            Lead inputLead = leadsToCheck[inputIndex];
            if (inputLead == null || inputLead.Id != candidateId) {
                duplicateFlags[inputIndex] = true;
            }
        }
    }

    private static void markContactMatch(
        String candidateValue,
        Map<String, Set<Integer>> indexes,
        List<Boolean> duplicateFlags
    ) {
        if (candidateValue == null || !indexes.containsKey(candidateValue)) {
            return;
        }
        for (Integer inputIndex : indexes.get(candidateValue)) {
            duplicateFlags[inputIndex] = true;
        }
    }
}
