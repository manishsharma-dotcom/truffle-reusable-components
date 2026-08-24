/**
 * caseListView.js
 * Controller for the Case List View LWC used on Experience Cloud.
 *
 * Two personas (determined by Custom Permission "Case_Admin_Access"):
 *   Admin    → All Cases, all Accounts in filter, bulk Close 
 *   Customer → My Cases, own Accounts in filter, New button only
 */
import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent }           from 'lightning/platformShowToastEvent';
import { NavigationMixin }          from 'lightning/navigation';
import isAdminUser    from '@salesforce/apex/TF_EX_CaseListViewController.isAdminUser';
import getAccounts    from '@salesforce/apex/TF_EX_CaseListViewController.getAccounts';
import getCases       from '@salesforce/apex/TF_EX_CaseListViewController.getCases';
import closeCasesApex from '@salesforce/apex/TF_EX_CaseListViewController.closeCases';

// ─── Constants ──────────────────────────────────────────────────────────────
const PAGE_SIZE          = 10;
const DEFAULT_SORT_FIELD = 'CaseNumber';
const DEFAULT_SORT_DIR   = 'desc';
const SEARCH_DEBOUNCE_MS = 350;

/**
 * Column definitions used to drive the table header (for:each in template).
 * sortable:false  → clicks are ignored in handleSort + non-sortable CSS applied.
 */
const COLUMN_DEFS = [
    { key: 'CaseNumber',  label: 'Case Number',  field: 'CaseNumber',   sortable: true },
    { key: 'Subject',     label: 'Subject',      field: 'Subject',      sortable: true },
    { key: 'ContactName', label: 'Contact Name', field: 'Contact.Name', sortable: true },
    { key: 'AccountName', label: 'Account Name', field: 'Account.Name', sortable: true },
    { key: 'Status',      label: 'Status',       field: 'Status',       sortable: true },
    { key: 'CaseType', label:'Case Type', field: 'RecordType.Name', sortable:true}
];

// Status → badge CSS class
const STATUS_BADGE_MAP = {
    'New'       : 'slds-truncate lv-badge lv-status-new',
    'Working'   : 'slds-truncate lv-badge lv-status-working',
    'On Hold'   : 'slds-truncate lv-badge lv-status-on-hold',
    'Escalated' : 'slds-truncate lv-badge lv-status-escalated',
    'Closed'    : 'slds-truncate lv-badge lv-status-closed',
    'Pending Reply - Customer': 'slds-truncate lv-badge lv-status-pending-customer',
};

// Priority → coloured dot class
const PRIORITY_DOT_MAP = {
    'High'   : 'lv-priority-dot lv-priority-high',
    'Medium' : 'lv-priority-dot lv-priority-medium',
    'Low'    : 'lv-priority-dot lv-priority-low'
};

//Case Type - Badges
const CASE_TYPE_MAP = {
    'Integration Request': 'slds-truncate lv-badge lv-case-type-integration',
    'Customer Support': 'slds-truncate lv-badge lv-case-type-customer-support',
    'Enrollments Support': 'slds-truncate lv-badge lv-case-type-enrollment',
    'Training': 'slds-truncate lv-badge lv-case-type-training',
}

// ─── Component ──────────────────────────────────────────────────────────────
export default class CaseListView extends NavigationMixin(LightningElement) {

    // Persona & loading
    @track isAdmin         = false;
    @track isLoading       = true;

    // Account filter state
    @track accounts           = [];   // [{accountId, accountName, isSelected, checkboxId}]
    @track isDropdownOpen     = false;
    @track accountSearchTerm  = '';

    // Case table state
    @track cases          = [];   // pre-processed display objects
    @track totalCount     = 0;
    @track pageNumber     = 1;
    @track sortField      = DEFAULT_SORT_FIELD;
    @track sortDirection  = DEFAULT_SORT_DIR;
    @track searchTerm     = '';
    @track listViewType   = 'MY_CASES';
    @track statusFilter          = 'ALL';
    @track isStatusDropdownOpen  = false;
    @track showFlow = false;

    // Row selection (plain array for reactivity)
    @track selectedRowIds = [];

    // Private
    _searchTimeout       = null;
    _boundCloseDropdown  = null;


    // ─── Lifecycle ────────────────────────────────────────────────────────────

    async connectedCallback() {
        // Close dropdown when user clicks anywhere outside the filter widget
        this._boundCloseDropdown = this.closeDropdown.bind(this);
        window.addEventListener('click', this._boundCloseDropdown);
        

        try {
            this.isAdmin = await isAdminUser();
            await this.loadAccounts();
            this._preselectPrimaryAccount();
            await this.loadCases();
        } catch (e) {
            this.handleError(e);
            this.isLoading = false;
        }
    }

    disconnectedCallback() {
        if (this._boundCloseDropdown) {
            window.removeEventListener('click', this._boundCloseDropdown);
        }
        
        if (this._searchTimeout) clearTimeout(this._searchTimeout);
    }

    // ─── Data Loading ─────────────────────────────────────────────────────────

    async loadAccounts() {
        try {
            const result = await getAccounts();
            this.accounts = result.map(acc => ({
                accountId    : acc.accountId,
                accountName  : acc.accountName,
                isPrimary      : acc.isPrimary || false,
                isSelected   : false,
                checkboxId   : 'acc-cb-' + acc.accountId,
                removePillLabel: 'Remove ' + acc.accountName
            }));
        } catch (e) {
            this.handleError(e);
        }
    }

    async loadCases() {
        this.isLoading = true;
        try {
            const accountIds = this.accounts
                .filter(a => a.isSelected)
                .map(a => a.accountId);

            const result = await getCases({
                accountIds    : accountIds,
                pageSize      : PAGE_SIZE,
                pageNumber    : this.pageNumber,
                sortField     : this.sortField,
                sortDirection : this.sortDirection,
                searchTerm    : this.searchTerm,
                listViewType  : this.listViewType,
                statusFilter  : this.statusFilter
            });

            const selSet = new Set(this.selectedRowIds);
            const offset = (this.pageNumber - 1) * PAGE_SIZE;
            this.cases = result.cases.map((c, idx) => this._mapCase(c, selSet, offset + idx + 1));
            console.log('Case list is here---->',this.cases);
            this.totalCount  = result.totalCount;
        } catch (e) {
            this.handleError(e);
        } finally {
            this.isLoading = false;
        }
    }

    /** Transform a raw Case SObject into a flat display-ready object. */
    _mapCase(c, selSet, rowNumber) {
        const isSelected = selSet.has(c.Id);
        return {
            Id            : c.Id,
            rowNumber,
            CaseNumber    : c.CaseNumber || '—',
            Subject       : c.Subject    || '—',
            ContactName   : (c.Contact  && c.Contact.Name) ? c.Contact.Name  : '—',
            AccountName   : (c.Account  && c.Account.Name) ? c.Account.Name  : '—',
            Status        : c.Status    || '—',
            CaseType      : c.RecordType.Name || '-',
            Priority      : c.Priority  || '—',
            OwnerName     : (c.Owner    && c.Owner.Name)   ? c.Owner.Name    : '—',
            FormattedDate : this._formatDate(c.CreatedDate),
            isSelected,
            rowClass          : isSelected ? 'slds-is-selected' : '',
            checkboxId        : 'row-cb-' + c.Id,
            statusBadgeClass  : STATUS_BADGE_MAP[c.Status]   || 'slds-truncate lv-badge lv-status-default',
            priorityDotClass  : PRIORITY_DOT_MAP[c.Priority] || 'lv-priority-dot lv-priority-low',
            caseTypeBadgeClass: CASE_TYPE_MAP[c.RecordType.Name] || 'slds-truncate lv-badge lv-status-default'
        };
    }

    // ─── Account Filter Handlers ──────────────────────────────────────────────

    toggleAccountDropdown(e) {
    e.stopPropagation();
    this.isDropdownOpen       = !this.isDropdownOpen;
    this.isStatusDropdownOpen = false;
    this.accountSearchTerm    = '';
}

    closeDropdown() {
    if (this.isDropdownOpen)       this.isDropdownOpen       = false;
    if (this.isStatusDropdownOpen) this.isStatusDropdownOpen = false;
}

    /** Prevents clicks inside the filter widget from reaching the window listener. */
    stopPropagation(e) {
        e.stopPropagation();
    }

    /** Prevents clicks at the root container from interfering with dropdown close. */
    handleRootClick() {
        // intentionally empty – click propagation to window is what closes the dropdown
    }

    handleAccountSearch(e) {
        this.accountSearchTerm = e.target.value;
    }

    handleAccountSelect(e) {
        const id      = e.target.value;
        const checked = e.target.checked;

        // Immutable update to trigger @track reactivity
        this.accounts = this.accounts.map(acc =>
            acc.accountId === id ? { ...acc, isSelected: checked } : acc
        );

        // Reset to page 1 and clear row selection when filter changes
        this.pageNumber     = 1;
        this.selectedRowIds = [];
        this.loadCases();
    }

    removeAccountPill(e) {
        e.stopPropagation();
        const id = e.currentTarget.dataset.id;
        this.accounts = this.accounts.map(acc =>
            acc.accountId === id ? { ...acc, isSelected: false } : acc
        );
        this.pageNumber     = 1;
        this.selectedRowIds = [];
        this.loadCases();
    }


    handleStatusFilterToggle(e) {
    e.stopPropagation();
    this.isStatusDropdownOpen = !this.isStatusDropdownOpen;
    this.isDropdownOpen = false; // close account dropdown
}

handleStatusFilterSelect(e) {
    const val = e.currentTarget.dataset.value;
    if (this.statusFilter === val) {
        this.isStatusDropdownOpen = false;
        return;
    }
    this.statusFilter        = val;
    this.isStatusDropdownOpen = false;
    this.pageNumber          = 1;
    this.selectedRowIds      = [];
    this.loadCases();
}
    // ─── Case Search Handler ──────────────────────────────────────────────────

    handleSearchChange(e) {
        const val = e.target.value;
        if (this._searchTimeout) clearTimeout(this._searchTimeout);
        this._searchTimeout = setTimeout(() => {
            this.searchTerm = val;
            this.pageNumber = 1;
            this.loadCases();
        }, SEARCH_DEBOUNCE_MS);
    }

    // ─── Sort Handler ─────────────────────────────────────────────────────────

    handleSort(e) {
        const field = e.currentTarget.dataset.field;
        const col   = COLUMN_DEFS.find(c => c.field === field);
        if (!col || !col.sortable) return;

        if (this.sortField === field) {
            this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField     = field;
            this.sortDirection = 'asc';
        }
        this.pageNumber = 1;
        this.loadCases();
    }

    // ─── Row Selection Handlers ───────────────────────────────────────────────

    handleSelectAll(e) {
        const checked    = e.target.checked;
        const pageIds    = this.cases.map(c => c.Id);
        const pageIdSet  = new Set(pageIds);

        // Toggle isSelected on all visible rows
        this.cases = this.cases.map(c => ({
            ...c,
            isSelected : checked,
            rowClass   : checked ? 'slds-is-selected' : ''
        }));

        if (checked) {
            // Merge page IDs into the overall selection (keep cross-page selections)
            this.selectedRowIds = [...new Set([...this.selectedRowIds, ...pageIds])];
        } else {
            // Remove only the current page from selection
            this.selectedRowIds = this.selectedRowIds.filter(id => !pageIdSet.has(id));
        }
    }

    handleRowSelect(e) {
        const id      = e.target.dataset.id;
        const checked = e.target.checked;

        this.cases = this.cases.map(c =>
            c.Id === id
                ? { ...c, isSelected: checked, rowClass: checked ? 'slds-is-selected' : '' }
                : c
        );

        if (checked) {
            if (!this.selectedRowIds.includes(id)) {
                this.selectedRowIds = [...this.selectedRowIds, id];
            }
        } else {
            this.selectedRowIds = this.selectedRowIds.filter(x => x !== id);
        }
    }

    handleClearSelection() {
        this.selectedRowIds = [];
        this.cases = this.cases.map(c => ({ ...c, isSelected: false, rowClass: '' }));
    }

    // ─── Action Handlers ──────────────────────────────────────────────────────

    handleNew() {
    this.showFlow = true;
}

handleCaseCreated(event) {
    const { caseId, caseNumber } = event.detail;
    this.showFlow = false;
    this.selectedRowIds = [];
    this._toast(
        `Your Case ${caseNumber || ''} has been created successfully.`,
        'success',
        'Case Created'
    );
    this[NavigationMixin.Navigate]({
        type: 'standard__recordPage',
        attributes: { recordId: caseId, actionName: 'view' }
    });
}

handleModalClosed() {
    this.showFlow = false;
}

handleFlowCancel() {
    // Delegate cancel to child — child cleans up files then fires modalclosed
    const child = this.template.querySelector('c-case-community-create');
    if (child) {
        child.cancel();
    } else {
        this.showFlow = false;
    }
}

    async handleCloseCases() {
        if (!this.selectedRowIds.length) {
            this._toast('Please select at least one case to close.', 'info', 'Info');
            return;
        }
        this.isLoading = true;
        try {
            await closeCasesApex({ caseIds: this.selectedRowIds });
            this._toast(
                `${this.selectedRowIds.length} case(s) closed successfully.`,
                'success',
                'Success'
            );
            this.selectedRowIds = [];
            await this.loadCases();
        } catch (e) {
            this.handleError(e);
            this.isLoading = false;
        }
    }


    /** Navigate to the case record page. */
    handleCaseClick(e) {
        e.preventDefault();
        const caseId = e.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type       : 'standard__recordPage',
            attributes : {
                recordId   : caseId,
                actionName : 'view'
            }
        });
    }

    // ─── Pagination Handlers ──────────────────────────────────────────────────

    handlePrevPage() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.loadCases();
        }
    }

    handleNextPage() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.loadCases();
        }
    }

    // ─── Getters (computed properties) ───────────────────────────────────────

    get listViewTitle() {
    const isAccount = this.listViewType === 'MY_ACCOUNT_CASES';
    const base      = isAccount ? 'My Account' : 'My';
    if (this.statusFilter === 'OPEN')   return `${base} Open Cases`;
    if (this.statusFilter === 'CLOSED') return `${base} Closed Cases`;
    return isAccount ? 'My Account Cases' : 'My Cases';
}

get statusFilterLabel() {
    if (this.statusFilter === 'OPEN')   return 'Status: Open';
    if (this.statusFilter === 'CLOSED') return 'Status: Closed';
    return 'Status: All';
}

get statusFilterBtnClass() {
    return 'lv-filter-btn' + (this.statusFilter !== 'ALL' ? ' lv-filter-btn--active' : '');
}

get statusDropdownChevronIcon() {
    return this.isStatusDropdownOpen ? 'utility:chevronup' : 'utility:chevrondown';
}

get isStatusAll()    { return this.statusFilter === 'ALL'; }
get isStatusOpen()   { return this.statusFilter === 'OPEN'; }
get isStatusClosed() { return this.statusFilter === 'CLOSED'; }

get statusOptionAllClass() {
    return 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small'
        + (this.statusFilter === 'ALL' ? ' slds-is-selected' : '');
}
get statusOptionOpenClass() {
    return 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small'
        + (this.statusFilter === 'OPEN' ? ' slds-is-selected' : '');
}
get statusOptionClosedClass() {
    return 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small'
        + (this.statusFilter === 'CLOSED' ? ' slds-is-selected' : '');
}

    get showListViewToggle() {
    return this.isAdmin;
    }

    get isMyAccountCases() {
    return this.listViewType === 'MY_ACCOUNT_CASES';
    }

    get isMyAccountCasesBtnClass() {
    return this.listViewType === 'MY_ACCOUNT_CASES'
        ? 'lv-toggle-btn lv-toggle-btn--active'
        : 'lv-toggle-btn';
    }

    get isMyCasesBtnClass() {
    return this.listViewType === 'MY_CASES'
        ? 'lv-toggle-btn lv-toggle-btn--active'
        : 'lv-toggle-btn';
    }

    /**
     * Returns column definition objects enriched with sort state for the template.
     */
    get columns() {
        console.log('COLUMN_DEFS-->',COLUMN_DEFS);
        return COLUMN_DEFS.map(col => {
            const isSorted    = this.sortField === col.field;
            const isDesc      = isSorted && this.sortDirection === 'desc';
            const thClasses   = [
                col.sortable ? 'slds-is-sortable' : 'lv-col-unsortable',
                isSorted ? 'slds-is-sorted'    : '',
                isDesc   ? 'slds-is-sorted_desc' : ''
            ].filter(Boolean).join(' ');

            return {
                ...col,
                isSorted,
                sortIconName : isDesc ? 'utility:arrowdown' : 'utility:arrowup',
                thClass      : thClasses
            };
        });
    }

    // Account filter getters
    get filteredAccounts() {
        if (!this.accountSearchTerm) return this.accounts;
        const q = this.accountSearchTerm.toLowerCase();
        return this.accounts.filter(a => a.accountName.toLowerCase().includes(q));
    }

    get selectedAccounts() {
        return this.accounts.filter(a => a.isSelected);
    }

    get hasSelectedAccounts() {
        return this.accounts.some(a => a.isSelected);
    }

    get hasFilteredAccounts() {
        return this.filteredAccounts.length > 0;
    }

    get accountFilterLabel() {
        const selected = this.accounts.filter(a => a.isSelected);
        if (selected.length === 0) return 'Account: All';
        if (selected.length === 1) return `Account: ${selected[0].accountName}`;
        return `Accounts: ${selected.length} selected`;
    }

    get filterBtnClass() {
        return this.hasSelectedAccounts
            ? 'slds-button lv-filter-btn lv-filter-btn--active'
            : 'slds-button lv-filter-btn';
    }

    get dropdownChevronIcon() {
        return this.isDropdownOpen ? 'utility:chevronup' : 'utility:chevrondown';
    }

    // Row selection getters
    get hasSelectedRows() {
        return this.selectedRowIds.length > 0;
    }

    get selectedCount() {
        return this.selectedRowIds.length;
    }

    get isAllSelected() {
        return this.cases.length > 0 && this.cases.every(c => c.isSelected);
    }

    // Table state getters
    get hasCases() {
        return this.cases.length > 0;
    }

    get emptyCases() {
        return !this.isLoading && this.cases.length === 0;
    }

    // Pagination getters
    get totalPages() {
        return Math.max(1, Math.ceil(this.totalCount / PAGE_SIZE));
    }

    get isPrevDisabled() {
        return this.pageNumber <= 1;
    }

    get isNextDisabled() {
        return this.pageNumber >= this.totalPages;
    }

    get paginationLabel() {
        if (this.totalCount === 0) return '0 items';
        const start = (this.pageNumber - 1) * PAGE_SIZE + 1;
        const end   = Math.min(this.pageNumber * PAGE_SIZE, this.totalCount);
        return `${start}–${end} of ${this.totalCount} item${this.totalCount !== 1 ? 's' : ''}`;
    }

    /** Short count shown in the page header subtitle. */
    get paginationMeta() {
        if (this.isLoading && this.totalCount === 0) return 'Loading…';
        return `${this.totalCount} item${this.totalCount !== 1 ? 's' : ''}`;
    }

    // ─── Private Utilities ────────────────────────────────────────────────────

    _preselectPrimaryAccount() {
    const primary = this.accounts.find(a => a.isPrimary);
    if (primary) {
        this.accounts = this.accounts.map(a => ({
            ...a,
            isSelected: a.accountId === primary.accountId
        }));
    }
}

    _formatDate(dateStr) {
        if (!dateStr) return '—';
        try {
            return new Date(dateStr).toLocaleDateString('en-US', {
                month : 'short',
                day   : '2-digit',
                year  : 'numeric'
            });
        } catch (_) {
            return dateStr;
        }
    }

    _toast(message, variant, title) {
        this.dispatchEvent(new ShowToastEvent({ title: title || variant, message, variant }));
    }

    handleError(error) {
        const msg = error?.body?.message || error?.message || 'An unexpected error occurred.';
        this._toast(msg, 'error', 'Error');
    }

    get showAccountFilter() {
    return this.accounts.length > 1;
    }


    handleListViewChange(e) {
    const selected = e.currentTarget.dataset.type;
    if (this.listViewType === selected) return;
    this.listViewType   = selected;
    this.pageNumber     = 1;
    this.selectedRowIds = [];
    this.loadCases();
}
}