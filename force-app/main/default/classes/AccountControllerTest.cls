@isTest
public class AccountControllerTest {

    @isTest
    static void testDisplayAccounts(){
        Account acc1 = new Account(Name = 'Account 1', Phone = '1234567890', Industry = 'Technology');
        Account acc2 = new Account(Name = 'Account 2', Phone = '8732239840', Industry = 'Finance');
        insert new List<Account>{ acc1, acc2 };
            
        Test.startTest();
        List<Account> accounts = AccountController.displayAccounts();
        Test.stopTest();
        
        system.assertEquals(2,accounts.size());
    }
    
    @isTest
    static void testGetIndustryPicklistValues() {
        Test.startTest();
        List<String> industries = AccountController.getIndustryPicklistValues();
        Test.stopTest();

        System.assert(industries.contains('Technology'), 'The picklist values should include "Technology".');
    }
    
    @isTest
    public static void testCreateAccount(){
        
        Account a=new Account(Name='Sahil',Industry='Mobile',Phone='7845863');
       
        Test.startTest();
        
        AccountController.createRecord(a);
        
        Test.stopTest();
        
       Account accObject=[SELECT Id,Name From Account WHERE Id=:a.Id];
        system.assertEquals(accObject.Id,a.Id,'Account Does not Created');
    }
    
    @isTest
    public static void testCreateAccountNegative(){
       
        Test.startTest();
        
      
        try{
         AccountController.createRecord(null);
            System.assert(false, 'Expected exception was not thrown.');
        }
        catch(Exception e){
           system.assert(true,'Exception occurs'+e.getMessage());
        }
      
        Test.stopTest();
     
    }
    
    @isTest
    public static void testUpdateAccount(){
        
        Account acc=new Account();
        acc.Name='Mahi';
        insert acc;
        
        
        acc.Name='Nikhil';
        
        Test.startTest();
        AccountController.updateAccount(acc);
    
        Test.stopTest();
        
        Account accObject=[SELECT Name From Account WHERE Id=:acc.Id];
        system.assertEquals('Nikhil',accObject.Name,'Account Not Updated');
    }
    
    @isTest
    public static void testUpdateAccountNegative(){
        
        Test.startTest();
        
        try{
        AccountController.updateAccount(null);
            System.assert(false, 'Expected exception was not thrown.');
        }
        catch(Exception e){
            System.assert(true,'Exception'+e.getMessage());
        }
        Test.stopTest();
    }
    

    
     @isTest
	static void testDeleteRecord() {
    Account acc = new Account(Name = 'Raju', Phone = '1234567890', Industry = 'Technology');
    insert acc;
    

    Test.startTest();
    AccountController.deleteRecord(acc.Id);
    Test.stopTest();
    

    Integer accountCount = [SELECT COUNT() FROM Account WHERE Id = :acc.Id];
    System.assertEquals(0, accountCount, 'Account should be deleted');
}


}