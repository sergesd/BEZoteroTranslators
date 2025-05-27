// Core Zotero object
const Zotero = {
    // Core translator loading
    loadTranslator: function(type) {
        return new Zotero.Translator(type);
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

// Export
if (typeof module !== 'undefined' && module.exports) {
    module.exports = Zotero;
} else {
    window.Zotero = Zotero;
} 