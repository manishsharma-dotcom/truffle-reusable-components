trigger TF_EX_ContentVersionAutoDistribute on ContentVersion (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        MindTouch_Config__mdt config = [
            SELECT SiteURL__c,matchingPattern__c, TriggerActive__c
            FROM MindTouch_Config__mdt where DeveloperName = 'siteURL'
            LIMIT 1
        ];
        if(config != null && config.TriggerActive__c){
            TF_EX_ContentVersionAutoDistributeHelper.createPublicLinks(Trigger.new);
        }
    }
}