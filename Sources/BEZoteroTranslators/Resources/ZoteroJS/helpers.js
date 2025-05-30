// Zotero initialization and cleanup helpers
window.ZoteroHelpers = {
    // Clean up Zotero objects
    cleanup: function() {
        if (window.Zotero) {
            delete window.Zotero;
        }
        if (window.ZoteroLoader) {
            delete window.ZoteroLoader;
        }
        if (window.zoteroTranslator) {
            delete window.zoteroTranslator;
        }
        return true;
    },

    // Initialize Zotero
    initialize: async function() {
        try {
            if (!window.ZoteroLoader) {
                throw new Error('ZoteroLoader not found');
            }
            
            await ZoteroLoader.load();
            
            if (!window.Zotero) {
                window.Zotero = new Zotero();
            }
            
            // Verify initialization
            if (typeof window.Zotero !== 'object') {
                throw new Error('Zotero initialization failed');
            }
            
            return true;
        } catch (e) {
            console.error('Failed to initialize Zotero:', e);
            // Cleanup on error
            this.cleanup();
            throw e;
        }
    },

    // Load and initialize a translator
    loadTranslator: function(translatorCode) {
        try {
            console.log('Initializing translator...');
            // Wait for Zotero to be available
            if (typeof Zotero === 'undefined') {
                throw new Error('Zotero runtime not loaded');
            }
            
            // Create a function from the translator code
            const translatorFunction = new Function('return ' + translatorCode);
            const translator = translatorFunction();
            
            // Validate required functions
            const requiredFunctions = ['detectWeb', 'doWeb'];
            for (const func of requiredFunctions) {
                if (typeof translator[func] !== 'function') {
                    throw new Error(`Missing required function: ${func}`);
                }
            }
            
            // Create a new translator instance
            window.zoteroTranslator = new Zotero.Translator('web');
            
            // Copy the functions from our translator
            window.zoteroTranslator.detectWeb = translator.detectWeb;
            window.zoteroTranslator.doWeb = translator.doWeb;
            window.zoteroTranslator.getSearchResults = translator.getSearchResults;
            window.zoteroTranslator.scrape = translator.scrape;
            
            // Set up the translator
            window.zoteroTranslator.setTranslator('951c027d-74ac-47d4-a107-9c3069ab7b48');
            window.zoteroTranslator.setDocument(document);
            
            console.log('Translator initialized successfully');
            return true;
        } catch (e) {
            console.error('Error initializing translator:', e);
            throw e;
        }
    },

    // Detect web type
    detectWeb: function() {
        try {
            if (!window.zoteroTranslator) {
                throw new Error('Translator not initialized');
            }
            
            // Validate translator state
            if (!window.zoteroTranslator.detectWeb) {
                throw new Error('Translator missing detectWeb function');
            }
            
            const type = window.zoteroTranslator.detectWeb(document, window.location.href);
            if (!type) {
                throw new Error('No type detected');
            }
            
            // Validate the detected type
            if (typeof type !== 'string') {
                throw new Error('Invalid type returned: ' + typeof type);
            }
            
            return type;
        } catch (e) {
            console.error('Error in detectWeb:', e);
            throw e;
        }
    },

    // Scrape the page
    scrape: function() {
        try {
            console.log('Executing doWeb...');
            if (!window.zoteroTranslator) {
                throw new Error('Translator not initialized');
            }
            
            // Validate translator state
            if (!window.zoteroTranslator.doWeb) {
                throw new Error('Translator missing doWeb function');
            }
            
            const result = window.zoteroTranslator.doWeb(document, window.location.href);
            
            // Validate result
            if (!result) {
                throw new Error('No result returned from doWeb');
            }
            
            if (!Array.isArray(result)) {
                throw new Error('Invalid result type: ' + typeof result);
            }
            
            // Validate each item in the result
            for (let i = 0; i < result.length; i++) {
                const item = result[i];
                if (typeof item !== 'object') {
                    throw new Error(`Invalid item type at index ${i}: ${typeof item}`);
                }
                
                // Check for required fields
                const requiredFields = ['itemType', 'title'];
                for (const field of requiredFields) {
                    if (!(field in item)) {
                        throw new Error(`Missing required field '${field}' in item at index ${i}`);
                    }
                }
            }
            
            console.log('doWeb completed with result:', result);
            return result;
        } catch (e) {
            console.error('Error in doWeb:', e);
            throw e;
        }
    },

    // Resolve item selection
    resolveSelection: function(selectedItems) {
        try {
            if (!window.zoteroTranslator) {
                throw new Error('Translator not initialized');
            }
            
            // Implementation depends on your specific needs
            // This is a placeholder for the actual implementation
            console.log('Resolving selection:', selectedItems);
            return true;
        } catch (e) {
            console.error('Error resolving selection:', e);
            throw e;
        }
    }
}; 