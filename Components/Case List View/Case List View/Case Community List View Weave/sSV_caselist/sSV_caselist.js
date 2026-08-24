import { LightningElement, track, api } from 'lwc';
import getCaseList from '@salesforce/apex/SSV_PortalCaseListController.getCaseList';
import getCaseCount from '@salesforce/apex/SSV_PortalCaseListController.getCaseCount';
import SSV_WeaveHC from '@salesforce/resourceUrl/SSV_WeaveHC';

const imgUrl = SSV_WeaveHC + '/WeaveHCR/img/zigzag.svg';

export default class SSV_caselist extends LightningElement {
    imgUrl = imgUrl;
    @track bannercss;
    @track sortedBy;
    @track sortedDirection = 'asc';
    
    columns;
    @track allCases = [];
    @track visibleCases = [];
    showData = false;
    showSpinner = true;
    totalCount = 0;
    @track currentOffset = 0;
    @track limitSize = 1000;

    @api pagesize = 25;
    @api submitACaseURL;
    @api communityPath;

    hasMore = false;
    disabledHasMore = false;
    error = '';
    searchText = '';
    currentListView = 'My Open Cases';

    PRIORITY_ORDER = {
        'Urgent': 1,
        'High': 2,
        'Medium': 3,
        'Low': 4
    };

    get listViewOptions() {
        return [
            { label: 'My Open Cases', value: 'My Open Cases' },
            { label: 'My Closed Cases', value: 'My Closed Cases' },
            { label: 'My Company Cases - Open', value: 'My Company Cases - Open' },
            { label: 'My Company Cases - Closed', value: 'My Company Cases - Closed' },
        ];
    }

    connectedCallback() {
        this.bannercss = "height: 70px;background-repeat: no-repeat;background-image:url('" + this.imgUrl + "')";
        this.fetchCaseCountOnly();
        this.fetchMoreCasesFromApex();
    }

    get showMoreButtonDisabled() {
        return this.disabledHasMore || this.visibleCases.length >= this.totalCount;
    }

    fetchMoreCasesFromApex() {
        this.showSpinner = true;

        getCaseList({
            searchText: this.searchText,
            listView: this.currentListView,
            limitSize: this.limitSize,
            offsetVal: this.currentOffset 
        })
        .then(result => {
            if (!this.communityPath) {
                this.communityPath = "";
            }
            const newCases = result.caseData.map(row => {
                return { ...row, caseNumberURL: this.communityPath + '/' + row.Id };
            });

            this.allCases = [...this.allCases, ...newCases];
            this.currentOffset += newCases.length;
            this.columns = result.columns;

            this.updateVisibleCases();
            this.showData = this.visibleCases.length > 0;
            this.hasMore = this.visibleCases.length < this.totalCount;
            this.showSpinner = false;
            this.disabledHasMore = false;
        })
        .catch(error => {
            this.error = error;
            console.error('Error fetching case list: ', error);
            this.allCases = [];
            this.visibleCases = [];
            this.disabledHasMore = false;
            this.showSpinner = false;
        });
    }

    updateVisibleCases() {
        const nextBatch = this.allCases.slice(this.visibleCases.length, this.visibleCases.length + this.pagesize);
        this.visibleCases = [...this.visibleCases, ...nextBatch];
        this.hasMore = this.visibleCases.length < this.totalCount;
    }
    
    handleShowMore() {
        this.disabledHasMore = true;
    
        if (this.visibleCases.length < this.allCases.length) {
            this.updateVisibleCases();
            this.disabledHasMore = false;
        } else if (this.allCases.length < this.totalCount) {
            this.fetchMoreCasesFromApex();
        } else {
            this.hasMore = false;
            this.disabledHasMore = false;
        }
    }
    

    fetchCaseCountOnly() {
        getCaseCount({
            searchText: this.searchText,
            listView: this.currentListView
        })
        .then(count => {
            this.totalCount = count;
            this.hasMore = this.visibleCases.length < this.totalCount;
        })
        .catch(error => {
            console.error('Error fetching count: ', error);
        });
    }

    handleKeyUpSearch(evt) {
        window.clearTimeout(this.delayTimeout);
        const searchKey = evt.target.value;

        this.delayTimeout = setTimeout(() => {
            this.searchText = searchKey;
            this.resetCases();
        }, 500);
    }

    handleClear() {
        this.searchText = '';
        this.resetCases();
    }

    handleListViewChange(evt) {
        this.currentListView = evt.target.value;
        this.resetCases();
    }

    resetCases() {
        this.allCases = [];
        this.visibleCases = [];
        this.columns = null;
        this.currentOffset = 0;
        this.fetchCaseCountOnly();
        this.fetchMoreCasesFromApex();
    }
    
    getPriorityValue(priority) {
        return this.PRIORITY_ORDER[priority] || 999;
    }    

    handleSort(event) {
        let { fieldName, sortDirection } = event.detail;

        if (fieldName === 'caseNumberURL') {
            fieldName = 'CaseNumber';
        }
        let dataToSort = Array.isArray(this.visibleCases) ? [...this.visibleCases] : [];
    
        if (fieldName === 'Priority') {
            dataToSort.sort((a, b) => {
                const valA = this.PRIORITY_ORDER[a.Priority] || 999;
                const valB = this.PRIORITY_ORDER[b.Priority] || 999;
                return sortDirection === 'asc' ? valA - valB : valB - valA;
            });
        } 
        else if (fieldName === 'CaseNumber') {
            dataToSort.sort((a, b) => {
                const valA = Number(a[fieldName]) || 0;
                const valB = Number(b[fieldName]) || 0;
                return sortDirection === 'asc' ? valA - valB : valB - valA;
            });
        }

        else if (fieldName === 'CreatedDate') {
            dataToSort.sort((a, b) => {
                const valA = new Date(a[fieldName]);
                const valB = new Date(b[fieldName]);
                return sortDirection === 'asc' ? valA - valB : valB - valA;
            });

        }
        
        else {
            dataToSort.sort((a, b) => {
                const valA = (a[fieldName] || '').toString().toLowerCase();
                const valB = (b[fieldName] || '').toString().toLowerCase();
                return sortDirection === 'asc'
                    ? valA.localeCompare(valB)
                    : valB.localeCompare(valA);
            });
        }
    
        this.visibleCases = dataToSort;
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = sortDirection;
    }
    
    
}