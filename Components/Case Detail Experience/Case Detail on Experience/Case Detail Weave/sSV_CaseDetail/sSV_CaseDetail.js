import { LightningElement, api, track } from 'lwc';

import FetchCaseForm from '@salesforce/apex/SSV_PortalFetchCaseDetails.fetchCaseFormType';

import CaseNumber from '@salesforce/schema/Case.CaseNumber';
import SuppliedEmail from '@salesforce/schema/Case.SuppliedEmail';
import Description from '@salesforce/schema/Case.Description';
import Subject from '@salesforce/schema/Case.Subject';
import OfficePhoneNumber__c from '@salesforce/schema/Case.SSV_OfficePhoneNumber__c';
import Phone__c from '@salesforce/schema/Case.SSV_Phone__c';
import Weave_User_Email__c from '@salesforce/schema/Case.SSV_WeaveUserEmail__c';
import PhoneTreeActive__c from '@salesforce/schema/Case.SSV_PhoneTreeActive__c';
import CallQueueGreeting__c from '@salesforce/schema/Case.SSV_CallQueueGreeting__c';
import CallQueueName__c from '@salesforce/schema/Case.SSV_CallQueueName__c';
import OfficeName__c from '@salesforce/schema/Case.SSV_OfficeName__c';
import CallQueueFallbackOption__c from '@salesforce/schema/Case.SSV_CallQueueFallbackOption__c';
import CallQueueRoutingType__c from '@salesforce/schema/Case.SSV_CallQueueRoutingType__c';
import CallQueuePhoneAssignment__c from '@salesforce/schema/Case.SSV_CallQueuePhoneAssignment__c';
import CallQueueEscape__c from '@salesforce/schema/Case.SSV_CallQueueEscape__c';
import CallQueueHoldMusic__c from '@salesforce/schema/Case.SSV_CallQueueHoldMusic__c';
import CallQueuePositionFirstAnnouncement__c from '@salesforce/schema/Case.SSV_CallQueuePositionFirstAnnouncement__c';
import MaximumCallerHoldTime__c from '@salesforce/schema/Case.SSV_MaximumCallerHoldTime__c';
import CallQueueConsiderations__c from '@salesforce/schema/Case.SSV_CallQueueConsiderations__c';
import FirstLastName__c from '@salesforce/schema/Case.SSV_FirstLastName__c';
import ExternalStatusForm__c from '@salesforce/schema/Case.SSV_ExternalStatusForm__c';

// New Ownership Transfer fields
import NewLegalBusinessName__c from '@salesforce/schema/Case.SSV_NewLegalBusinessName__c';
import NewBusinessAddress__c from '@salesforce/schema/Case.SSV_NewBusinessAddress__c';
import EIN__c from '@salesforce/schema/Case.SSV_EIN__c';
import NewSuperAdminEmail__c from '@salesforce/schema/Case.SSV_NewSuperAdminEmail__c';

import CurrentSuperAdminEmail__c from '@salesforce/schema/Case.SSV_Current_Super_Admin_Email__c';
import CurrentSuperAdminName__c from '@salesforce/schema/Case.SSV_Current_Super_Admin_Name__c';
import CurrentBusinessOwnerName__c from '@salesforce/schema/Case.Current_Business_Owner_Name__c';
import CurrentOfficeName__c from '@salesforce/schema/Case.SSV_Current_Office_Name__c';
import CurrentOfficePhone__c from '@salesforce/schema/Case.SSV_Current_Office_Phone_Number__c';
import EmailContactForNewOffice__c from '@salesforce/schema/Case.SSV_Email_Contact_for_New_Office__c';




export default class SSV_CaseDetail extends LightningElement {
    // Expose a field to make it available in the template
    CaseNumber = CaseNumber;
    SuppliedEmail = SuppliedEmail;
    Description = Description;
    Subject = Subject;
    CallQueueConsiderations = CallQueueConsiderations__c;
    Weave_User_Email = Weave_User_Email__c;
    OfficeName = OfficeName__c;
    OfficePhoneNumber = OfficePhoneNumber__c;
    Phone = Phone__c;
    PhoneTreeActive = PhoneTreeActive__c;
    CallQueueName = CallQueueName__c;
    CallQueueRoutingType = CallQueueRoutingType__c;
    CallQueueGreeting = CallQueueGreeting__c;
    CallQueuePhoneAssignment = CallQueuePhoneAssignment__c;
    CallQueueFallbackOption = CallQueueFallbackOption__c;
    CallQueueEscape = CallQueueEscape__c;
    CallQueueHoldMusic = CallQueueHoldMusic__c;
    CallQueuePositionFirstAnnouncement = CallQueuePositionFirstAnnouncement__c;
    MaximumCallerHoldTime = MaximumCallerHoldTime__c;
    CallQueueConsiderations = CallQueueConsiderations__c;

    FirstLastName = FirstLastName__c;
    ExternalStatusForm = ExternalStatusForm__c;

    // NEW: ownership transfer fields exposed for template
    NewLegalBusinessName = NewLegalBusinessName__c;
    NewBusinessAddress = NewBusinessAddress__c;
    EIN = EIN__c;
    NewSuperAdminEmail = NewSuperAdminEmail__c;


    // Newly added flags - tracked values
    CurrentSuperAdminEmail = CurrentSuperAdminEmail__c;
    CurrentSuperAdminName = CurrentSuperAdminName__c;
    CurrentBusinessOwnerName = CurrentBusinessOwnerName__c;
    CurrentOfficeName = CurrentOfficeName__c;
    CurrentOfficePhone = CurrentOfficePhone__c;
    EmailContactForNewOffice = EmailContactForNewOffice__c;
    



    // Flexipage provides recordId and objectApiName
    @api recordId;
    @api objectApiName;
    @track FormType;
    @track ErrorMessage;
    @track ValidCase = false;

    @track isNWW = false;
    @track isPC = false;
    @track isSR = false;
    @track isESR = false;
    @track isPCQSR = false;
    // --- NEW flag
    @track isOwnershipTransfer = false;

    connectedCallback() {
        this.objectApiName = 'Case';

        console.log(this.recordId);        

        FetchCaseForm({ recordId: this.recordId })
            .then(result => {

                if (result && result == 'Case Not Found') {
                    this.ErrorMessage = 'Case Not Found';
                } else if (result) {
                    this.ValidCase = true;
                    this.FormType = result;

                    // reset all flags first (safety)
                    this.isNWW = false;
                    this.isPC = false;
                    this.isSR = false;
                    this.isESR = false;
                    this.isPCQSR = false;
                    this.isOwnershipTransfer = false;

                    if (this.FormType == 'New Weave Workspace' || this.FormType == 'New Workspace' || this.FormType == 'Billing') {
                        this.isNWW = true;
                    } else if (this.FormType == 'Payment Contact Us') {
                        this.isPC = true;
                    }
                    else if (this.FormType == 'Support Request') {
                        this.isSR = true;
                    } else if (this.FormType == 'Emergency After Hours') {
                        this.isESR = true;
                    } else if (this.FormType == 'Phone Call Queue') {
                        this.isPCQSR = true;
                    } else if (this.FormType == 'Ownership Transfer') {
                        // --- NEW: set ownership transfer flag
                        this.isOwnershipTransfer = true;
                    }

                    console.log(this.FormType);
                    console.log({
                        isPCQSR: this.isPCQSR,
                        isESR: this.isESR,
                        isSR: this.isSR,
                        isPC: this.isPC,
                        isNWW: this.isNWW,
                        isOwnershipTransfer: this.isOwnershipTransfer
                    });
                }
            })
            .catch(error => {
                if (error) {
                    this.ErrorMessage = 'Case Not Found';
                }
            })
    }
}