import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import analyzeCandidateResume from '@salesforce/apex/CVAnalysisController.analyzeCandidateResume';
import saveAnalysisResults from '@salesforce/apex/CVAnalysisController.saveAnalysisResults';

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
    
    get isAnalyzeButtonDisabled() {
        return !this.lastAnalyzedDocumentId;
    }
    
    get skills() {
        if (this.analysisResults && this.analysisResults.skills) {
            if (Array.isArray(this.analysisResults.skills)) {
                return this.analysisResults.skills;
            } else if (typeof this.analysisResults.skills === 'object') {
                // Jeśli skills to obiekt z kluczami name, zwróć listę nazw
                return Object.values(this.analysisResults.skills)
                    .filter(skill => skill && skill.name)
                    .map(skill => skill.name);
            }
        }
        return null;
    }
    
    get matchedSkills() {
        if (this.analysisResults && this.analysisResults.matchedSkills) {
            if (Array.isArray(this.analysisResults.matchedSkills)) {
                return this.analysisResults.matchedSkills;
            }
        }
        return null;
    }
    
    get missingSkills() {
        if (this.analysisResults && this.analysisResults.missingSkills) {
            if (Array.isArray(this.analysisResults.missingSkills)) {
                return this.analysisResults.missingSkills;
            }
        }
        return null;
    }
    
    get matchScore() {
        if (this.analysisResults && this.analysisResults.matchScore !== undefined) {
            // Upewnij się, że matchScore jest liczbą
            const score = parseFloat(this.analysisResults.matchScore);
            return isNaN(score) ? 0 : score;
        }
        return 0;
    }
    
    get matchScoreFormatted() {
        return `${Math.round(this.matchScore)}% Match`;
    }
    
    get matchScoreClass() {
        const score = this.matchScore;
        if (score >= 80) return 'match-score-high';
        if (score >= 60) return 'match-score-medium';
        return 'match-score-low';
    }
    
    get recommendations() {
        if (this.analysisResults && this.analysisResults.recommendations) {
            return this.analysisResults.recommendations;
        } else if (this.matchScore >= 80) {
            return 'This candidate has strong technical skills that match the job requirements. Recommend scheduling a technical interview.';
        } else if (this.matchScore >= 60) {
            return 'This candidate has some relevant skills but may need additional training. Consider a preliminary interview to assess potential.';
        } else {
            return 'This candidate does not match the key requirements for this position. Consider for other roles or reject application.';
        }
    }
    
    get showCandidateDetails() {
        return this.candidateName || this.candidateEmail || this.education;
    }
    
    get candidateName() {
        if (this.analysisResults) {
            if (this.analysisResults.candidateName) {
                return this.analysisResults.candidateName;
            } else if (this.analysisResults.personalInfo && this.analysisResults.personalInfo.name) {
                return this.analysisResults.personalInfo.name;
            }
        }
        return '';
    }
    
    get candidateEmail() {
        if (this.analysisResults) {
            if (this.analysisResults.candidateEmail) {
                return this.analysisResults.candidateEmail;
            } else if (this.analysisResults.personalInfo && this.analysisResults.personalInfo.email) {
                return this.analysisResults.personalInfo.email;
            }
        }
        return '';
    }
    
    get education() {
        if (this.analysisResults && this.analysisResults.education) {
            if (typeof this.analysisResults.education === 'string') {
                return this.analysisResults.education;
            } else if (Array.isArray(this.analysisResults.education)) {
                return this.analysisResults.education.join(', ');
            } else if (typeof this.analysisResults.education === 'object') {
                // Jeśli education to obiekt, próbujemy wyodrębnić najważniejsze informacje
                const edu = this.analysisResults.education;
                if (edu.degree && edu.institution) {
                    return `${edu.degree}, ${edu.institution}${edu.year ? ` (${edu.year})` : ''}`;
                }
            }
        }
        return '';
    }
    
    handleUpload(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.lastAnalyzedDocumentId = uploadedFiles[0].documentId;
            // Nie analizujemy automatycznie, czekamy na kliknięcie przycisku
            this.showToast('Success', 'File uploaded successfully. Click "Analyze CV" to proceed.', 'success');
        }
    }
    
    handleAnalyzeClick() {
        if (this.lastAnalyzedDocumentId) {
            this.isLoading = true;
            this.analyzeCV(this.lastAnalyzedDocumentId, false);
        } else {
            this.showToast('Error', 'Please upload a CV file first', 'error');
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
            this.showToast('Success', 'CV analysis completed successfully', 'success');
        })
        .catch(error => {
            this.error = error;
            this.analysisResults = undefined;
            this.isLoading = false;
            this.showResults = false;
            
            // Show error toast
            this.showToast('Error', 'An error occurred during CV analysis: ' + this.extractErrorMessage(error), 'error');
        });
    }
    
    handleForceAnalysis() {
        if (this.lastAnalyzedDocumentId) {
            this.isLoading = true;
            this.analyzeCV(this.lastAnalyzedDocumentId, true);
        } else {
            this.showToast('Error', 'No CV found for analysis', 'error');
        }
    }
    
    handleResetAnalysis() {
        this.analysisResults = undefined;
        this.error = undefined;
        this.showResults = false;
        this.lastAnalyzedDocumentId = null;
    }
    
    handleSaveResults() {
        if (!this.analysisResults) {
            this.showToast('Error', 'No analysis results to save', 'error');
            return;
        }
        
        this.isLoading = true;
        
        saveAnalysisResults({
            recordId: this.recordId,
            analysisResults: JSON.stringify(this.analysisResults)
        })
        .then(result => {
            this.isLoading = false;
            this.showToast('Success', 'Analysis results saved successfully', 'success');
            
            // Dispatch event to notify parent components
            this.dispatchEvent(new CustomEvent('analysissaved', {
                detail: {
                    success: true,
                    recordId: result
                }
            }));
        })
        .catch(error => {
            this.isLoading = false;
            this.showToast('Error', 'Failed to save analysis results: ' + this.extractErrorMessage(error), 'error');
        });
    }
    
    extractErrorMessage(error) {
        let message = 'Unknown error';
        if (typeof error === 'string') {
            message = error;
        } else if (error.body && error.body.message) {
            message = error.body.message;
        } else if (error.message) {
            message = error.message;
        }
        return message;
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