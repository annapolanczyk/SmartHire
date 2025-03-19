import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveAnalysisResults from '@salesforce/apex/CVAnalysisController.saveAnalysisResults';
import getLatestAnalysisForRecord from '@salesforce/apex/CVAnalysisController.getLatestAnalysisForRecord';

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
        { label: 'Highly Recommended', value: 'Highly Recommended' },
        { label: 'Recommended', value: 'Recommended' },
        { label: 'Consider', value: 'Consider' },
        { label: 'Not Recommended', value: 'Not Recommended' }
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
        JOB_APPLICATION_FIELD
    ];
    
    // Wire the record data
    @wire(getRecord, { recordId: '$analysisId', fields: '$fields' })
    analysisRecord;
    
    // Computed properties for the analysis data
    get matchScore() {
        return this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, MATCH_SCORE_FIELD) : null;
    }
    
    get matchScoreFormatted() {
        return this.matchScore ? Math.round(this.matchScore * 100) + '%' : '0%';
    }
    
    get matchScoreClass() {
        if (!this.matchScore) return 'slds-theme_info';
        if (this.matchScore >= 0.75) return 'slds-theme_success';
        if (this.matchScore >= 0.5) return 'slds-theme_warning';
        return 'slds-theme_error';
    }
    
    get matchingSkills() {
        const skills = this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, MATCHING_SKILLS_FIELD) : null;
        return skills ? skills.split(',').map(skill => skill.trim()) : [];
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
        return this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, RECOMMENDATION_LEVEL_FIELD) : null;
    }
    
    get recommendationLevelClass() {
        if (!this.recommendationLevel) return '';
        if (this.recommendationLevel === 'High') return 'slds-theme_success';
        if (this.recommendationLevel === 'Medium') return 'slds-theme_warning';
        if (this.recommendationLevel === 'Low') return 'slds-theme_error';
        return '';
    }
    
    get keyHighlights() {
        const highlights = this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, KEY_HIGHLIGHTS_FIELD) : null;
        return highlights ? highlights.split('\n').filter(h => h.trim() !== '') : [];
    }
    
    get potentialConcerns() {
        const concerns = this.analysisRecord.data ? getFieldValue(this.analysisRecord.data, POTENTIAL_CONCERNS_FIELD) : null;
        return concerns ? concerns.split('\n').filter(c => c.trim() !== '') : [];
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
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    actionName: 'view'
                }
            });
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