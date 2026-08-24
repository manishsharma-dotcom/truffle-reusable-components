import { LightningElement, track, api } from "lwc";
import GetData from "@salesforce/apex/SSV_PortalCaseCollaboratorController.getData";
import RemoveColab from "@salesforce/apex/SSV_PortalCaseCollaboratorController.removeColabFromCase";
import AddColab from "@salesforce/apex/SSV_PortalCaseCollaboratorController.addColabOnCase";

export default class SSV_CaseCollaboratorCC extends LightningElement {
  @track showSpinner = false;
  @track CollabInputvalue = "";
  @track ExistingCollab = [];
  CanAddCollab = true;
  @api recordId;
  @track buttonclicked = false;
  async connectedCallback() {
    GetData({ recordId: this.recordId })
      .then((result) => {
        console.log(result);

        this.ExistingCollab = [];

        for (let i = 0; i < result.length; i++) {
          if (result[i].email) {
            this.ExistingCollab.push(result[i]);
          }
          //Do something
        }
        if (this.ExistingCollab.length < 5) {
          this.CanAddCollab = true;
        }
      })
      .catch(() => {});
  }

  handleInputChangeEmail(data) {
    // eslint-disable-next-line no-useless-escape
    const emailRegex =
      /^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}))$/;
    if (data.match(emailRegex)) {
      return true;
    }
    return false;
  }

  handleInputChange(event) {
    let fieldname = event.target.dataset.name;
    let value = event.target.value;
    let ele = this.template.querySelector('[data-name="' + fieldname + '"]');
    if (fieldname === "CollabInput") {
      let valid = this.handleInputChangeEmail(value);
      if (valid) {
        // this.CallSaveCollab(value);
        ele.setCustomValidity("");
      } else {
        ele.setCustomValidity("Please enter valid email");
      }
      ele.reportValidity();
    }
  }
  DeleteCollab(event) {
    let cdid = event.target.dataset.id;
    this.showSpinner = true;
    this.buttonclicked = true;
    RemoveColab({ recordId: this.recordId, fieldNumber: cdid })
      .then((result) => {
        if (result) {
          this.ExistingCollab = [];

          for (let i = 0; i < result.length; i++) {
            if (result[i].email) {
              this.ExistingCollab.push(result[i]);
            }
          }
          if (this.ExistingCollab.length < 5) {
            this.CanAddCollab = true;
          } else {
            this.CanAddCollab = false;
          }
        }
        this.showSpinner = false;
        this.buttonclicked = false;
      })
      .catch(() => {
        this.showSpinner = false;
        this.buttonclicked = false;
      });
  }

  AddCc() {
    this.buttonclicked = true;
    let IsValidData = true;

    let FormTypeEle = this.template.querySelector('[data-name="CollabInput"]');
    console.log("1>>>>" + FormTypeEle.value);

    if (!FormTypeEle.value && FormTypeEle.value.trim() === "") {
      this.buttonclicked = false;
      return;
    }
    FormTypeEle.setCustomValidity("");
    if (!this.handleInputChangeEmail(FormTypeEle.value)) {
      FormTypeEle.setCustomValidity("Please add a valid email");
      IsValidData = false;
    } else {
      FormTypeEle.setCustomValidity("");
    }
    FormTypeEle.reportValidity();

    for (let i = 0; i < this.ExistingCollab.length; i++) {
      console.log(this.ExistingCollab[i].email);
      console.log(FormTypeEle.value);

      if (this.ExistingCollab[i].email === FormTypeEle.value) {
        IsValidData = false;
        FormTypeEle.setCustomValidity("Collaborator already exisits");
        FormTypeEle.reportValidity();
      }
      //Do something
    }

    if (IsValidData) {
      this.CallSaveCollab(FormTypeEle.value);
    }else{
      this.buttonclicked = false;
    }
  }
  CallSaveCollab(value) {
    this.buttonclicked = true;
    this.showSpinner = true;

    AddColab({ recordId: this.recordId, email: value })
      .then((result) => {
        if (result) {
          this.ExistingCollab = [];
          for (let i = 0; i < result.length; i++) {
            if (result[i].email) {
              this.ExistingCollab.push(result[i]);
            }
            //Do something
          }
          if (this.ExistingCollab.length < 5) {
            this.CanAddCollab = true;
          } else {
            this.CanAddCollab = false;
          }
        }
        this.CollabInputvalue = "";
        let FormTypeEle = this.template.querySelector('[data-name="CollabInput"]');
        FormTypeEle.value='';
        this.showSpinner = false;
        this.buttonclicked = false;
      })
      .catch((error) => {
        if (error) {
          this.showSpinner = false;
          this.buttonclicked = false;
        }
      });
  }
}