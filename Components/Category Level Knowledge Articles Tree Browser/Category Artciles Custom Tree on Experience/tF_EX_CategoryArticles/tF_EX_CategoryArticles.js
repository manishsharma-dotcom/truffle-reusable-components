import { LightningElement, wire, track } from 'lwc';
import { subscribe, MessageContext } from 'lightning/messageService';
import CATEGORY_SELECTED from '@salesforce/messageChannel/tF_EX_CategorySelected__c';
import getArticles from '@salesforce/apex/TF_EX_DataCategoryController.getArticles';

const PAGE_SIZE    = 10;
const ARTICLE_BASE = '/s/article/';

// Format a date string to "Apr 9, 2026"
function formatDate(dateStr) {
    if (!dateStr) return '';
    try {
        const d = new Date(dateStr);
        return d.toLocaleDateString('en-US', {
            month: 'short', day: 'numeric', year: 'numeric'
        });
    } catch (e) { return ''; }
}

export default class TF_EX_CategoryArticles extends LightningElement {

    @track isLoading           = false;
    @track _allArticles        = [];
    @track _currentPage        = 1;

    selectedCategory      = null;
    selectedGroup         = null;
    selectedCategoryLabel = '';
    subscription          = null;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this._subscribe();
    }

    disconnectedCallback() {
        // Subscription is cleaned up automatically by LWC
    }

    // ── Subscribe to message channel ────────────────────────────────────────
    _subscribe() {
        if (this.subscription) return;
        this.subscription = subscribe(
            this.messageContext,
            CATEGORY_SELECTED,
            msg => this._handleMessage(msg)
        );
    }

    _handleMessage(msg) {
    this.selectedCategory      = msg.categoryName;
    this.selectedGroup         = msg.groupName;
    // Use the label sent from tree, fall back to API name formatting
    this.selectedCategoryLabel = msg.categoryLabel || 
                                 (msg.categoryName || '').replace(/_/g, ' ');
    this._currentPage          = 1;
    this._loadArticles();
}

    // ── Load articles ───────────────────────────────────────────────────────
    _loadArticles() {
        if (!this.selectedCategory || !this.selectedGroup) return;
        this.isLoading    = true;
        this._allArticles = [];

        getArticles({
            groupName: this.selectedGroup,
            categName: this.selectedCategory
        })
            .then(data => {
                this.isLoading    = false;
                this._allArticles = (data || []).map(art => ({
                    ...art,
                    formattedDate: formatDate(art.LastPublishedDate),
                    articleUrl   : `${ARTICLE_BASE}${art.UrlName}`
                }));
            })
            .catch(err => {
                console.error('getArticles error:', JSON.stringify(err));
                this.isLoading    = false;
                this._allArticles = [];
            });
    }

    // ── Computed getters ────────────────────────────────────────────────────
    get hasCategory() {
        return !!this.selectedCategory;
    }

    get isEmpty() {
        return !this.isLoading && this._allArticles.length === 0;
    }

    get totalPages() {
        return Math.ceil(this._allArticles.length / PAGE_SIZE) || 1;
    }

    get pageArticles() {
        const start = (this._currentPage - 1) * PAGE_SIZE;
        return this._allArticles.slice(start, start + PAGE_SIZE);
    }

    get showPagination() {
        return this._allArticles.length > PAGE_SIZE;
    }

    get isPrevDisabled() {
        return this._currentPage <= 1;
    }

    get isNextDisabled() {
        return this._currentPage >= this.totalPages;
    }

    get paginationInfo() {
        const start = (this._currentPage - 1) * PAGE_SIZE + 1;
        const end   = Math.min(this._currentPage * PAGE_SIZE, this._allArticles.length);
        return `${start}–${end} of ${this._allArticles.length}`;
    }

    // ── Pagination handlers ─────────────────────────────────────────────────
    handlePrevPage() {
        if (this._currentPage > 1) {
            this._currentPage -= 1;
        }
    }

    handleNextPage() {
        if (this._currentPage < this.totalPages) {
            this._currentPage += 1;
        }
    }

    // ── Article click ───────────────────────────────────────────────────────
    handleArticleClick(evt) {
        evt.preventDefault();
        const url = evt.currentTarget.dataset.url;
        if (url) window.location.href = url;
    }
}