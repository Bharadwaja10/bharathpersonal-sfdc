public with sharing class getRecordDataController {
  @AuraEnabled(cacheable=true)
  public static List<Account> getAccounts() {
      // Query to get accounts
      return [SELECT Id, Name, Phone, Industry FROM Account Limit 10];
  }
}