trigger LeadDuplicateDetection on Lead (before insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        List<Boolean> duplicateFlags =
            LeadDuplicateDetectionService.findPotentialDuplicates(Trigger.new);

        for (Boolean duplicateFound : duplicateFlags) {
            if (duplicateFound) {
                System.debug(LoggingLevel.WARN, 'A possible duplicate person was found.');
            }
        }
    }
}
