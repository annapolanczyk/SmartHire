import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveAnalysisResults from '@salesforce/apex/CVAnalysisController.saveAnalysisResults';
import getLatestAnalysisForRecord from '@salesforce/apex/AiAnalysisController.getLatestAnalysisForRecord';

// Import fields from AiAnalysisResult__c
import MATCH_SCORE_FIELD from '@salesforce/schema/AiAnalysisResult__c.MatchScore__c';
import MATCHING_SKILLS_FIELD from '@salesforce/schema/AiAnalysisResult__c.MatchingSkills__c';
import MISSING_SKILLS_FIELD from '@salesforce/schema/AiAnalysisResult__c.MissingSkills__c';
import ADDITIONAL_SKILLS_FIELD from '@salesforce/schema/AiAnalysisResult__c.AdditionalSkills__c';
import ANALYSIS_SUMMARY_FIELD from '@salesforce/schema/AiAnalysisResult__c.AnalysisSummary__c';
import RECOMMENDATION_LEVEL_FIELD from '@salesforce/schema/AiAnalysisResult__c.RecommendationLevel__c';
import KEY_HIGHLIGHTS_FIELD from '@salesforce/schema/AiAnalysisResult__c.KeyHighlights__c';
import POTENTIAL_CONCERNS_FIELD from '@salesforce/schema/AiAnalysisResult__c.PotentialConcerns__c';
import RAW_ANALYSIS_RESULTS_FIELD from '@salesforce/schema/AiAnalysisResult__c.RawAnalysisResults__c';
import CANDIDATE_FIELD from '@salesforce/schema/AiAnalysisResult__c.Candidate__c';
import POSITION_FIELD from '@salesforce/schema/AiAnalysisResult__c.Position__c';
import JOB_APPLICATION_FIELD from '@salesforce/schema/AiAnalysisResult__c.Job_Application__c';
import CERTIFICATIONS_FIELD from '@salesforce/schema/AiAnalysisResult__c.Certifications__c';

export default class AiAnalysisViewer extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    @api showHeader = false;
    @api showRawResults = false;
    @api showCreateNewButton = false;
    
    @track analysisId;
    @track isLoading = true;
    @track error;
    @track showCreateForm = false;
    @track newAnalysisResults = {};
    
    // Opcje dla listy rozwijanej poziomu rekomendacji
    recommendationOptions = [
        { label: 'High', value: 'High' },
        { label: 'Medium', value: 'Medium' },
        { label: 'Low', value: 'Low' }
    ];
    
    // Computed properties for UI display
    get isAiAnalysisResult() {
        return this.objectApiName === 'AiAnalysisResult__c';
    }
    
    get isCandidateOrJobApplication() {
        return this.objectApiName === 'Candidate__c' || this.objectApiName === 'Job_Application__c';
    }
    
    get hasAnalysis() {
        return this.analysisId != null;
    }
    
    get hasError() {
        return this.error != null;
    }
    
    get isCandidate() {
        return this.objectApiName === 'Candidate__c';
    }
    
    get isJobApplication() {
        return this.objectApiName === 'Job_Application__c';
    }
    
    // Fields to retrieve from the AiAnalysisResult__c record
    fields = [
        MATCH_SCORE_FIELD,
        MATCHING_SKILLS_FIELD,
        MISSING_SKILLS_FIELD,
        ADDITIONAL_SKILLS_FIELD,
        ANALYSIS_SUMMARY_FIELD,
        RECOMMENDATION_LEVEL_FIELD,
        KEY_HIGHLIGHTS_FIELD,
        POTENTIAL_CONCERNS_FIELD,
        RAW_ANALYSIS_RESULTS_FIELD,
        CANDIDATE_FIELD,
        POSITION_FIELD,
        JOB_APPLICATION_FIELD,
        CERTIFICATIONS_FIELD
    ];
    
    // Wire the record data
    @wire(getRecord, { recordId: '$analysisId', fields: '$fields' })
    analysisRecord;
    
    // Computed properties for the analysis data
    get matchScore() {
        const score = this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, MATCH_SCORE_FIELD) : null;
        // Jeśli score jest null, zwracamy 0, w przeciwnym razie zwracamy wartość procentową (0-100)
        return score !== null ? parseFloat(score) : 0;
    }
    
    get matchScoreFormatted() {
        return this.matchScore ? Math.round(this.matchScore) + '%' : '0%';
    }
    
    get matchScoreClass() {
        if (!this.matchScore) return 'slds-theme_info';
        if (this.matchScore >= 75) return 'slds-theme_success';
        if (this.matchScore >= 50) return 'slds-theme_warning';
        return 'slds-theme_error';
    }
    
    get matchingSkills() {
        const skills = this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, MATCHING_SKILLS_FIELD) : null;
        console.log('Raw matchingSkills value:', skills);
        
        if (!skills) return [];
        
        // Przekształć ciąg znaków na tablicę i usuń białe znaki oraz kropki na końcu
        const skillsArray = skills.split(',')
            .map(skill => {
                // Usuń białe znaki z początku i końca, a następnie usuń kropkę jeśli występuje na końcu
                let trimmedSkill = skill.trim();
                return trimmedSkill.endsWith('.') ? trimmedSkill.substring(0, trimmedSkill.length - 1) : trimmedSkill;
            })
            .filter(skill => skill.length > 0); // Filtruj puste elementy
        
        console.log('Processed matchingSkills:', skillsArray);
        return skillsArray;
    }
    
    get missingSkills() {
        const skills = this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, MISSING_SKILLS_FIELD) : null;
        return skills ? skills.split(',').map(skill => skill.trim()) : [];
    }
    
    get additionalSkills() {
        const skills = this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, ADDITIONAL_SKILLS_FIELD) : null;
        return skills ? skills.split(',').map(skill => skill.trim()) : [];
    }
    
    get analysisSummary() {
        return this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, ANALYSIS_SUMMARY_FIELD) : null;
    }
    
    get recommendationLevel() {
        console.log('Getting recommendationLevel');
        if (this.analysisRecord && this.analysisRecord.data) {
            const recommendationValue = getFieldValue(this.analysisRecord.data, RECOMMENDATION_LEVEL_FIELD);
            console.log('Recommendation level value:', recommendationValue);
            return recommendationValue || 'None';
        }
        return 'None';
    }
    
    get recommendationScoreValue() {
        const level = this.recommendationLevel.toLowerCase();
        switch (level) {
            case 'high':
                return 90;
            case 'medium':
                return 60;
            case 'low':
                return 30;
            default:
                return 0;
        }
    }
    
    get recommendationProgressVariant() {
        const level = this.recommendationLevel.toLowerCase();
        switch (level) {
            case 'high':
                return 'success';
            case 'medium':
                return 'warning';
            case 'low':
                return 'error';
            default:
                return 'base';
        }
    }
    
    get recommendationLevelClass() {
        if (!this.recommendationLevel) return '';
        if (this.recommendationLevel === 'High') return 'slds-theme_success slds-box slds-p-around_x-small';
        if (this.recommendationLevel === 'Medium') return 'slds-theme_warning slds-box slds-p-around_x-small';
        if (this.recommendationLevel === 'Low') return 'slds-theme_error slds-box slds-p-around_x-small';
        return 'slds-box slds-p-around_x-small';
    }
    
    get keyHighlights() {
        const highlights = this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, KEY_HIGHLIGHTS_FIELD) : null;
        console.log('Raw keyHighlights value:', highlights);
        
        if (!highlights) return [];
        
        // Podziel na linie, usuń białe znaki oraz kropki na końcu każdego punktu
        const highlightsArray = highlights.split('\n')
            .map(highlight => {
                // Usuń białe znaki z początku i końca, a następnie usuń kropkę jeśli występuje na końcu
                let trimmedHighlight = highlight.trim();
                return trimmedHighlight.endsWith('.') ? trimmedHighlight.substring(0, trimmedHighlight.length - 1) : trimmedHighlight;
            })
            .filter(highlight => highlight.length > 0); // Filtruj puste elementy
        
        console.log('Processed keyHighlights:', highlightsArray);
        return highlightsArray;
    }
    
    get potentialConcerns() {
        const concerns = this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, POTENTIAL_CONCERNS_FIELD) : null;
        console.log('Raw potentialConcerns value:', concerns);
        
        if (!concerns) return [];
        
        // Podziel na linie, usuń białe znaki oraz kropki na końcu każdego punktu
        const concernsArray = concerns.split('\n')
            .map(concern => {
                // Usuń białe znaki z początku i końca, a następnie usuń kropkę jeśli występuje na końcu
                let trimmedConcern = concern.trim();
                return trimmedConcern.endsWith('.') ? trimmedConcern.substring(0, trimmedConcern.length - 1) : trimmedConcern;
            })
            .filter(concern => concern.length > 0); // Filtruj puste elementy
        
        console.log('Processed potentialConcerns:', concernsArray);
        return concernsArray;
    }
    
    get recommendations() {
        // Zamiast używać tego samego pola co dla analysisSummary, możemy utworzyć dostosowaną rekomendację
        // opartą na poziomie rekomendacji lub sformatować ją inaczej niż analysisSummary
        const level = this.recommendationLevel ? this.recommendationLevel.toLowerCase() : 'none';
        
        switch(level) {
            case 'high':
                return 'Kandydat jest silnym dopasowaniem do stanowiska. Zalecamy szybkie przeprowadzenie procesu rekrutacyjnego.';
            case 'medium':
                return 'Kandydat ma potencjał na tym stanowisku, ale może wymagać dodatkowego szkolenia. Zalecamy dalszą ocenę.';
            case 'low':
                return 'Kandydat nie spełnia kluczowych wymagań stanowiska. Zalecamy rozważenie innych kandydatów.';
            default:
                return 'Brak dostępnych rekomendacji dla tego kandydata.';
        }
    }
    
    get rawAnalysisResults() {
        return this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, RAW_ANALYSIS_RESULTS_FIELD) : null;
    }
    
    get candidateId() {
        return this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, CANDIDATE_FIELD) : null;
    }
    
    get positionId() {
        return this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, POSITION_FIELD) : null;
    }
    
    get jobApplicationId() {
        return this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, JOB_APPLICATION_FIELD) : null;
    }
    
    get certifications() {
        const certifications = this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, CERTIFICATIONS_FIELD) : null;
        console.log('Raw certifications value:', certifications);
        
        if (!certifications) return [];
        
        let certificationsArray = [];
        
        // Obsługa różnych formatów danych
        if (typeof certifications === 'string') {
            // Jeśli to ciąg znaków, rozdziel na linie
            // Sprawdzamy różne separatory: nowa linia, przecinek, średnik
            if (certifications.includes('\n')) {
                certificationsArray = certifications.split('\n');
            } else if (certifications.includes(',')) {
                certificationsArray = certifications.split(',');
            } else if (certifications.includes(';')) {
                certificationsArray = certifications.split(';');
            } else {
                // Jeśli nie ma separatorów, traktuj jako pojedynczy certyfikat
                certificationsArray = [certifications];
            }
        } else if (Array.isArray(certifications)) {
            // Jeśli to już tablica, użyj jej bezpośrednio
            certificationsArray = certifications.map(cert => typeof cert === 'string' ? cert : String(cert));
        }
        
        // Przetwórz każdy element: przytnij białe znaki, usuń kropki na końcu, usuń puste elementy
        const processedCerts = certificationsArray
            .map(cert => {
                if (typeof cert !== 'string') return String(cert).trim();
                
                // Usuń białe znaki z początku i końca
                let trimmedCert = cert.trim();
                
                // Usuń kropkę jeśli występuje na końcu
                while (trimmedCert.endsWith('.')) {
                    trimmedCert = trimmedCert.substring(0, trimmedCert.length - 1).trim();
                }
                
                return trimmedCert;
            })
            .filter(cert => cert.length > 0); // Filtruj puste elementy
        
        console.log('Processed certifications:', processedCerts);
        return processedCerts;
    }
    
    // Lifecycle hooks
    connectedCallback() {
        this.loadAnalysisData();
    }
    
    // Load the analysis data
    loadAnalysisData() {
        this.isLoading = true;
        this.error = null;
        
        if (this.isAiAnalysisResult) {
            // If we're on an AiAnalysisResult__c record page, use the current record ID
            this.analysisId = this.recordId;
            this.isLoading = false;
        } else if (this.isCandidateOrJobApplication) {
            // If we're on a Candidate__c or Job_Application__c record page, get the latest analysis
            this.getLatestAnalysis();
        } else {
            this.error = 'Unsupported object type: ' + this.objectApiName;
            this.isLoading = false;
        }
    }
    
    // Get the latest analysis for the current record
    getLatestAnalysis() {
        getLatestAnalysisForRecord({ recordId: this.recordId })
            .then(result => {
                if (result) {
                    this.analysisId = result;
                } else {
                    this.error = 'No analysis found for this record.';
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.error = 'Error loading analysis: ' + this.reduceErrors(error);
                this.isLoading = false;
            });
    }
    
    // Navigate to the record
    navigateToRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        console.log('Navigating to record:', recordId);
        console.log('analysisId value:', this.analysisId);
        console.log('Current target dataset:', event.currentTarget.dataset);
        
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    actionName: 'view'
                }
            });
        } else {
            console.error('No record ID found for navigation');
        }
    }
    
    // Handle creating a new analysis record
    handleCreateNewClick() {
        this.showCreateForm = true;
    }
    
    handleCancel() {
        this.showCreateForm = false;
        this.newAnalysisResults = {};
    }
    
    handleInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.newAnalysisResults[field] = value;
    }
    
    handleSkillsChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        // Split comma-separated skills into array
        if (value) {
            this.newAnalysisResults[field] = value.split(',').map(item => item.trim());
        } else {
            this.newAnalysisResults[field] = [];
        }
    }
    
    handleNumberChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        // Convert to number
        this.newAnalysisResults[field] = parseFloat(value);
    }
    
    handleSaveNewAnalysis() {
        if (!this.recordId) {
            this.showToast('Error', 'Missing record ID', 'error');
            return;
        }
        
        this.isLoading = true;
        
        // Prepare data for saving
        const resultsToSave = { ...this.newAnalysisResults };
        
        // Add context information
        resultsToSave.recordId = this.recordId;
        resultsToSave.objectApiName = this.objectApiName;
        
        // Make sure recommendationLevel is a string
        if (resultsToSave.recommendationLevel && typeof resultsToSave.recommendationLevel !== 'string') {
            resultsToSave.recommendationLevel = String(resultsToSave.recommendationLevel);
        }
        
        // Make sure skill fields are arrays
        ['matchedSkills', 'missingSkills', 'additionalSkills'].forEach(field => {
            if (resultsToSave[field] && !Array.isArray(resultsToSave[field])) {
                resultsToSave[field] = [resultsToSave[field]];
            }
        });
        
        // Save the analysis results
        saveAnalysisResults({
            recordId: this.recordId,
            analysisResults: JSON.stringify(resultsToSave)
        })
        .then(result => {
            this.isLoading = false;
            this.showCreateForm = false;
            this.newAnalysisResults = {};
            this.showToast('Success', 'Analysis results created successfully', 'success');
            
            // Update the view with the new analysis
            this.analysisId = result;
            
            // Refresh the component
            this.loadAnalysisData();
        })
        .catch(error => {
            this.isLoading = false;
            
            // Error handling
            let errorMessage = this.reduceErrors(error);
            console.error('Error saving analysis results:', error);
            console.error('Detailed error message:', errorMessage);
            
            this.showToast('Error', 'Failed to create analysis: ' + errorMessage, 'error');
        });
    }
    
    // Helper method to show toast notifications
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
    
    // Error reducer similar to cvAnalyzer
    reduceErrors(error) {
        if (typeof error === 'string') {
            return error;
        }
        
        if (error.body && error.body.message) {
            return error.body.message;
        }
        
        if (error.message) {
            return error.message;
        }
        
        return 'Unknown error';
    }
}