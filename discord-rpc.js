// Discord RPC Integration for MangaBox
// Based on Discord-RPC-Extension API

class DiscordRPC {
    constructor() {
        this.extensionId = this.getExtensionId();
        this.clientId = '1387138193165389895'; // Replace with your Discord Application ID
        this.isRegistered = false;
        this.isEnabled = false;
        this.currentActivity = null;
        this.activityTimeout = null;
        
        this.init();
    }

    getExtensionId() {
        // Detect browser and return appropriate extension ID
        if (typeof browser !== 'undefined' && typeof chrome !== "undefined") {
            return "{57081fef-67b4-482f-bcb0-69296e63ec4f}"; // Firefox
        } else {
            return "agnaejlkbiiggajjmnpmeheigkflbnoo"; // Chrome
        }
    }

    async init() {
        try {
            // Check if chrome extension API is available
            if (typeof chrome === 'undefined' || !chrome.runtime || !chrome.runtime.sendMessage) {
                throw new Error('Chrome extension API not available');
            }
            
            await this.register();
            this.setupMessageListener();
            this.isEnabled = true;
            console.log('Discord RPC initialized successfully');
        } catch (error) {
            console.warn('Discord RPC extension not found or failed to initialize:', error);
            this.isEnabled = false;
        }
    }

    async register() {
        return new Promise((resolve, reject) => {
            try {
                chrome.runtime.sendMessage(this.extensionId, { mode: 'passive' }, (response) => {
                    if (chrome.runtime.lastError) {
                        reject(new Error(`Extension communication failed: ${chrome.runtime.lastError.message}`));
                    } else {
                        this.isRegistered = true;
                        console.log('Discord RPC registered');
                        resolve(response);
                    }
                });
            } catch (error) {
                reject(new Error(`Failed to communicate with Discord RPC extension: ${error.message}`));
            }
        });
    }

    setupMessageListener() {
        chrome.runtime.onMessage.addListener((info, sender, sendResponse) => {
            console.log('Discord RPC presence requested', info);
            
            if (this.currentActivity) {
                sendResponse({
                    clientId: this.clientId,
                    presence: this.currentActivity
                });
            } else {
                // Return empty object to keep registration but show no presence
                sendResponse({
                    clientId: this.clientId,
                    presence: {}
                });
            }
        });
    }

    async setActivity(activity) {
        if (!this.isEnabled || !this.isRegistered) return;
        
        this.currentActivity = {
            details: activity.details || '',
            state: activity.state || '',
            startTimestamp: activity.startTimestamp || Date.now(),
            largeImageKey: activity.largeImageKey || undefined,
            largeImageText: activity.largeImageText || undefined,
            smallImageKey: activity.smallImageKey || undefined,
            smallImageText: activity.smallImageText || undefined,
            instance: false
        };

        // Force update by re-registering
        try {
            await this.register();
        } catch (error) {
            console.warn('Failed to update Discord activity:', error);
        }
    }

    async clearActivity() {
        if (!this.isEnabled || !this.isRegistered) return;
        
        this.currentActivity = null;
        
        // Force update by re-registering
        try {
            await this.register();
        } catch (error) {
            console.warn('Failed to clear Discord activity:', error);
        }
    }

    // Debounced activity update to prevent spam
    updateActivityDebounced(activity, delay = 2000) {
        if (this.activityTimeout) {
            clearTimeout(this.activityTimeout);
        }
        
        this.activityTimeout = setTimeout(() => {
            this.setActivity(activity);
        }, delay);
    }
}

// Export for use in main application
window.DiscordRPC = DiscordRPC;
