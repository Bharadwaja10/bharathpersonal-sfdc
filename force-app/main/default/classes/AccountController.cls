public class AccountController {
    @AuraEnabled(cacheable=true)
    public static List<Account> displayAccounts() {
        return [SELECT Id, Name, Phone, Industry FROM Account ORDER BY CreatedDate ASC];
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getIndustryPicklistValues() {
        // Get picklist values for the Industry field
        List<String> picklistValues = new List<String>();
        Schema.DescribeFieldResult fieldResult = Account.Industry.getDescribe();
        List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry entry : picklistEntries) {
            picklistValues.add(entry.getValue());
        }
        return picklistValues;
    }

    @AuraEnabled
    public static void createRecord(Account acc) {
        try{
            insert acc;
        }
        catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }       
        
    }

    @AuraEnabled
    public static void updateAccount(Account acc){
        try {
            update acc;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Account> deleteRecord(String accId) {
        delete [SELECT Id FROM Account WHERE Id = :accId];
        
        return displayAccounts();
    }
}