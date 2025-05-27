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
            script.src = path;
            script.onload = resolve;
            script.onerror = reject;
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