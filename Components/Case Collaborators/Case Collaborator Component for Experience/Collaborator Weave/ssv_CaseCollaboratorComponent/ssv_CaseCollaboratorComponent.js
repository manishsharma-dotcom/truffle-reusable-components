import { LightningElement, api, track, wire } from 'lwc';
import {getRecord, notifyRecordUpdateAvailable} from "lightning/uiRecordApi";
import {RefreshEvent} from "lightning/refresh";
import COLLABORATOR1 from "@salesforce/schema/Case.SSV_Collaborator1__c";
import COLLABORATOR2 from "@salesforce/schema/Case.SSV_Collaborator2__c";
import COLLABORATOR3 from "@salesforce/schema/Case.SSV_Collaborator3__c";
import COLLABORATOR4 from "@salesforce/schema/Case.SSV_Collaborator4__c";
import COLLABORATOR5 from "@salesforce/schema/Case.SSV_Collaborator5__c";
import setupCollaborators from "@salesforce/apex/SSV_CaseCollaboratorController.setupCollaborators";

const fields = [COLLABORATOR1, COLLABORATOR2, COLLABORATOR3, COLLABORATOR4, COLLABORATOR5];

export default class Ssv_CaseCollaboratorComponent extends LightningElement {
    @api recordId;

    @track isLoaded = false;
    @track hasValidInput = true;

    @track collaborator1;
    @track collaborator2;
    @track collaborator3;
    @track collaborator4;
    @track collaborator5;

    get collaboratorsList()
    {
        let ret = [];
        if(this.collaborator1) ret.push(this.collaborator1);
        if(this.collaborator2) ret.push(this.collaborator2);
        if(this.collaborator3) ret.push(this.collaborator3);
        if(this.collaborator4) ret.push(this.collaborator4);
        if(this.collaborator5) ret.push(this.collaborator5);

        console.log("Collaborators:" + JSON.stringify(ret));
        return ret.join(', ');
    }

    @wire(getRecord, {recordId: this.recordId, fields})
    recordSetup({error, data}) {
        console.log("receivedData:" + JSON.stringify(data));
        console.log("Error:" + JSON.stringify(error));

        if(data == null) return;

        this.isLoaded = false;
        this.collaborator1 = data.fields.SSV_Collaborator1__c.value;
        this.collaborator2 = data.fields.SSV_Collaborator2__c.value;
        this.collaborator3 = data.fields.SSV_Collaborator3__c.value;
        this.collaborator4 = data.fields.SSV_Collaborator4__c.value;
        this.collaborator5 = data.fields.SSV_Collaborator5__c.value;

        this.isLoaded = true;
    }

    handleCollaboratorsChange(event)
    {
        let newValue = event.detail.value;
        let inputComponent = this.template.querySelector("lightning-input");
        inputComponent.setCustomValidity("");
        this.hasValidInput = inputComponent.reportValidity();

        if(this.hasValidInput)
        {
            let values = newValue.split(',');
            if(values.length > 5)
            {
                this.hasValidInput = false;
                inputComponent.setCustomValidity("More than 5 collaborators not allowed.");
                inputComponent.reportValidity();
            }
        }
        //console.log("New Value:" + newValue + " isValid:" + this.hasValidInput);
    }

    async handleSave()
    {
        let newValue = this.template.querySelector("lightning-input").value;

        console.log("Saving:" + newValue);

        let affectedRecords = await setupCollaborators({caseId : this.recordId, collaboratorsEmailCSV:newValue});

        let notificationData = [];

        for(const currId of affectedRecords)
        {
            notificationData.push({recordId : currId});
        }

        console.log("Notification:" + JSON.stringify(notificationData));

        await notifyRecordUpdateAvailable(notificationData);

        await this.dispatchEvent(new RefreshEvent());
    }
}