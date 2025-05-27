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

// Export
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ZU;
} else {
    window.ZU = ZU;
} 