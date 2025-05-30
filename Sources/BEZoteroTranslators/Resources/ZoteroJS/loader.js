// Zotero Loader
class ZoteroLoader {
    static async load() {
        const modules = [
            'core/Zotero.js',
            'utilities/ZU.js',
            'translators/Translator.js'
        ];
        
        for (const module of modules) {
            await this.loadModule(module);
        }
    }
    
    static async loadModule(path) {
        return new Promise((resolve, reject) => {
            const script = document.createElement('script');
            script.src = window.ZOTERO_BASE_URL + '/' + path;
            script.onload = resolve;
            script.onerror = (error) => {
                console.error('Failed to load module:', path, error);
                reject(error);
            };
            document.head.appendChild(script);
        });
    }
}

// Export
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ZoteroLoader;
} else {
    window.ZoteroLoader = ZoteroLoader;
} 