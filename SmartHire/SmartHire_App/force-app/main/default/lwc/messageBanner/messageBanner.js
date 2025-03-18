// messageBanner/messageBanner.js
import { LightningElement, api, track } from 'lwc';

export default class MessageBanner extends LightningElement {
    @track message = '';
    @track variant = 'info';
    @track isVisible = false;
    
    @api
    showMessage(message, variant) {
        this.message = message;
        this.variant = variant || 'info';
        this.isVisible = true;
        
        // Automatycznie ukryj po 5 sekundach
        setTimeout(() => {
            this.hideMessage();
        }, 5000);
    }
    
    @api
    hideMessage() {
        this.isVisible = false;
    }
    
    get messageClass() {
        return `slds-notify slds-notify_alert slds-theme_${this.variant}`;
    }
    
    get iconName() {
        switch(this.variant) {
            case 'success': return 'utility:success';
            case 'warning': return 'utility:warning';
            case 'error': return 'utility:error';
            default: return 'utility:info';
        }
    }
    
    handleClose() {
        this.hideMessage();
    }
}