// parentComponent/parentComponent.js
import { LightningElement, api, track } from 'lwc';
import getApplicationsByPosition from '@salesforce/apex/RecruitmentController.getApplicationsByPosition';

export default class ParentComponent extends LightningElement {
    @api recordId; // ID stanowiska
    @track applications = [];
    @track selectedApplicationId;
    @track isLoading = false;
    @track error;
    
    // Pobierz listę aplikacji po załadowaniu komponentu
    connectedCallback() {
        this.loadApplications();
    }
    
    // Ładowanie aplikacji dla stanowiska
    loadApplications() {
        this.isLoading = true;
        getApplicationsByPosition({ positionId: this.recordId })
            .then(result => {
                this.applications = result;
                this.error = undefined;
                this.isLoading = false;
            })
            .catch(error => {
                this.error = error.body.message;
                this.applications = [];
                this.isLoading = false;
            });
    }
    
    // Obsługa wyboru aplikacji
    handleApplicationSelection(event) {
        this.selectedApplicationId = event.detail.applicationId;
    }
    
    // Obsługa zdarzenia analizy CV
    handleCVAnalysisComplete(event) {
        // Odśwież listę aplikacji, aby pokazać nowe statusy
        this.loadApplications();
        
        // Pokaż komunikat sukcesu używając komponentu messageBanner
        const messageBanner = this.template.querySelector('c-message-banner');
        if (messageBanner) {
            messageBanner.showMessage('Analiza CV zakończona pomyślnie', 'success');
        }
    }
    
    // Getter sprawdzający, czy wybrano aplikację
    get isApplicationSelected() {
        return !!this.selectedApplicationId;
    }
}