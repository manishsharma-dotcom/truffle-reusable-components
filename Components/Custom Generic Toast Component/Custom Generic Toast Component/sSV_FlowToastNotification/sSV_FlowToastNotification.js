import { api, LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
export default class SSV_FlowToastNotification extends LightningElement {

    @api title;
    /* Title of the toast */
    @api message;
    @api variant;
    @api delay;
    /* Delay of the toast in milliseconds */
    @api recordName;
    /* Name of the record which will be displayed over the toast message */
    @api url;
    /* URL of the record where user will be redirected when user clicks on the url */
    @api actionLabel;
    /* Label of the clickable button. For Example Click Here, or Here */

    connectedCallback(){
        setTimeout(() => {
        window.open('/lightning/o/Case/list?filterName=__Recent', '_self');
        }, 3000);
    }

    renderedCallback(){
        this.template.querySelector('c-common-toast').showToast('success','Enter Valid Email and License Id','utility:warning',10000);
    }

    @api
    showToast() {
        const event = new ShowToastEvent({
            title: 'Get Help',
            message:
                'Salesforce documentation is available in the app. Click ? in the upper-right corner.',
        });
        this.dispatchEvent(event);
    }

    showToastMessage = (self) => {
        let toastMessage = {
            title: this.title,
            message: this.message,
            variant: this.variant?this.variant:'info'
        };
        if(this.delay){
            setTimeout(() => {
                this.fireToastMessage(toastMessage);
            } , this.delay);
        }else{
            self.fireToastMessage(toastMessage);
        }
    }

    fireToastMessage = (toastMessage) => {
        window.console.log('Toast Message: ', toastMessage);
        this.dispatchEvent(new ShowToastEvent(toastMessage) );
    }
}