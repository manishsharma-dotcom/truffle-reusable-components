/**
 * TF_EX_CaseCommunityDetail.js
 *
 * Experience Cloud record-page LWC that replaces the standard Case detail page.
 *
 * Features:
 *   - Read-only display of: CaseNumber, Status, Subject, TF_EX_Description__c,
 *     ContactPhone, IsEscalated (only when true)
 *   - Existing CaseTeamMember collaborators shown as pills with remove buttons
 *   - Reusable TF_EX_CaseCollaborator picker for adding new collaborators
 *     (picker remounts after each add so its internal selection resets cleanly)
 *   - Close Case modal  → requires Closed_Reason__c picklist value
 *   - Reopen Case modal → requires free-text reason, posted to Chatter as FeedItem
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent }               from 'lightning/platformShowToastEvent';
import getCaseDetail          from '@salesforce/apex/TF_EX_CaseCommunityDetailController.getCaseDetail';
import getClosedReasonOptions from '@salesforce/apex/TF_EX_CaseCommunityDetailController.getClosedReasonOptions';
import closeCase              from '@salesforce/apex/TF_EX_CaseCommunityDetailController.closeCase';
import reopenCase             from '@salesforce/apex/TF_EX_CaseCommunityDetailController.reopenCase';
import addCollaborator        from '@salesforce/apex/TF_EX_CaseCommunityDetailController.addCollaborator';
import removeCollaborator     from '@salesforce/apex/TF_EX_CaseCommunityDetailController.removeCollaborator';

// Status → badge CSS class (same palette as caseListView)
const STATUS_BADGE_MAP = {
    'New'                     : 'cd-badge cd-status-new',
    'Working'                 : 'cd-badge cd-status-working',
    'On Hold'                 : 'cd-badge cd-status-on-hold',
    'Escalated'               : 'cd-badge cd-status-escalated',
    'Closed'                  : 'cd-badge cd-status-closed',
    'Pending Reply - Customer': 'cd-badge cd-status-pending',
    'Resolved'                : 'cd-badge cd-status-resolved',
    'Pending'                 : 'cd-badge cd-status-pending',
};

export default class TF_EX_CaseCommunityDetail extends LightningElement {

    // Provided by the Experience Cloud record page
    @api recordId;

    // ── Data ──────────────────────────────────────────────────────────────────
    @track isLoading           = true;
    @track caseRecord          = null;
    @track collaborators       = [];       // [{caseTeamMemberId, userId, userName}]
    @track caseTeamRoleId      = '';
    @track closedReasonOptions = [];
    @track canReopen           = false;


    // ── Close Modal ───────────────────────────────────────────────────────────
    @track showCloseModal        = false;
    @track closedReason          = '';
    @track showClosedReasonError = false;
    @track isClosing             = false;

    // ── Reopen Modal ──────────────────────────────────────────────────────────
    @track showReopenModal        = false;
    @track reopenReason           = '';
    @track showReopenReasonError  = false;
    @track isReopening            = false;

    // ── Collaborator Picker ───────────────────────────────────────────────────
    // Incrementing this forces the TF_EX_CaseCollaborator component to remount
    // with a clean internal state after each successful add.
    // COLLAB_SUPPRESSED: picker state kept but never used while HTML is commented out
    @track _pickerVisible      = false;   // ← changed from true to false as safety net
    _lastPickerSelection       = [];   // tracks previous event payload for diffing

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    async connectedCallback() {
        await this._loadData();
    }

    async _loadData() {
        this.isLoading = true;
        try {
            const [detail, options] = await Promise.all([
                getCaseDetail({ caseId: this.recordId }),
                getClosedReasonOptions()
                ]);
                this.caseRecord          = detail.caseRecord;
            // COLLAB_SUPPRESSED: collaborator data loaded but not displayed.
            // Uncomment below + restore HTML section to re-enable.
            // this.collaborators    = detail.collaborators || [];
            // this.caseTeamRoleId   = detail.caseTeamRoleId || '';
            this.collaborators       = []; // always empty while suppressed
            this.caseTeamRoleId      = '';
            this.canReopen           = detail.canReopen === true;
            this.closedReasonOptions = options || [];
        } catch (e) {
            this._toast(e?.body?.message || 'Failed to load case details.', 'error', 'Error');
        } finally {
            this.isLoading = false;
        }
    }


    // _remountPicker — keep method, suppress body:
    async _remountPicker() {
    // COLLAB_SUPPRESSED: picker remount disabled.
    // Uncomment below to re-enable:
    // this._pickerVisible   = false;
    // this._lastPickerSelection = [];
    // await Promise.resolve();
    // this._pickerVisible   = true;
}

    // ── Close Case Handlers ───────────────────────────────────────────────────

    handleOpenCloseModal() {
        this.closedReason          = '';
        this.showClosedReasonError = false;
        this.showCloseModal        = true;
    }

    handleClosedReasonChange(e) {
        this.closedReason          = e.target.value;
        this.showClosedReasonError = false;
    }

    handleCancelClose() {
        this.showCloseModal = false;
    }

    async handleConfirmClose() {
        if (!this.closedReason) {
            this.showClosedReasonError = true;
            return;
        }
        this.isClosing = true;
        try {
            await closeCase({
                caseId       : this.recordId,
                closedReason : this.closedReason
            });
            this.showCloseModal = false;
            this._toast('Case closed successfully.', 'success', 'Case Closed');
            setTimeout(() => { window.location.reload(); }, 1500);
        } catch (e) {
            this._toast(
                e?.body?.message || 'Failed to close the case.',
                'error',
                'Error'
            );
        } finally {
            this.isClosing = false;
        }
    }

    // ── Reopen Case Handlers ──────────────────────────────────────────────────

    handleOpenReopenModal() {
        this.reopenReason          = '';
        this.showReopenReasonError = false;
        this.showReopenModal       = true;
    }

    handleReopenReasonChange(e) {
        this.reopenReason          = e.target.value;
        this.showReopenReasonError = false;
    }

    handleCancelReopen() {
        this.showReopenModal = false;
    }

    async handleConfirmReopen() {
        if (!this.reopenReason.trim()) {
            this.showReopenReasonError = true;
            return;
        }
        this.isReopening = true;
        try {
            await reopenCase({
                caseId : this.recordId,
                reason : this.reopenReason.trim()
            });
            this.showReopenModal = false;
            this._toast('Case reopened successfully.', 'success', 'Case Reopened');
            setTimeout(() => { window.location.reload(); }, 1500);
        } catch (e) {
            this._toast(
                e?.body?.message || 'Failed to reopen the case.',
                'error',
                'Error'
            );
        } finally {
            this.isReopening = false;
        }
    }

    // ── Collaborator Handlers ─────────────────────────────────────────────────

    /**
     * Fired by TF_EX_CaseCollaborator whenever selection changes.
     * We diff against the previous selection to detect the single newly added
     * user, create their CaseTeamMember, then remount the picker clean.
     */
            // handleCollaboratorChange — keep method, suppress body:
        async handleCollaboratorChange(e) {
            // COLLAB_SUPPRESSED: handler body disabled.
            // Uncomment below to re-enable adding collaborators:
            /*
            const newSelection = e.detail.selectedUserIds || [];
            const prevSet      = new Set(this._lastPickerSelection);
            const added        = newSelection.filter(id => !prevSet.has(id));
            if (added.length === 0) {
                this._lastPickerSelection = [...newSelection];
                return;
            }
            const existingUserIds = new Set(this.collaborators.map(c => c.userId));
            let   anyAdded        = false;
            for (const userId of added) {
                if (existingUserIds.has(userId)) continue;
                try {
                    await addCollaborator({ caseId: this.recordId, userId, teamRoleId: this.caseTeamRoleId });
                    anyAdded = true;
                } catch (err) {
                    this._toast(err?.body?.message || 'Failed to add collaborator.', 'error', 'Error');
                }
            }
            if (anyAdded) {
                await this._loadData();
                await this._remountPicker();
            } else {
                this._lastPickerSelection = [...newSelection];
            }
            */
        }

    /*async handleRemovePreloadedCollaborator(e) {
        const userId = e.detail.userId;
        const collab = this.collaborators.find(c => c.userId === userId);
        if (!collab) return;

        // Optimistic update — immediately removes pill via reactive binding
        this.collaborators = this.collaborators.filter(c => c.userId !== userId);

        try {
            await removeCollaborator({ caseTeamMemberId: collab.caseTeamMemberId });
        } catch (err) {
            this._toast(
                err?.body?.message || 'Failed to remove collaborator.',
                'error',
                'Error'
            );
            // Restore correct state on failure
            await this._loadData();
            this._pickerKey++;
        }
    }*/

            // handleRemoveCollaborator — keep method, suppress body:
        async handleRemoveCollaborator(e) {
            // COLLAB_SUPPRESSED: handler body disabled.
            // Uncomment below to re-enable removing collaborators:
            /*
            const ctmId  = e.currentTarget.dataset.id;
            const collab = this.collaborators.find(c => c.caseTeamMemberId === ctmId);
            if (!collab) return;
            this.collaborators = this.collaborators.filter(c => c.caseTeamMemberId !== ctmId);
            try {
                await removeCollaborator({ caseTeamMemberId: ctmId });
                await this._remountPicker();
            } catch (err) {
                this._toast(err?.body?.message || 'Failed to remove collaborator.', 'error', 'Error');
                await this._loadData();
                await this._remountPicker();
            }
            */
        }

    // ── Getters ───────────────────────────────────────────────────────────────

    get isClosed() {
        return this.caseRecord?.IsClosed === true;
    }

    get showReopenButton() {
        return this.isClosed && this.canReopen;
    }
    
    get isEscalated() {
        return this.caseRecord?.IsEscalated === true;
    }

    get statusBadgeClass() {
        const status = this.caseRecord?.Status || '';
        return STATUS_BADGE_MAP[status] || 'cd-badge cd-status-default';
    }

    get accountId() {
        return this.caseRecord?.AccountId || null;
    }

    // Getters — keep, return safe values:
    get hasCollaborators() {
        return false; // COLLAB_SUPPRESSED: always false while section is hidden
    }

    get existingCollaboratorUserIds() {
        return []; // COLLAB_SUPPRESSED: always empty while section is hidden
    }

    get closeReasonSelectClass() {
        return this.showClosedReasonError
            ? 'cd-select cd-select--error'
            : 'cd-select';
    }

    get reopenReasonClass() {
        return this.showReopenReasonError
            ? 'cd-textarea cd-input--error'
            : 'cd-textarea';
    }

    get isConfirmCloseDisabled()  { return this.isClosing; }
    get isConfirmReopenDisabled() { return this.isReopening; }

    // ── Private Utilities ─────────────────────────────────────────────────────

    stopPropagation(e) {
        e.stopPropagation();
    }

    _toast(message, variant, title) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}