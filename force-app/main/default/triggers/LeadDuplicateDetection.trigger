trigger LeadDuplicateDetection on Lead (after insert, after update) {
    if (Trigger.isInsert) {
        LeadDuplicateDetectionService.checkFromTrigger(Trigger.new, null);
    } else if (Trigger.isUpdate) {
        List<Lead> changedLeads = new List<Lead>();
        Map<Id, Lead> priorValuesById = new Map<Id, Lead>();

        for (Lead currentLead : Trigger.new) {
            Lead priorLead = Trigger.oldMap.get(currentLead.Id);
            if (LeadDuplicateDetectionService.hasFieldChanged(currentLead.Email, priorLead.Email)
                || LeadDuplicateDetectionService.hasFieldChanged(currentLead.Phone, priorLead.Phone)
                || LeadDuplicateDetectionService.hasFieldChanged(currentLead.MobilePhone, priorLead.MobilePhone)) {
                changedLeads.add(currentLead);
                priorValuesById.put(priorLead.Id, priorLead);
            }
        }

        if (!changedLeads.isEmpty()) {
            LeadDuplicateDetectionService.checkFromTrigger(changedLeads, priorValuesById);
        }
    }
}
