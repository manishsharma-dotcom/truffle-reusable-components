trigger TF_EX_FeedCommentTrigger on FeedComment (before insert, before update) {
    TF_EX_FeedCommentTriggerHandler.handle(Trigger.new);
}