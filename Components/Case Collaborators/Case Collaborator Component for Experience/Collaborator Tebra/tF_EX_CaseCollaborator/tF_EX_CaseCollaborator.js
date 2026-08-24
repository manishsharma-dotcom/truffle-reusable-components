/**
 * caseCollaborator.js
 *
 * Reusable multi-select collaborator picker.
 *
 * Inputs:
 *   @api accountId  — filters users to those whose Contact is linked
 *                     to this Account via AccountContactRelation.
 *                     When this changes the user list reloads automatically.
 *
 * Outputs / Events:
 *   collaboratorchange — fires on every selection change.
 *                        detail: { selectedUserIds: ['id1', 'id2', ...] }
 *
 * Usage:
 *   <c-case-collaborator
 *       account-id={accountId}
 *       oncollaboratorchange={handleCollaboratorChange}>
 *   </c-case-collaborator>
 *
 * Can be placed on a Case detail page later by passing the Case's AccountId.
 */
import { LightningElement, api, track } from 'lwc';
import getCollaborators from '@salesforce/apex/TF_EX_CaseCommunityCreateController.getCollaborators';

export default class CaseCollaborator extends LightningElement {

    // ── Public API ────────────────────────────────────────────────────────────

    /**
     * When accountId changes the collaborator list is re-fetched automatically.
     * Pass null or '' to show the "Select an account first" hint.
     */
    @api
    get accountId() { return this._accountId; }
    set accountId(val) {
        const changed = this._accountId !== val;
        this._accountId = val;
        if (changed) {
            // Reset selection and reload when account changes
            this._selectedIds    = [];
            this._collaborators  = [];
            this.searchTerm      = '';
            this.isDropdownOpen  = false;
            if (val) this._loadCollaborators(val);
        }
    }

    // ── Internal state ────────────────────────────────────────────────────────
    @api excludedUserIds = [];
    @api hidePills       = false;

    //@api
    //get preloadedCollaborators() { return this._preloadedCollaborators; }
    //set preloadedCollaborators(val) {
    //    this._preloadedCollaborators = val ? [...val] : [];
    //}
    //@track _preloadedCollaborators = [];
    @track _collaborators         = [];   // [{userId, label, isSelected, itemClass}]
    @track _selectedIds           = [];
    @track searchTerm             = '';
    //@track isDropdownOpen         = false;
    @track isLoadingCollaborators = false;

    _accountId             = null;
    _isDropdownOpen        = false;
    _boundCloseDropdown    = null;

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    connectedCallback() {}
    disconnectedCallback() {}

    // ── Data loading ──────────────────────────────────────────────────────────

    async _loadCollaborators(accountId) {
        this.isLoadingCollaborators = true;
        try {
            const result = await getCollaborators({ accountId });
            this._collaborators = result.map(c => ({
                userId    : c.userId,
                label     : c.label,
                isSelected: false,
                itemClass : 'cb-item'
            }));
        } catch (e) {
            console.error('caseCollaborator: failed to load collaborators —', e);
            this._collaborators = [];
        } finally {
            this.isLoadingCollaborators = false;
        }
    }

    // ── Handlers ──────────────────────────────────────────────────────────────

    handleFocus() {
        if (this._accountId) this.isDropdownOpen = true;
    }

    /*handlePillRemove(e) {
        const userId      = e.currentTarget.dataset.id;
        const pillType    = e.currentTarget.dataset.pilltype;
        if (pillType === 'preloaded') {
            this.dispatchEvent(new CustomEvent('collaboratorremove', {
                detail: { userId }
            }));
        } else {
            this._selectedIds = this._selectedIds.filter(x => x !== userId);
            this._refreshClasses();
            this._fireChange();
        }
    }

    get allCollaboratorPills() {
        const preloaded = (this._preloadedCollaborators || []).map(c => ({
            key     : 'pre-' + c.userId,
            userId  : c.userId,
            label   : c.userName,
            pillType: 'preloaded'
        }));
        const preloadedUserIds = new Set(preloaded.map(c => c.userId));
        const selSet   = new Set(this._selectedIds);
        const selected = this._collaborators
            .filter(c => selSet.has(c.userId) && !preloadedUserIds.has(c.userId))
            .map(c => ({
                key     : 'sel-' + c.userId,
                userId  : c.userId,
                label   : c.label,
                pillType: 'selected'
            }));
        return [...preloaded, ...selected];
    }

    handleRemove(e) {
        const id = e.currentTarget.dataset.id;
        this._selectedIds = this._selectedIds.filter(x => x !== id);
        this._refreshClasses();
        this._fireChange();
    }*/

    /*get hasAnyCollaboratorPills() {
        return this.allCollaboratorPills.length > 0;
    }*/

    handleSearch(e) {
        this.searchTerm    = e.target.value;
        this.isDropdownOpen = !!this._accountId;
    }

    handleSelect(e) {
        const id = e.currentTarget.dataset.id;
        if (this._selectedIds.includes(id)) {
            this._selectedIds = this._selectedIds.filter(x => x !== id);
        } else {
            this._selectedIds = [...this._selectedIds, id];
        }
        this._refreshClasses();
        this.searchTerm = '';
        this.isDropdownOpen = false;
        this._fireChange();
    }

    handleRemove(e) {
        const id = e.currentTarget.dataset.id;
        this._selectedIds = this._selectedIds.filter(x => x !== id);
        this._refreshClasses();
        this._fireChange();
    }

    stopPropagation(e) {
        e.stopPropagation();
    }

    // ── Getters ───────────────────────────────────────────────────────────────

    get showAccountHint()  { return !this._accountId; }
    get isDisabled()       { return !this._accountId; }
    get isDropdownOpen()   { return this._isDropdownOpen; }
    set isDropdownOpen(v)  { this._isDropdownOpen = v; }


    get filteredCollaborators() {
        const excluded = new Set(this.excludedUserIds || []);
        const base = this._collaborators.filter(c => !excluded.has(c.userId));
        if (!this.searchTerm) return base;
        const q = this.searchTerm.toLowerCase();
        return base.filter(c => c.label.toLowerCase().includes(q));
    }
    
    get hasFilteredCollaborators() { return this.filteredCollaborators.length > 0; }

    get selectedCollaborators() {
        const selSet = new Set(this._selectedIds);
        return this._collaborators.filter(c => selSet.has(c.userId));
    }

    get hasSelectedCollaborators() { return !this.hidePills && this._selectedIds.length > 0; }
    // ── Private helpers ───────────────────────────────────────────────────────

    _refreshClasses() {
        const selSet = new Set(this._selectedIds);
        this._collaborators = this._collaborators.map(c => ({
            ...c,
            isSelected: selSet.has(c.userId),
            itemClass : 'cb-item' + (selSet.has(c.userId) ? ' cb-item--active' : '')
        }));
    }

    _fireChange() {
        this.dispatchEvent(new CustomEvent('collaboratorchange', {
            detail: { selectedUserIds: [...this._selectedIds] }
        }));
    }

    handleBlur() {
    // Delay lets handleSelect fire before dropdown closes
    setTimeout(() => {
        this.isDropdownOpen = false;
    }, 200);
}
}