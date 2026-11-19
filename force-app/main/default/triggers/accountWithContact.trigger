/*Practice Question:
Write a trigger on the Account object to automatically create a related Contact whenever an Account is created, and populate the following fields in the Contact:
*/

trigger accountWithContact on Account(After insert){
    list<Contact> con= new List<Contact>();
    
    if(Trigger.isInsert){
        for(Account acc:Trigger.new){
            if (acc.Phone != '' && acc.Phone != null){
            Contact c=new Contact();
            c.LastName = 'Primary Contact';
            c.Phone = acc.Phone;
            con.add(c);
            }
            else{
        system.debug('know the contact number before entering to the contact');
    }
        }
        
    }
    insert con;
    
}