import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import analyzeCandidateResume from '@salesforce/apex/CVAnalysisController.analyzeCandidateResume';

export default class CvAnalyzer extends LightningElement {
    @api recordId; // ID aplikacji lub kandydata
    @api objectApiName; // Do określenia kontekstu
    
    @track isLoading = false;
    @track analysisResults;
    @track error;
    @track showResults = false;
    
    acceptedFormats = ['.pdf', '.doc', '.docx', '.txt'];
    lastAnalyzedDocumentId = null; // Zmienna do przechowywania ID ostatniego pliku
    
    get isCandidate() {
        return this.objectApiName === 'Candidate__c';
    }
    
    get isJobApplication() {
        return this.objectApiName === 'Job_Application__c';
    }
    
    handleUpload(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.isLoading = true;
            this.lastAnalyzedDocumentId = uploadedFiles[0].documentId;
            this.analyzeCV(this.lastAnalyzedDocumentId, false);
        }
    }
    
    analyzeCV(contentDocumentId, bypassCache = false) {
        let positionId = null;
        
        if (this.isJobApplication) {
            positionId = this.recordId;
        }
        
        analyzeCandidateResume({ 
            contentDocumentId: contentDocumentId,
            positionId: positionId,
            bypassCache: bypassCache 
        })
        .then(result => {
            this.analysisResults = result;
            this.error = undefined;
            this.isLoading = false;
            this.showResults = true;
            
            // Dispatch success event
            this.dispatchEvent(new CustomEvent('analysiscomplete', {
                detail: {
                    success: true,
                    results: result
                }
            }));
            
            // Show success toast
            this.showToast('Sukces', 'Analiza CV zakończona pomyślnie', 'success');
        })
        .catch(error => {
            this.error = error;
            this.analysisResults = undefined;
            this.isLoading = false;
            this.showResults = false;
            
            // Show error toast
            this.showToast('Błąd', 'Wystąpił błąd podczas analizy CV: ' + error.body.message, 'error');
        });
    }
    
    handleForceAnalysis() {
        if (this.lastAnalyzedDocumentId) {
            this.isLoading = true;
            this.analyzeCV(this.lastAnalyzedDocumentId, true);
        } else {
            this.showToast('Błąd', 'Nie znaleziono CV do analizy', 'error');
        }
    }
    
    handleResetAnalysis() {
        this.analysisResults = undefined;
        this.error = undefined;
        this.showResults = false;
        this.lastAnalyzedDocumentId = null;
    }
    
    get hasSkills() {
        return this.analysisResults && this.analysisResults.skills && this.analysisResults.skills.length > 0;
    }
    
    get hasJobMatch() {
        return this.analysisResults && this.analysisResults.matchScore !== undefined;
    }
    
    get matchColor() {
        if (!this.hasJobMatch) return '';
        const score = this.analysisResults.matchScore;
        if (score >= 80) return 'slds-text-color_success';
        if (score >= 60) return 'slds-text-color_warning';
        return 'slds-text-color_error';
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}