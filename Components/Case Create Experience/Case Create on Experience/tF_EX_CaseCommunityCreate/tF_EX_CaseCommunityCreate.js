/**
 * caseCommunityCreate.js
 *
 * Two-step modal form that replaces the TF_CaseCreate Screen Flow.
 *
 * Step 1 – Record type selection (radio buttons → Next)
 * Step 2 – Case details form (Back → Submit)
 *
 * Events dispatched to parent (caseListView):
 *   casecreated   → { caseId, caseNumber } — case was successfully created
 *   modalclosed   → no detail            — user cancelled or parent called cancel()
 *
 * Dependent picklists use getPicklistValues from lightning/uiObjectInfoApi
 * which respects record-type-level restrictions natively.
 */
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import CATEGORY_FIELD    from '@salesforce/schema/Case.Contact_Code_Category__c';
import ISSUE_FIELD       from '@salesforce/schema/Case.Contact_Code__c';
import ISSUE_DETAIL_FIELD from '@salesforce/schema/Case.Sub_Contact_Code__c';
import getInitialData    from '@salesforce/apex/TF_EX_CaseCommunityCreateController.getInitialData';
import createCase        from '@salesforce/apex/TF_EX_CaseCommunityCreateController.createCase';
import deleteFiles       from '@salesforce/apex/TF_EX_CaseFileUploadController.deleteFiles';

// Issue Detail values to hide from community users for specific
// Record Type + Category + Issue combinations. Backend dependency is
// left untouched — internal teams still see/use these values elsewhere.
const HIDDEN_ISSUE_DETAILS_BY_CONTEXT = [
    {
        recordTypeDeveloperName: 'Enrollments_Support',
        category               : 'Enrollments',
        issue                  : 'Insurance Enrollments',
        hiddenValues           : ['Child Site Migration']
    }
];

export default class CaseCommunityCreate extends LightningElement {

    MAX_ERA = 5;

    // ── State ─────────────────────────────────────────────────────────────────
    @track step           = 1;
    @track isLoading      = true;
    @track isSubmitting   = false;
    @track _pendingFileIds = [];
    @track _hasUploadingFiles = false;
    @track finalDescription = '';
    @track additionalDescription = '';
    
    //Missing ERAs related fields
    @track missingERASelected = false;
    @track eraSections = [];

    //Error Troubleshooting fields
    @track errorTroubleshootingSelected = false;
    @track warningMessage = 'Please attach a copy of XML Request, Response, and examples in the attachments section.';

    //New Connection fields
    @track newConnectionSelected = false;
    @track admin = false;
    @track keyReason;

    //FHIR fields
    @track fHIRSelected = false;

    //Activation fields
    @track activationSelected = false;
    @track ehrName;

    //Appointment Reminders fields
    @track appReminderSelected = false;
    @track appDate;
    @track patientName = '';

    //Add New Insurance Payer Connection fields
    @track payerConnectionSelected = false;
    @track payerName = '';
    @track payerId = '';
    @track tin ='';

    //Assistance with an Existing Enrollment fields
    @track existingEnrollmentSelected = false;
    @track npi;

    //New Lab Connection fields
    @track labConnectionSelected = false;
    @track labAccountNumber;

    //epcs fields
    @track epcsSelected = false;

    //erx fields
    @track erxSelected = false;

    //add Refill fields
    @track addRefillSelected = false;

    //Template Creation fields
    @track tempCreationSelected = false;
    @track tempCreationWarningMessage = 'Please attach copies of the templates you would like assistance creating in the attachments section.';

    //Template Troubleshooting fields
    @track tempTroubleshootingSelected = false;
    @track tempTroubleshootingWarningMessage = 'Please attach a video of the issue and template name in the attachments section.';

    //University Troubleshooting fields
    @track uniTroubleshootingSelected = false;
    @track uniTroubleshootingWarningMessage = 'Please attach a video of the issue and course name in the attachments section.';

    //Template Training fields
    @track tempTrainingSelected = false;
    @track completedProviderMedicalSelected =false;
    @track completedProviderMedical;
    @track completedTemplateEditor;

    //Custom Paid Training fields
    @track customPaidSelected = false;
    @track completedTraining;

    //ERA Payment Posting fields
    @track paymentPostingSelected = false;
    @track billerTrainingSelected = false;
    @track eraIds;
    @track completedBillerTraining;

    //Advanced Payment Posting fields
    @track advancePaymentSelected = false;
    @track advanceBillerTrainingSelected = false;
    @track advanceBillerTraining400Selected = false;
    
    @track completedAdvanceBillerTraining;
    @track completedAdvanceBillerTraining400;

    //Update name of provider, address, phone fields
    @track updateProviderDetailsSelected = false;
    @track providerName='';
    @track previousProviderName = '';
    @track providerAddress='';
    @track previousProviderAddress = '';
    @track providerPhoneNumber='';
    @track previousProviderPhoneNumber = '';
    @track selectFeature = '';
    
    // ── Step 1 ────────────────────────────────────────────────────────────────
    @track recordTypeOptions    = [];
    @track showRecordTypeError  = false;

    // selectedRecordTypeId drives the wire adapters.
    // Must be null (not '') so wires don't fire with an empty ID.
    @track selectedRecordTypeId = null;

    // ── Step 2 ────────────────────────────────────────────────────────────────
    @track isSingleAccount         = false;
    @track accountOptions          = [];
    @track selectedAccountId       = '';
    @track currentUserEmail        = '';
    @track currentUserContactPhone = '';
    @track currentUserContactId    = '';
    @track caseTeamRoleId          = '';

    // Picklist selections
    @track selectedCategory    = '';
    @track selectedIssue       = '';
    @track selectedIssueDetail = '';
    @track subject             = '';
    @track description         = '';

    // Collaborators
    
    @track selectedCollaboratorIds  = [];
    

    // Validation
    @track showAccountError                  = false;
    @track showCategoryError                 = false;
    @track showIssueError                    = false;
    @track showIssueDetailError              = false;
    @track showSubjectError                  = false;
    @track showDescriptionError              = false;
    @track showAppDateError                  = false;
    @track showPatientNameError              = false;
    @track showEhrNameError                  = false;
    @track showAdminError                    = false;
    @track showKeyReasonError                = false;
    @track showPayerNameError                = false;
    @track showPayerIdError                  = false;
    @track showNpiError                      = false;
    @track showLabAccountNumberError         = false;
    @track showCompletedProviderMedicalError = false;
    @track showCompletedTemplateEditorError  = false;
    @track showCompletedTrainingError        = false;
    @track showCompletedBillerTrainingError  = false;
    @track showCompletedAdvanceBillerTrainingError = false;
    @track showCompletedAdvanceBillerTraining400Error = false;
    @track showEraIdsError = false;
    @track showTinError = false;
    @track showSelectFeatureError = false;

    // Raw picklist wire data
    _categoryWire     = null;
    _issueWire        = null;
    _issueDetailWire  = null;

    // Single-account data (for auto-population)
    _singleAccountId   = null;

    // Window listener for closing collaborator dropdown
    _selectedRecordTypeDeveloperName = null;
    // ── Wire – Picklist Values ─────────────────────────────────────────────────

    @wire(getPicklistValues, {
        recordTypeId  : '$selectedRecordTypeId',
        fieldApiName  : CATEGORY_FIELD
    })
    wiredCategory({ error, data }) {
        if (data)  { this._categoryWire = data;  this._resetPicklistsFromCategory(); }
        if (error) { console.error('Category picklist wire error:', JSON.stringify(error)); }
    }

    @wire(getPicklistValues, {
        recordTypeId  : '$selectedRecordTypeId',
        fieldApiName  : ISSUE_FIELD
    })
    wiredIssue({ error, data }) {
        if (data)  { this._issueWire = data; }
        if (error) { console.error('Issue picklist wire error:', JSON.stringify(error)); }
    }

    @wire(getPicklistValues, {
        recordTypeId  : '$selectedRecordTypeId',
        fieldApiName  : ISSUE_DETAIL_FIELD
    })
    wiredIssueDetail({ error, data }) {
        if (data)  { this._issueDetailWire = data; }
        if (error) { console.error('Issue Detail picklist wire error:', JSON.stringify(error)); }
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    async connectedCallback() {
        this.eraSections = [this.createERA(1)];
        try {
            const data = await getInitialData();
            this._applyInitialData(data);
        } catch (e) {
            this._toast('Failed to load form data. Please refresh and try again.', 'error', 'Error');
        } finally {
            this.isLoading = false;
        }
    }

    disconnectedCallback() {}


    // ── @api methods (called by parent caseListView) ──────────────────────────

    /**
     * Called by parent when the X button is clicked.
     * Cleans up any uploaded files then fires modalclosed.
     */
    @api
    async cancel() {
        await this._cleanupFiles();
        this.dispatchEvent(new CustomEvent('modalclosed'));
    }

    createERA(number) {
        return {
            id: Date.now() + Math.random(),
            displayNumber: number,
            checkDate: '',
            checkNumber: '',
            checkAmount: '',
            showEraCheckDateError:false,
            showEraCheckNumberError:false,
            showEraCheckAmountError:false,
            showRemove: number > 1
        };
    }
    // ── Step 1 Handlers ───────────────────────────────────────────────────────

    handleRecordTypeChange(e) {
    this.selectedRecordTypeId  = e.target.value || null;
    this.showRecordTypeError   = false;
    this._categoryWire        = null;
    this._issueWire           = null;
    this._issueDetailWire     = null;
    this._resetPicklistsFromCategory();
    // Store developer name for Training auto-populate logic
    const rt = this.recordTypeOptions.find(r => r.value === this.selectedRecordTypeId);
    this._selectedRecordTypeDeveloperName = rt ? rt.developerName : null;
}

    handleNext() {
        if (!this.selectedRecordTypeId) {
            this.showRecordTypeError = true;
            return;
        }
        this.step = 2;
    }

    // ── Step 2 Handlers ───────────────────────────────────────────────────────

    async handleBack() {
        await this._cleanupFiles();
        this._resetStep2Form();
        this.step = 1;
    }

    handleAccountChange(e) {
    this.selectedAccountId       = e.target.value;
    this.showAccountError        = false;
    this.selectedCollaboratorIds = [];
    }

    handleCategoryChange(e) {
    this.selectedCategory    = e.target.value;
    this.selectedIssue       = '';
    this.selectedIssueDetail = '';
    this.showCategoryError   = false;
    this.showIssueError      = false;
    this.showIssueDetailError = false;
    this.errorTroubleshootingSelected = false;
    this.newConnectionSelected = false;
    this.fHIRSelected = false;
    this.activationSelected = false;
    this.appReminderSelected = false;
    this.payerConnectionSelected = false;
    this.existingEnrollmentSelected = false;
    this.labConnectionSelected = false;
    this.epcsSelected = false;
    this.erxSelected = false;
    this.addRefillSelected = false;
    this.tempCreationSelected = false;
    this.tempTroubleshootingSelected = false;
    this.uniTroubleshootingSelected = false;
    this.tempTrainingSelected = false;
    this.completedProviderMedicalSelected =false;
    this.customPaidSelected = false;
    this.paymentPostingSelected = false;
    this.billerTrainingSelected = false;
    this.advancePaymentSelected = false;
    this.advanceBillerTrainingSelected = false;
    this.advanceBillerTraining400Selected = false;
    this.updateProviderDetailsSelected = false;
}

    handleIssueChange(e) {
    this.selectedIssue        = e.target.value;
    this.selectedIssueDetail  = '';
    this.showIssueError       = false;
    this.showIssueDetailError = false;
    this.errorTroubleshootingSelected = false;
    this.newConnectionSelected = false;
    this.fHIRSelected = false;
    this.activationSelected = false;
    this.appReminderSelected = false;
    this.payerConnectionSelected = false;
    this.existingEnrollmentSelected = false;
    this.labConnectionSelected = false;
    this.epcsSelected = false;
    this.erxSelected = false;
    this.addRefillSelected = false;
    this.tempCreationSelected = false;
    this.tempTroubleshootingSelected = false;
    this.uniTroubleshootingSelected = false;
    this.tempTrainingSelected = false;
    this.completedProviderMedicalSelected =false;
    this.customPaidSelected = false;
    this.paymentPostingSelected = false;
    this.billerTrainingSelected = false;
    this.advancePaymentSelected = false;
    this.advanceBillerTrainingSelected = false;
    this.advanceBillerTraining400Selected = false;
    this.updateProviderDetailsSelected = false;
}

    handleIssueDetailChange(e) {
        this.selectedIssueDetail  = e.target.value;
        this.showIssueDetailError = false;
        // Training RT: auto-populate Subject with selected Issue Detail value
        if (this._selectedRecordTypeDeveloperName === 'Training' && this.selectedIssueDetail) {
            this.subject        = this.selectedIssueDetail;
            this.showSubjectError = false;
        }
        if(this.selectedCategory == 'Desktop Application' && this.selectedIssue == 'Billing & Payments' && this.selectedIssueDetail == 'Missing ERA'){
            this.missingERASelected = true;
        }else{
            this.missingERASelected = false;
            this.eraSections = [];
        }
        if(this.selectedCategory == 'Product Support' && this.selectedIssue == 'Product API' && this.selectedIssueDetail == 'Error Troubleshooting'){
            this.errorTroubleshootingSelected = true;
        }else{
            this.errorTroubleshootingSelected = false;
        }
        if(this.selectedCategory == 'Product Support' && this.selectedIssue == 'Product API' && this.selectedIssueDetail == 'New Connection'){
            this.newConnectionSelected = true;
        }else{
            this.newConnectionSelected = false;
            this.admin = false;
            this.keyReason = null;
        }
        if(this.selectedCategory == 'Product Support' && this.selectedIssue == 'Product API' && this.selectedIssueDetail == 'FHIR'){
            this.fHIRSelected = true;
        }else{
            this.fHIRSelected = false;
            this.admin = false;
        }

        if(this.selectedCategory == 'Product Support' && this.selectedIssue == 'Calendar Integration' && this.selectedIssueDetail == 'Activation'){
            this.activationSelected = true;
        }else{
            this.activationSelected = false;
            this.ehrName = null;
        }
        
        if(this.selectedCategory == 'Product Support' && this.selectedIssue == 'Calendar Integration' && this.selectedIssueDetail == 'Appointment Reminders'){
            this.appReminderSelected = true;
        }else{
            this.appReminderSelected = false;
            this.appDate = null;
            this.patientName = null;
        }

        if(this.selectedCategory == 'Enrollments' && this.selectedIssue == 'Insurance Enrollments' && this.selectedIssueDetail == 'Add New Insurance Payer Connection'){
            this.payerConnectionSelected = true;
        }else{
            this.payerConnectionSelected = false;
            this.payerName = null;
            this.payerId = null;
        }

        if(this.selectedCategory == 'Enrollments' && this.selectedIssue == 'Insurance Enrollments' && this.selectedIssueDetail == 'Assistance with an Existing Enrollment'){
            this.existingEnrollmentSelected = true;
        }else{
            this.existingEnrollmentSelected = false;
            this.payerName = null;
            this.payerId = null;
            this.npi = null;
        }

        if(this.selectedCategory == 'Enrollments' && this.selectedIssue == 'Clinical Enrollments' && this.selectedIssueDetail == 'New Laboratory Connection'){
            this.labConnectionSelected = true;
        }else{
            this.labConnectionSelected = false;
            this.labAccountNumber = null;
        }

        if(this.selectedCategory == 'Enrollments' && this.selectedIssue == 'Clinical Enrollments' && this.selectedIssueDetail == 'EPCS Enrollment Assistance'){
            this.epcsSelected = true;
        }else{
            this.epcsSelected = false;
            this.npi = null;
        }

        if(this.selectedCategory == 'Enrollments' && this.selectedIssue == 'Clinical Enrollments' && this.selectedIssueDetail == 'eRx Enrollment Assistance'){
            this.erxSelected = true;
        }else{
            this.erxSelected = false;
            this.npi = null;
        }

        if(this.selectedCategory == 'Enrollments' && this.selectedIssue == 'Clinical Enrollments' && this.selectedIssueDetail == 'Add Refills'){
            this.addRefillSelected = true;
        }else{
            this.addRefillSelected = false;
            this.npi = null;
        }

        if(this.selectedCategory == 'Enrollments' && this.selectedIssue == 'Clinical Enrollments' && this.selectedIssueDetail == 'Update Name of Provider, Address, Phone'){
            this.updateProviderDetailsSelected = true;
        }else{
            this.updateProviderDetailsSelected = false;
            this.providerName = null;
            this.providerAddress = null;
            this.providerPhoneNumber = null;
            this.previousProviderName = null;
            this.npi = null;
        }

        if(this.selectedCategory == 'Training Support' && this.selectedIssue == 'Services' && this.selectedIssueDetail == 'Custom Template Creation'){
            this.tempCreationSelected = true;
        }else{
            this.tempCreationSelected = false;
        }

        if(this.selectedCategory == 'Training Support' && this.selectedIssue == 'Services' && this.selectedIssueDetail == 'Custom Templates Troubleshooting'){
            this.tempTroubleshootingSelected = true;
        }else{
            this.tempTroubleshootingSelected = false;
        }

        if(this.selectedCategory == 'Training Support' && this.selectedIssue == 'Services' && this.selectedIssueDetail == 'Tebra University Troubleshooting'){
            this.uniTroubleshootingSelected = true;
        }else{
            this.uniTroubleshootingSelected = false;
        }

        if(this.selectedCategory == 'Training Support' && this.selectedIssue == 'Training' && this.selectedIssueDetail == 'Custom Template Training'){
            this.tempTrainingSelected = true;
        }else{
            this.tempTrainingSelected = false;
            this.completedProviderMedical = null;
            this.completedTemplateEditor = null;
        }

        if(this.selectedCategory == 'Training Support' && this.selectedIssue == 'Training' && this.selectedIssueDetail == 'Custom Paid Training'){
            this.customPaidSelected = true;
        }else{
            this.customPaidSelected = false;
            this.completedTraining = null;
        }
        
        if(this.selectedCategory == 'Training Support' && this.selectedIssue == 'Training' && this.selectedIssueDetail == 'ERA Payment Posting'){
            this.paymentPostingSelected = true;
        }else{
            this.paymentPostingSelected = false;
            this.billerTrainingSelected = false;
            this.completedBillerTraining = null;
            this.eraIds = null;
        }

        if(this.selectedCategory == 'Training Support' && this.selectedIssue == 'Training' && this.selectedIssueDetail == 'Advanced Payment Posting'){
            this.advancePaymentSelected = true;
        }else{
            this.advancePaymentSelected = false;
            this.advanceBillerTrainingSelected = false;
            this.advanceBillerTraining400Selected = false;
            this.completedAdvanceBillerTraining = null;
            this.completedAdvanceBillerTraining400 = null;
            this.eraIds = null;
        }
    }

    get disableAddButton() {
        return this.eraSections.length >= this.MAX_ERA;
    }

    addERA() {
        if (this.eraSections.length >= this.MAX_ERA) {
            return;
        }

        const newSection = this.createERA(this.eraSections.length + 1);

        this.eraSections = [...this.eraSections, newSection];
    }

    removeERA(event) {
        const index = Number(event.target.dataset.index);

        this.eraSections.splice(index, 1);

        // Renumber sections
        this.eraSections = this.eraSections.map((item, i) => {
            return {
                ...item,
                displayNumber: i + 1,
                showRemove: i > 0
            };
        });
    }

    handleFieldChange(event) {

        const index = Number(event.target.dataset.index);
        const field = event.target.dataset.field;
        const value = event.target.value;

        this.eraSections[index][field] = value;

        // Force reactivity
        //this.eraSections = [...this.eraSections];
    }

    handleBillerTrainingChange(e){
        
        if(this.advancePaymentSelected){
            this.completedAdvanceBillerTraining = e.target.value;
            this.showCompletedAdvanceBillerTrainingError = false;
            
            if(this.completedAdvanceBillerTraining == 'Yes'){
                this.advanceBillerTrainingSelected = true;
            }else{
                this.advanceBillerTrainingSelected = false;
            }
        }else{
            this.completedBillerTraining = e.target.value;
            if(this.completedBillerTraining == 'Yes'){
                this.billerTrainingSelected = true;
            }else{
                this.billerTrainingSelected = false;
            }
        }
        
    }
    handleBillerTraining400Change(e){
        this.completedAdvanceBillerTraining400 = e.target.value;
        this.showCompletedAdvanceBillerTraining400Error = false;
        if(this.completedAdvanceBillerTraining400 == 'Yes'){
            this.advanceBillerTraining400Selected = true;
        }else{
            this.advanceBillerTraining400Selected = false;
        }
    }
    handleEraIdsChange(e){
        this.eraIds = e.target.value;
        this.showEraIdsError = false;
    }

    handleAdminChange(e){
        this.admin = e.target.value;
        this.showAdminError = false;
    }

    handleKeyReasonChange(e){
        this.keyReason = e.target.value;
        this.showKeyReasonError = false;
    }

    handleEhrNameChange(e){
        this.ehrName = e.target.value;
        this.showEhrNameError = false;
    }

    handleAppDateChange(e){
        this.appDate = e.target.value;
        this.showAppDateError = false;
    }

    handlePatientNameChange(e){
        this.patientName = e.target.value;
        this.showPatientNameError = false;
    }

    handlePayerNameChange(e){
        this.payerName = e.target.value;
        this.showPayerNameError = false;
    }

    handlePayerIdChange(e){
        this.payerId = e.target.value;
        this.showPayerIdError = false;
    }

    handleNpiChange(e){
        this.npi = e.target.value;
        this.showNpiError = false;
    }

    handleTinChange(e){
        this.tin = e.target.value;
        this.showTinError = false;
    }
    handleProviderAddressChange(e){
        this.providerAddress = e.target.value;
    }

    handlePreviousProviderAddressChange(e){
        this.previousProviderAddress = e.target.value;
    }
    handleProviderPhoneNumberChange(e){
        this.providerPhoneNumber = e.target.value;
    }
    handlePreviousProviderPhoneNumberChange(e){
        this.previousProviderPhoneNumber = e.target.value;
    }

    handleProviderNameChange(e){
        this.providerName = e.target.value;
    }

    handlePreviousProviderNameChange(e){
        this.previousProviderName = e.target.value;
    }
    handleLabAccountNumberChange(e){
        this.labAccountNumber = e.target.value;
        this.showLabAccountNumberError = false;
    }

    handleTempTrainingChange(e){
        this.completedProviderMedical = e.target.value;
        this.showCompletedProviderMedicalError = false;
        if(this.completedProviderMedical == 'Yes'){
            this.completedProviderMedicalSelected = true;
        }else{
            this.completedProviderMedicalSelected = false;
        }
    }

    handleTemplateEditorChange(e){
        this.completedTemplateEditor = e.target.value;
        this.showCompletedTemplateEditorError = false;
    }

    handleCompletedTrainingChange(e){
        this.completedTraining = e.target.value;
        this.showCompletedTrainingError = false;
    }
    
    handleSelectFeatureChange(e){
        this.selectFeature = e.target.value;
        this.showSelectFeatureError = false;
    }
    handleSubjectChange(e) {
        this.subject        = e.target.value;
        this.showSubjectError = false;
    }

    handleDescriptionChange(e) {
        this.description         = e.target.value;
        this.showDescriptionError = false;
    }

    handleCollaboratorChange(e) {
        this.selectedCollaboratorIds = e.detail.selectedUserIds || [];
    }
    handleFilesUpdated(e) {
        this._pendingFileIds      = e.detail.uploadedFileIds   || [];
        this._hasUploadingFiles   = e.detail.hasUploadingFiles || false;
    }

    // ── Submit ────────────────────────────────────────────────────────────────

    async handleSubmit() {
        console.log('TIN value on submit-->' , this.tin);
        this.additionalDescription = '';
        if(this.missingERASelected){
            //this.additionalDescription = 'Check Date: ' + this.selectedCheckDate + '\nCheck Number: ' + this.selectedCheckNumber + '\nCheck Amount: ' + this.selectedCheckAmount;
            this.additionalDescription = 'Payer Name: ' + this.payerName + '\nPayer Id: ' + this.payerId + '\nNPI: ' + this.npi + '\nTIN: ' + this.tin;
            var counter = 1;
            this.eraSections.forEach(section => {
                this.additionalDescription += '\n\nERA: ' + counter + '\nCheck Date: ' + section.checkDate + '\nCheck Number: ' + section.checkNumber + '\nCheck Amount: ' + section.checkAmount;
                counter = counter+1;
            }); 
        }
        if(this.newConnectionSelected){
            this.additionalDescription = 'Are you Admin?: ' + this.admin + '\nKey Request Reason: ' + this.keyReason;
        }
        if(this.fHIRSelected){
            this.additionalDescription = 'Are you Admin?: ' + this.admin;
        }
        if(this.activationSelected){
            this.additionalDescription = 'EHR Name: ' + this.ehrName;
        }
        if(this.appReminderSelected){
            this.additionalDescription = 'Date: ' + this.appDate + '\nPatient Name: ' + this.patientName;
        }
        if(this.payerConnectionSelected){
            this.additionalDescription = 'Payer Name: ' + this.payerName + '\nPayer Id: ' + this.payerId;
        }
        if(this.existingEnrollmentSelected){
            this.additionalDescription = 'Payer Name: ' + this.payerName + '\nPayer Id: ' + this.payerId + '\nNPI: ' + this.npi;
        }
        if(this.labConnectionSelected){
            this.additionalDescription = 'Lab Account Number: ' + this.labAccountNumber;
        }
        if(this.epcsSelected || this.erxSelected || this.addRefillSelected){
            this.additionalDescription = 'NPI: ' + this.npi;
        }
        if(this.updateProviderDetailsSelected){
            this.additionalDescription = 'Previous Name:' + this.previousProviderName + '\nNew Name: ' + this.providerName + '\nPrevious Address: ' + this.previousProviderAddress + '\nNew Address: ' + this.providerAddress + '\nPrevious Phone Number: ' + this.previousProviderPhoneNumber + '\nNew Phone Number: ' + this.providerPhoneNumber + '\nNPI: ' + this.npi;
        }
        if(this.tempTrainingSelected){
            this.additionalDescription = 'Have you completed provider Medical in Tebra University?: ' + this.completedProviderMedical;
            if(this.completedProviderMedicalSelected){
                this.additionalDescription += '\nHave you completed template editor training in Tebra University?: ' + this.completedTemplateEditor 
            }
        }
        if(this.customPaidSelected){
            this.additionalDescription = 'Have you completed Training in Tebra University?: ' + this.completedTraining;
        }

        if(this.paymentPostingSelected){
            this.additionalDescription = 'Have you completed Biller Training in Tebra University?: ' + this.completedBillerTraining;
            if(this.billerTrainingSelected){
                this.additionalDescription += '\nProvide 3 ERA Ids & Check Numbers: ' + this.eraIds 
            }
        }

        if(this.advancePaymentSelected){
            this.additionalDescription = 'Have you completed Biller Training in Tebra University?: ' + this.completedAdvanceBillerTraining;
            if(this.advanceBillerTrainingSelected){
                this.additionalDescription += '\nHave you completed Biller Training 4-200 Live?: ' + this.completedAdvanceBillerTraining400;
                if(this.advanceBillerTraining400Selected){
                    this.additionalDescription += '\nProvide 3 ERA Ids & Check Numbers: ' + this.eraIds 
                }
            }
        }

        this.finalDescription = this.description + '\n' + this.additionalDescription;
        if(this.finalDescription.length > 131072){
            this.finalDescription = this.description.slice(0,131072-this.finalDescription.length) + '\n' + this.additionalDescription;
        }
        
        if (!this._validate()) return;
        this.isSubmitting = true;
        try {
            const contentDocumentIds = [...this._pendingFileIds];


            const result = await createCase({
                recordTypeId       : this.selectedRecordTypeId,
                accountId          : this.selectedAccountId || this._singleAccountId,
                contactId          : this.currentUserContactId,
                contactPhone       : this.currentUserContactPhone,
                userEmail          : this.currentUserEmail,
                category           : this.selectedCategory,
                issue              : this.selectedIssue,
                issueDetail        : this.selectedIssueDetail,
                subject            : this.subject,
                description        : this.finalDescription,
                collaboratorUserIds: [...this.selectedCollaboratorIds],
                contentDocumentIds,
                caseTeamRoleId     : this.caseTeamRoleId
            });

            this.dispatchEvent(new CustomEvent('casecreated', {
                detail: { caseId: result.caseId, caseNumber: result.caseNumber }
            }));

        } catch (e) {
            const msg = e?.body?.message || e?.message || 'An unexpected error occurred.';
            this._toast(msg, 'error', 'Error Creating Case');
            this.isSubmitting = false;
        }
    }

    // ── Getters ───────────────────────────────────────────────────────────────

    get isStep1() { return this.step === 1 && !this.isLoading; }
    get isStep2() { return this.step === 2 && !this.isLoading; }
    get isSubmitDisabled() {
    return this.isSubmitting || this._hasUploadingFiles;
}

    // Picklist options built from wire data + dependency filtering

    get categoryOptions() {
        if (!this._categoryWire) return [];
        return this._categoryWire.values.map(v => ({
            label     : v.label,
            value     : v.value,
            isSelected: v.value === this.selectedCategory
        }));
    }

    get issueOptions() {
        if (!this._issueWire || !this.selectedCategory) return [];
        const ctrlIdx = this._issueWire.controllerValues[this.selectedCategory];
        if (ctrlIdx === undefined) return [];
        return this._issueWire.values
            .filter(v => v.validFor.includes(ctrlIdx))
            .map(v => ({
                label     : v.label,
                value     : v.value,
                isSelected: v.value === this.selectedIssue
            }));
    }

    get issueDetailOptions() {
    if (!this._issueDetailWire || !this.selectedIssue) return [];
    const ctrlIdx = this._issueDetailWire.controllerValues[this.selectedIssue];
    if (ctrlIdx === undefined) return [];

    let options = this._issueDetailWire.values
        .filter(v => v.validFor.includes(ctrlIdx))
        .map(v => ({
            label     : v.label,
            value     : v.value,
            isSelected: v.value === this.selectedIssueDetail
        }));

    // Hide specific values for specific Record Type + Category + Issue combinations
    const hiddenValues = this._getHiddenIssueDetailValues();
    if (hiddenValues.length > 0) {
        options = options.filter(opt => !hiddenValues.includes(opt.value));
    }

    return options;
}

_getHiddenIssueDetailValues() {
    const match = HIDDEN_ISSUE_DETAILS_BY_CONTEXT.find(ctx =>
        ctx.recordTypeDeveloperName === this._selectedRecordTypeDeveloperName &&
        ctx.category === this.selectedCategory &&
        ctx.issue === this.selectedIssue
    );
    return match ? match.hiddenValues : [];
}

    get isCategoryDisabled()    { return !this.selectedRecordTypeId; }
    get hasIssueOptions()       { return this.issueOptions.length > 0; }
    get hasIssueDetailOptions() { return this.issueDetailOptions.length > 0; }
    get isIssueDisabled()       { return !this.selectedCategory || !this.hasIssueOptions; }
    get isIssueDetailDisabled() { return !this.selectedIssue || !this.hasIssueDetailOptions; }

    get effectiveAccountId() {
    return this.isSingleAccount ? this._singleAccountId : this.selectedAccountId;
    }
    
    // Column class for Category — full width when account is hidden
    get categoryColClass() {
        return this.isSingleAccount ? 'cc-col-full' : 'cc-col-half';
    }


    // Dynamic input classes (add error indicator when invalid)
    get accountSelectClass()     { return this._inputClass('cc-select', this.showAccountError); }
    get categorySelectClass()    { return this._inputClass('cc-select', this.showCategoryError); }
    get issueSelectClass()       { return this._inputClass('cc-select', this.showIssueError) + (this.isIssueDisabled ? ' cc-select--disabled' : ''); }
    get issueDetailSelectClass() { return this._inputClass('cc-select', this.showIssueDetailError) + (this.isIssueDetailDisabled ? ' cc-select--disabled' : ''); }
    get payerNameClass()         { return this._inputClass('cc-input',  this.showPayerNameError); }
    get payerIdClass()           { return this._inputClass('cc-input',  this.showPayerIdError); }
    get npiClass()               { return this._inputClass('cc-input',  this.showNpiError); }
    get tinClass()               { return this._inputClass('cc-input',  this.showTinError); }
    get adminClass()             { return this._inputClass('cc-select', this.showAdminError); }
    get keyReasonClass()         { return this._inputClass('cc-input', this.showKeyReasonError); }
    get ehrNameClass()           { return this._inputClass('cc-input', this.showEhrNameError); }
    get appDateClass()           { return this._inputClass('cc-input', this.showAppDateError); }
    get patientNameClass()       { return this._inputClass('cc-input', this.showPatientNameError); }
    get labAccountNumberClass()  { return this._inputClass('cc-input', this.showLabAccountNumberError); }
    get tempTrainingClass()      { return this._inputClass('cc-select', this.showCompletedProviderMedicalError); }
    get templateEditorClass()    { return this._inputClass('cc-select', this.showCompletedTemplateEditorError); }
    get completedTrainingClass() { return this._inputClass('cc-select', this.showCompletedTrainingError); }
    get billerTrainingClass()    { return this._inputClass('cc-select', this.showCompletedBillerTrainingError); }
    get completedAdvanceBillerTrainingClass() { return this._inputClass('cc-select', this.showCompletedAdvanceBillerTrainingError); }
    get eraIdsClass()            { return this._inputClass('cc-input', this.showEraIdsError); }
    get billerTraining400Class() { return this._inputClass('cc-select', this.showCompletedAdvanceBillerTraining400Error); }
    get selectFeatureClass()     { return this._inputClass('cc-select', this.showSelectFeatureError); }
    get subjectClass()           { return this._inputClass('cc-input',  this.showSubjectError); }
    get descriptionClass()       { return this._inputClass('cc-textarea', this.showDescriptionError); }

    // ── Private Helpers ───────────────────────────────────────────────────────

    _applyInitialData(data) {
        this.currentUserEmail        = data.currentUserEmail        || '';
        this.currentUserContactPhone = data.currentUserContactPhone || '';
        this.currentUserContactId    = data.currentUserContactId    || '';
        this.caseTeamRoleId          = data.caseTeamRoleId          || '';
        this.isSingleAccount         = !!data.isSingleAccount;
        this._singleAccountId        = data.singleAccountId || null;
        if (this.isSingleAccount) this.selectedAccountId = data.singleAccountId || '';

        const primaryId = data.primaryAccountId || null;

        this.accountOptions = (data.accounts || []).map(a => ({
            value     : a.accountId,
            label     : a.accountName,
            isSelected: a.accountId === primaryId
        }));

        if (primaryId && !this.isSingleAccount) {
            this.selectedAccountId = primaryId;
        }

        this.recordTypeOptions = (data.recordTypes || []).map(rt => ({
        value        : rt.Id,
        label        : rt.Name,
        developerName: rt.DeveloperName,
        inputId      : 'rt-' + rt.Id
        }));

    }

    _resetPicklistsFromCategory() {
        this.selectedCategory    = '';
        this.selectedIssue       = '';
        this.selectedIssueDetail = '';
    }

    _resetStep2Form() {
        this._resetPicklistsFromCategory();
        this.subject              = '';
        this.description          = '';
        this.selectedAccountId    = this.isSingleAccount ? (this._singleAccountId || '') : '';
        this.selectedCollaboratorIds = [];
        this._pendingFileIds = [];
        this._clearValidation();
    }


    _validate() {
        let valid = true;
        if (!this.isSingleAccount && !this.selectedAccountId) {
            this.showAccountError = true; valid = false;
        }
        if (!this.selectedCategory) {
            this.showCategoryError = true; valid = false;
        }
        if (this.hasIssueOptions && !this.selectedIssue) {
            this.showIssueError = true; valid = false;
        }
        if (this.hasIssueDetailOptions && !this.selectedIssueDetail) {
           this.showIssueDetailError = true; valid = false;
        }
        if (!this.subject.trim()) {
            this.showSubjectError = true; valid = false;
        }
        if (!this.description.trim()) {
            this.showDescriptionError = true; valid = false;
        }
        if(this.appReminderSelected && !this.appDate){
            this.showAppDateError = true; valid = false;
        }
        if(this.appReminderSelected && !this.patientName){
            this.showPatientNameError = true; valid = false;
        }
        if(this.activationSelected && !this.ehrName){
            this.showEhrNameError = true; valid = false;
        }
        if(this.newConnectionSelected && !this.admin){
            this.showAdminError = true; valid = false;
        }
        if(this.fHIRSelected && !this.admin){
            this.showAdminError = true; valid = false;
        }
        if(this.newConnectionSelected && !this.keyReason){
            this.showKeyReasonError = true; valid = false;
        }
        if((this.payerConnectionSelected || this.missingERASelected || this.existingEnrollmentSelected) && !this.payerName){
            this.showPayerNameError = true; valid = false;
        }
        if((this.existingEnrollmentSelected || this.missingERASelected) && !this.payerId){
            this.showPayerIdError = true; valid = false;
        }
        if((this.existingEnrollmentSelected || this.missingERASelected || this.epcsSelected || this.erxSelected || this.addRefillSelected || this.updateProviderDetailsSelected) && !this.npi){
            this.showNpiError = true; valid = false;
        }
        if(this.missingERASelected && !this.tin){
            this.showTinError = true; valid = false;
        }
        if(this.labConnectionSelected && !this.labAccountNumber){
            this.showLabAccountNumberError = true; valid = false;
        }
        if(this.tempTrainingSelected && !this.completedProviderMedical){
            this.showCompletedProviderMedicalError = true; valid = false;
        }
        if(this.completedProviderMedicalSelected && !this.completedTemplateEditor){
            this.showCompletedTemplateEditorError = true; valid = false;
        }
        if(this.customPaidSelected && !this.completedTraining){
            this.showCompletedTrainingError = true; valid = false;
        }
        if(this.paymentPostingSelected && !this.completedBillerTraining){
            this.showCompletedBillerTrainingError = true; valid = false;
        }
        if(this.advanceBillerTrainingSelected && !this.completedAdvanceBillerTraining400){
            this.showCompletedAdvanceBillerTraining400Error = true; valid = false;
        }
        if(this.advancePaymentSelected && !this.completedAdvanceBillerTraining){
            this.showCompletedAdvanceBillerTrainingError = true; valid = false;
        }
        if(this.advanceBillerTraining400Selected && !this.eraIds){
            this.showEraIdsError = true; valid = false;
        }
        if(this.billerTrainingSelected && !this.eraIds){
            this.showEraIdsError = true; valid = false;
        }
        if(this.updateProviderDetailsSelected && !this.selectFeature){
            this.showSelectFeatureError = true; valid = false;
        }
        if(this.missingERASelected){
            console.log('Original-->' , this.eraSections);
            
            this.eraSections.forEach(section => {
                section.showEraCheckDateError = !section.checkDate;
                section.showEraCheckNumberError = !section.checkNumber;
                section.showEraCheckAmountError = !section.checkAmount;

                if (section.showEraCheckDateError || section.showEraCheckNumberError || section.showEraCheckAmountError) {
                    valid = false;
                }
            });

            this.eraSections = [...this.eraSections];
        }
        return valid;
    }

    _clearValidation() {
        this.showAccountError     = false;
        this.showCategoryError    = false;
        this.showIssueError       = false;
        this.showIssueDetailError = false;
        this.showSubjectError     = false;
        this.showDescriptionError = false;
    }

    async _cleanupFiles() {
    if (!this._pendingFileIds.length) return;
    try {
        await deleteFiles({ contentDocumentIds: [...this._pendingFileIds] });
        this._pendingFileIds = [];
    } catch (e) {
        console.error('caseCommunityCreate: file cleanup error —', e);
    }
}

    _inputClass(base, hasError) {
        return hasError ? `${base} cc-input--error` : base;
    }

    _toast(message, variant, title) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}