import { LightningElement, wire, track } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import CATEGORY_SELECTED from '@salesforce/messageChannel/tF_EX_CategorySelected__c';
import getCategoryTree from '@salesforce/apex/TF_EX_DataCategoryController.getCategoryTree';
import getArticleCountByCategory from '@salesforce/apex/TF_EX_DataCategoryController.getArticleCountByCategory';

const OBJECT_NAME    = 'KnowledgeArticleVersion';
const CATEGORY_GROUP = 'External';

// ---------------------------------------------------------------------------
// Flatten the tree into a single array with indent level + visibility flag.
// This lets us render arbitrary depth in a single <template for:each> in LWC
// without needing a recursive child component.
// ---------------------------------------------------------------------------
function flattenTree(nodes, expandedSet, selectedName, level = 0, parentExpanded = true) {
    const result = [];
    (nodes || []).forEach(node => {
        const hasChildren = Array.isArray(node.items) && node.items.length > 0;
        const isExpanded  = expandedSet.has(node.name);
        const isSelected  = node.name === selectedName;
        const isVisible   = parentExpanded;   // visible if parent is expanded (or root)

        // Indent class: level 0 → no indent, level 1 → indent-1, etc.
        const indentClass = level > 0 ? `indent-${Math.min(level, 4)}` : '';

        result.push({
            name        : node.name,
            label       : node.label,
            articleCount: node.articleCount || '',
            hasChildren,
            isExpanded,
            isSelected,
            isVisible,
            level,
            rowClass    : [
                'node-row',
                isSelected  ? 'node-row--selected'  : '',
                indentClass
            ].filter(Boolean).join(' '),
            chevronClass: [
                'chevron',
                isExpanded  ? 'chevron--open'        : '',
                !hasChildren ? 'chevron--hidden'     : ''
            ].filter(Boolean).join(' ')
        });

        // Recurse into children — they are visible only when THIS node is expanded
        if (hasChildren) {
            const childRows = flattenTree(
                  node.items,
                  expandedSet,
                  selectedName,
                  level + 1,
                  parentExpanded && isExpanded 
        );
            result.push(...childRows);
        }
    });
    return result;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------
export default class TF_EX_CategoryTree extends LightningElement {

    @track flatList     = [];   // flat array for single for:each
    @track isLoading    = true;

    _rawTree      = [];
    _selectedName = null;
    _expandedSet  = new Set();
    _countMap     = {};
    _defaultFired = false;

    @wire(MessageContext)
    messageContext;

    // ── Fetch tree ────────────────────────────────────────────────────────
    @wire(getCategoryTree, {
        objectName   : OBJECT_NAME,
        categoryGroup: CATEGORY_GROUP
    })
    wiredTree({ data, error }) {
        if (data) {
            this._rawTree = data;
            this._fetchCounts();
        } else if (error) {
            console.error('getCategoryTree error:', JSON.stringify(error));
            this.isLoading = false;
        }
    }

    // ── Fetch article counts (2 SOQLs total) ─────────────────────────────
    _fetchCounts() {
        getArticleCountByCategory({
            objectName   : OBJECT_NAME,
            categoryGroup: CATEGORY_GROUP
        })
            .then(countList => {
                const map = {};
                (countList || []).forEach(c => { map[c.name] = c.count; });
                this._countMap = map;
                this._applyCountsAndBuild();
            })
            .catch(() => {
                this._applyCountsAndBuild();
            });
    }

    _applyCountsAndBuild() {
        this._rawTree  = this._attachCounts(this._rawTree, this._countMap);
        this.isLoading = false;
        this._rebuild();

        // Auto-select first top-level category on load
        if (!this._defaultFired && this._rawTree.length > 0) {
            this._defaultFired = true;
            this._select(this._rawTree[0].name);
        }
    }

    _attachCounts(nodes, map) {
        return (nodes || []).map(n => ({
            ...n,
            articleCount: map[n.name] != null ? map[n.name] : '',
            items: this._attachCounts(n.items || [], map)
        }));
    }

    // ── Build flat list view-model ────────────────────────────────────────
    _rebuild() {
        const all = flattenTree(this._rawTree, this._expandedSet, this._selectedName);
        // Only render visible rows
        this.flatList = all.filter(r => r.isVisible);
    }

    // ── Select category + publish ─────────────────────────────────────────
    _select(name) {
    this._selectedName = name;
    this._rebuild();

    // Find the label for this node from the flat list
    const node = this.flatList.find(r => r.name === name);
    const label = node ? node.label : name;

    publish(this.messageContext, CATEGORY_SELECTED, {
        categoryName : name,
        categoryLabel: label,      // ← add this
        groupName    : CATEGORY_GROUP
    });
}

    // ── Row click: toggle expand + select ─────────────────────────────────
    handleRowClick(evt) {
        evt.stopPropagation();
        const name        = evt.currentTarget.dataset.name;
        const hasChildren = evt.currentTarget.dataset.hasChildren === 'true';

        if (hasChildren) {
            if (this._expandedSet.has(name)) {
                this._expandedSet.delete(name);
            } else {
                this._expandedSet.add(name);
            }
        }
        this._select(name);
    }
}