import { LightningElement, track, api } from 'lwc';

export default class SSV_CustomToast extends LightningElement {

    @track visible = false;
    @track message;
    @track variant;
    @track toastcontainer ='slds-notify slds-notify_toast';
    @track variantIcon;
    @api
    showToast(variant, message) {
        this.message = message;
        this.variant = variant;
        this.visible = true;
        console.log('message>>' + this.message);
        console.log('message>>' + this.variant);

        if (this.variant == 'Success') {
            this.toastcontainer = "slds-notify slds-notify_toast" + " successtoast";
            this.variantIcon = 'utility:success';
        }
        if (this.variant == 'Error') {
            this.toastcontainer = "slds-notify slds-notify_toast" + " errortoast";
            this.variantIcon = 'utility:error';

        }
        if (this.variant == 'Warning') {
            this.toastcontainer = "slds-notify slds-notify_toast" + " warningcontainer";
            this.variantIcon = 'utility:warning';

        }
        // Auto-hide after 3 seconds
        setTimeout(() => {
             this.visible = false;
        }, 3000);
    }

    @api closeToast() {
        this.visible = false;
    }
}