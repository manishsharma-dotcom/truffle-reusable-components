/**
 * caseFileUpload.js
 *
 * Custom file upload LWC designed to be embedded on a Salesforce Screen Flow screen.
 *
 * Responsibilities:
 *   - Accepts file(s) via click-to-browse or drag-and-drop
 *   - Uploads each file to Salesforce as a ContentVersion (via Apex base64 method)
 *   - Displays a live list of uploaded files with a per-file remove (✕) button
 *   - Removing a file deletes the ContentDocument from the org immediately
 *   - Keeps the @api `uploadedFileIds` array up to date — flow reads this on Next
 *   - Publishes current file IDs to the CaseFileUpload__c LMC after every change,
 *     so the parent caseListView can delete orphans if the user cancels the modal
 *
 * Scenarios handled:
 *   Submit  → flow reads `uploadedFileIds` output variable, creates CDLinks with Case
 *   Cancel  → parent caseListView receives INTERRUPTED, reads LMC IDs, deletes them
 *   Remove  → immediate Apex delete + UI update + LMC publish
 */
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent }                      from 'lightning/platformShowToastEvent';
import uploadFile        from '@salesforce/apex/TF_EX_CaseFileUploadController.uploadFile';
import deleteFiles       from '@salesforce/apex/TF_EX_CaseFileUploadController.deleteFiles';
import getFileDetails    from '@salesforce/apex/TF_EX_CaseFileUploadController.getFileDetails';
const MAX_FILE_BYTES = 2 * 1024 * 1024; // 2 MB

export default class CaseFileUpload extends LightningElement {

    /**
     * Flow output variable (Text Collection).
     * The Screen Flow reads this array via the "Outputs" mapping when the user clicks Next.
     * In Flow Builder, map this to the collection variable you loop through to create CDLinks.
     */
    @track _uploadedFileIds = [];

    @api
    get uploadedFileIds() {
        return this._uploadedFileIds;
    }

    set uploadedFileIds(val) {
    // Called by Flow on re-render to restore previously uploaded IDs
    this._uploadedFileIds = Array.isArray(val) ? [...val] : [];
    }

   

    async connectedCallback() {
    // Flow re-renders this component on validation error.
    // If uploadedFileIds already has values passed back in from the flow variable,
    // re-query ContentVersion to restore the file list display.
    if (this._uploadedFileIds && this._uploadedFileIds.length > 0) {
    try {
        const details = await getFileDetails({
            contentDocumentIds: this._uploadedFileIds
        });
            this.files = details.map(cv => ({
                tempId            : cv.ContentDocumentId,
                contentDocumentId : cv.ContentDocumentId,
                name              : cv.Title,
                size              : this._formatSize(cv.ContentSize),
                isUploading       : false
            }));
            this._syncAndPublish();
        } catch (e) {
            // Files are still in the org even if display restore fails.
            // Parent caseListView still has IDs for cleanup if user cancels.
            console.warn('caseFileUpload: could not restore file list —', e);
        }
    }
}

    @track files       = [];   // [{tempId, contentDocumentId, name, size, isUploading}]
    @track isDragOver  = false;

    // ─── UI Trigger ───────────────────────────────────────────────────────────

    handleChooseClick() {
        // Programmatically click the hidden native file input
        this.template.querySelector('.fu-hidden-input').click();
    }

    // ─── File Selection (via button) ──────────────────────────────────────────

    handleFileChange(event) {
    const selected = Array.from(event.target.files);
    event.target.value = '';
    this._processFiles(selected);
}

    // ─── Drag & Drop ──────────────────────────────────────────────────────────

    handleDragOver(event) {
        event.preventDefault();
        this.isDragOver = true;
    }

    handleDragLeave() {
        this.isDragOver = false;
    }

    handleDrop(event) {
    event.preventDefault();
    this.isDragOver = false;
    this._processFiles(Array.from(event.dataTransfer.files));
}

    // ─── Core Upload Logic ────────────────────────────────────────────────────

    _processFiles(files) {
    const oversized = files.filter(f => f.size > MAX_FILE_BYTES);
    const valid     = files.filter(f => f.size <= MAX_FILE_BYTES);

    if (oversized.length > 0) {
        const fileList = oversized
            .map(f => `${f.name} (${this._formatSize(f.size)})`)
            .join(', ');
        this._toast(
            `Oops! These files are larger than the 2 MB limit: ${fileList}. Please upload files under 2 MB.`,
            'error',
            'File Too Large',
            'pester'
        );
    }

    valid.forEach(f => this._readAndUpload(f));
}
    
    _readAndUpload(file) {
    const tempId = 'tmp-' + Date.now() + '-' + Math.random().toString(36).slice(2);

    this.files = [
        ...this.files,
        {
            tempId,
            contentDocumentId : null,
            name              : file.name,
            size              : this._formatSize(file.size),
            isUploading       : true
        }
    ];
    this._notifyParent();


    const reader = new FileReader();

    reader.onload = () => {
        // ── Step 1: Extract base64 safely ──────────────────────────
        let base64;
        try {
            const result = reader.result;
            if (!result || typeof result !== 'string') {
                throw new Error('FileReader returned an empty or invalid result.');
            }
            const commaIndex = result.indexOf(',');
            if (commaIndex === -1 || commaIndex === result.length - 1) {
                throw new Error('FileReader result is missing base64 content.');
            }
            base64 = result.substring(commaIndex + 1);
            if (!base64) {
                throw new Error('Base64 content is empty.');
            }
        } catch (readErr) {
            this.files = this.files.filter(f => f.tempId !== tempId);
            this._toast(
                `Could not read "${file.name}". Please try a different file.`,
                'error',
                'File Error'
            );
            return;
        }

        // ── Step 2: Call Apex upload ────────────────────────────────
        uploadFile({
            fileName    : file.name,
            base64Data  : base64,
            contentType : file.type || 'application/octet-stream'
        })
        .then(contentDocumentId => {
            this.files = this.files.map(f =>
                f.tempId === tempId
                    ? { ...f, contentDocumentId, isUploading: false }
                    : f
            );
            this._syncAndPublish();
        })
        .catch(err => {
            this.files = this.files.filter(f => f.tempId !== tempId);
            this._notifyParent();
            const apexMsg = err?.body?.message || err?.message || 'Unknown error';
            this._toast(
                `Failed to upload "${file.name}": ${apexMsg}`,
                'error',
                'Upload Error'
            );
        });
    };

    reader.onerror = () => {
        this.files = this.files.filter(f => f.tempId !== tempId);
        this._notifyParent();
        this._toast(
            `Could not read "${file.name}". The file may be corrupted.`,
            'error',
            'File Error'
        );
    };

    reader.readAsDataURL(file);
}

    // ─── Per-File Delete ──────────────────────────────────────────────────────

    async handleDeleteFile(event) {
        const cdId = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;

        // Optimistic remove from UI and output variable immediately
        this.files = this.files.filter(f => f.contentDocumentId !== cdId);
        this._syncAndPublish();

        try {
            await deleteFiles({ contentDocumentIds: [cdId] });
        } catch (err) {
            // File is already removed from UI — not re-adding to avoid confusion.
            // The orphaned file will be cleaned up by the parent on cancel,
            // or remain until Salesforce content cleanup policies apply.
            this._toast(
                `Could not remove "${name}" from the server. Please try again.`,
                'error',
                'Delete Error'
            );
        }
    }

    // ─── Sync Output Variable + Publish to LMC ───────────────────────────────

    /**
     * Called after every add or remove operation.
     * 1. Updates the @api `uploadedFileIds` array (flow reads this on Next click)
     * 2. Publishes current IDs to the LMC so the parent caseListView always
     *    has the latest snapshot for cancel-cleanup purposes
     */
_syncAndPublish() {
    this._uploadedFileIds = this.files
        .filter(f => f.contentDocumentId)
        .map(f => f.contentDocumentId);
    this._notifyParent();
}

_notifyParent() {
    const hasUploadingFiles = this.files.some(f => f.isUploading);
    this.dispatchEvent(new CustomEvent('filesupdated', {
        detail: {
            uploadedFileIds  : [...this._uploadedFileIds],
            hasUploadingFiles
        }
    }));
}
    // ─── Getters ──────────────────────────────────────────────────────────────

    get hasFiles() {
        return this.files.length > 0;
    }

    get dropzoneClass() {
        return this.isDragOver
            ? 'fu-dropzone fu-dropzone--active'
            : 'fu-dropzone';
    }

    // ─── Utilities ────────────────────────────────────────────────────────────

    _formatSize(bytes) {
        if (bytes < 1024)         return bytes + ' B';
        if (bytes < 1024 * 1024)  return (bytes / 1024).toFixed(1) + ' KB';
        return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    }

    _toast(message, variant, title, mode = 'dismissible') {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
    }
}