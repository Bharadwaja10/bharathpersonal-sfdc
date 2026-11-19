trigger DefualtIndustry on Account (before insert) {
    for (Account acc : Trigger.new) {
        if (acc.Industry == null) {
            acc.Industry = 'Technology';
            System.debug('this is updated');
        }
    }

}