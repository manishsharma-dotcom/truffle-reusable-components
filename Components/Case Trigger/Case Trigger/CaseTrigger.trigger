/************************************************************************************************
* Author: Deepak Sharma
* Date: Feb 03, 2023
* Description: Single entry point for all custom trigger logic on the Case standard object.
**************************************************************************************************/
trigger CaseTrigger on Case (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    
    if(!FeatureManagement.checkPermission('skipTrigger')) TriggerService.onTrigger();
}