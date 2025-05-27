// Zotero Runtime
const Zotero = {
    // Core translator loading
    loadTranslator: function(type) {
        return new Translator(type);
    },
    
    // Item selection (for multiple items)
    selectItems: async function(items) {
        // Send message to native code to handle item selection
        window.webkit.messageHandlers.zotero.postMessage({
            type: 'selectItems',
            items: items
        });
        
        // Return a promise that will be resolved by native code
        return new Promise((resolve) => {
            window.zoteroResolveSelection = resolve;
        });
    }
};

// Zotero Utilities (ZU)
const ZU = {
    // XPath utilities
    xpath: function(doc, xpath) {
        return doc.evaluate(xpath, doc, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
    },
    
    xpathText: function(doc, xpath) {
        const result = this.xpath(doc, xpath);
        return result.snapshotLength > 0 ? result.snapshotItem(0).textContent : null;
    },
    
    // String utilities
    trimInternal: function(str) {
        return str ? str.replace(/^\s+|\s+$/g, '') : '';
    },
    
    // Author utilities
    cleanAuthor: function(author, type) {
        if (!author) return null;
        
        // Basic author name parsing
        const parts = author.split(' ');
        if (parts.length === 1) {
            return {
                lastName: parts[0],
                creatorType: type
            };
        }
        
        return {
            firstName: parts[0],
            lastName: parts.slice(1).join(' '),
            creatorType: type
        };
    },
    
    // Array utilities
    arrayUnique: function(arr) {
        return [...new Set(arr)];
    },
    
    // Date utilities
    strToISO: function(dateStr) {
        if (!dateStr) return null;
        try {
            return new Date(dateStr).toISOString().split('T')[0];
        } catch (e) {
            return null;
        }
    }
};

// Basic Translator class
class Translator {
    constructor(type) {
        this.type = type;
        this.handlers = {};
    }
    
    setTranslator(id) {
        this.translatorId = id;
    }
    
    setDocument(doc) {
        this.doc = doc;
    }
    
    setHandler(event, handler) {
        this.handlers[event] = handler;
    }
    
    async getTranslatorObject() {
        return this;
    }
    
    // Helper function to create a new item
    createItem() {
        return {
            itemType: '',
            title: '',
            creators: [],
            date: '',
            abstractNote: '',
            url: '',
            attachments: [],
            tags: [],
            notes: [],
            seeAlso: []
        };
    }
    
    // Helper function to complete an item
    completeItem(item) {
        if (this.handlers.itemDone) {
            this.handlers.itemDone(null, item);
        }
    }
}

// Export for use in other scripts
window.Zotero = Zotero;
window.ZU = ZU; 