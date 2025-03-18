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
    
    get recommendationLevel() {
        if (this.analysisResults && this.analysisResults.recommendationLevel) {
            return this.analysisResults.recommendationLevel;
        } else if (this.matchScore >= 80) {
            return 'Highly Recommended';
        } else if (this.matchScore >= 60) {
            return 'Recommended';
        } else if (this.matchScore >= 40) {
            return 'Consider';
        } else {
            return 'Not Recommended';
        }
    }
    
    get recommendationLevelClass() {
        const level = this.recommendationLevel;
        if (!level) return 'slds-box slds-box_small';
        
        if (level === 'Highly Recommended') {
            return 'slds-box slds-box_small slds-theme_success';
        } else if (level === 'Recommended') {
            return 'slds-box slds-box_small slds-theme_info';
        } else if (level === 'Consider') {
            return 'slds-box slds-box_small slds-theme_warning';
        } else {
            return 'slds-box slds-box_small slds-theme_error';
        }
    }
    
    get analysisSummary() {
        if (this.analysisResults && this.analysisResults.analysisSummary) {
            return this.analysisResults.analysisSummary;
        }
        return '';
    }
    
    get keyHighlights() {
        if (this.analysisResults && this.analysisResults.keyHighlights) {
            if (Array.isArray(this.analysisResults.keyHighlights)) {
                return this.analysisResults.keyHighlights;
            } else if (typeof this.analysisResults.keyHighlights === 'string') {
                const highlights = this.analysisResults.keyHighlights;
                if (highlights.includes('\n')) {
                    return highlights.split('\n')
                        .map(item => item.replace(/^[\s-]*/, '').trim())
                        .filter(item => item.length > 0);
                } else if (highlights.includes(',')) {
                    return highlights.split(',')
                        .map(item => item.trim())
                        .filter(item => item.length > 0);
                } else {
                    return [highlights];
                }
            }
        }
        return null;
    }
    
    get potentialConcerns() {
        if (this.analysisResults && this.analysisResults.potentialConcerns) {
            if (Array.isArray(this.analysisResults.potentialConcerns)) {
                return this.analysisResults.potentialConcerns;
            } else if (typeof this.analysisResults.potentialConcerns === 'string') {
                const concerns = this.analysisResults.potentialConcerns;
                if (concerns.includes('\n')) {
                    return concerns.split('\n')
                        .map(item => item.replace(/^[\s-]*/, '').trim())
                        .filter(item => item.length > 0);
                } else if (concerns.includes(',')) {
                    return concerns.split(',')
                        .map(item => item.trim())
                        .filter(item => item.length > 0);
                } else {
                    return [concerns];
                }
            }
        }
        return null;
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
            // Dodajemy logowanie wyników
            console.log('Analysis Results:', JSON.stringify(result));
            
            // Sprawdzamy, czy mamy matchedSkills i missingSkills
            console.log('Has matchedSkills:', result.hasOwnProperty('matchedSkills'));
            console.log('matchedSkills type:', result.matchedSkills ? typeof result.matchedSkills : 'undefined');
            console.log('matchedSkills value:', result.matchedSkills);
            
            console.log('Has missingSkills:', result.hasOwnProperty('missingSkills'));
            console.log('missingSkills type:', result.missingSkills ? typeof result.missingSkills : 'undefined');
            console.log('missingSkills value:', result.missingSkills);
            
            console.log('Has skills:', result.hasOwnProperty('skills'));
            console.log('skills type:', result.skills ? typeof result.skills : 'undefined');
            console.log('skills value:', result.skills);
            
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
        
        // Przygotowanie danych do zapisu - tworzenie kopii obiektu z dostosowaniami
        const resultsToSave = JSON.parse(JSON.stringify(this.analysisResults));
        
        // Upewniamy się, że wszystkie wymagane pola są obecne
        if (resultsToSave.analysisSummary && !resultsToSave.summary) {
            resultsToSave.summary = resultsToSave.analysisSummary;
        }
        
        // Upewniamy się, że pola z umiejętnościami są tablicami
        if (resultsToSave.matchedSkills && !Array.isArray(resultsToSave.matchedSkills)) {
            resultsToSave.matchedSkills = [resultsToSave.matchedSkills];
        }
        
        if (resultsToSave.missingSkills && !Array.isArray(resultsToSave.missingSkills)) {
            resultsToSave.missingSkills = [resultsToSave.missingSkills];
        }
        
        if (resultsToSave.additionalSkills && !Array.isArray(resultsToSave.additionalSkills)) {
            resultsToSave.additionalSkills = [resultsToSave.additionalSkills];
        }
        
        // Upewniamy się, że poziom rekomendacji jest stringiem
        if (resultsToSave.recommendationLevel && typeof resultsToSave.recommendationLevel !== 'string') {
            resultsToSave.recommendationLevel = String(resultsToSave.recommendationLevel);
        }
        
        // Konwersja liczb do odpowiednich formatów
        if (resultsToSave.matchScore && typeof resultsToSave.matchScore === 'string') {
            resultsToSave.matchScore = parseFloat(resultsToSave.matchScore);
        }
        
        console.log('Data to save:', JSON.stringify(resultsToSave));
        
        saveAnalysisResults({
            recordId: this.recordId,
            analysisResults: JSON.stringify(resultsToSave)
        })
        .then(result => {
            this.isLoading = false;
            this.showToast('Success', 'Analysis results saved successfully', 'success');
            
            // Zachowujemy showResults = true, aby wyniki były nadal widoczne
            this.showResults = true;
            
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
            
            // Bardziej szczegółowa obsługa błędu
            let errorMessage = this.extractErrorMessage(error);
            console.error('Error saving analysis results:', error);
            console.error('Detailed error message:', errorMessage);
            
            // Dodatkowe informacje dla debugowania
            if (this.recordId) {
                console.log('RecordId:', this.recordId);
                console.log('Object API Name:', this.objectApiName);
            }
            
            this.showToast('Error', 'Failed to save analysis results: ' + errorMessage, 'error');
        });
    }
    
    extractErrorMessage(error) {
        let message = 'Unknown error';
        
        console.log('Error object:', JSON.stringify(error));
        
        if (typeof error === 'string') {
            message = error;
        } else if (error.body && error.body.message) {
            message = error.body.message;
            
            // Sprawdzamy, czy message zawiera zagnieżdżone informacje o błędzie
            if (message.includes('failed to save analysis results')) {
                const parts = message.split('failed to save analysis results:');
                if (parts.length > 1) {
                    message = parts[1].trim();
                }
            }
        } else if (error.message) {
            message = error.message;
        } else if (error.statusText) {
            message = error.statusText;
        } else if (error.detail) {
            message = error.detail;
        } else if (error.body && error.body.error) {
            message = error.body.error;
        } else if (error.body && error.body.stackTrace) {
            message = `Error with stack trace: ${error.body.stackTrace}`;
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