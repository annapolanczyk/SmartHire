import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';

// Import Apex methods
import convertCandidateToContact from '@salesforce/apex/CandidateConversionController.convertCandidateToContact';
import convertCandidateToUser from '@salesforce/apex/CandidateConversionController.convertCandidateToUser';
import getAvailableProfiles from '@salesforce/apex/CandidateConversionController.getAvailableProfiles';
import getAvailableRoles from '@salesforce/apex/CandidateConversionController.getAvailableRoles';

// Import fields
import CANDIDATE_NAME_FIELD from '@salesforce/schema/Candidate__c.Name';
import CANDIDATE_EMAIL_FIELD from '@salesforce/schema/Candidate__c.Email__c';
import CANDIDATE_STATUS_FIELD from '@salesforce/schema/Candidate__c.Status__c';

const FIELDS = [CANDIDATE_NAME_FIELD, CANDIDATE_EMAIL_FIELD, CANDIDATE_STATUS_FIELD];

export default class CandidateConversion extends NavigationMixin(LightningElement) {
    @api recordId; // Candidate Id
    
    candidateData;
    error;
    
    // Conversion type options
    conversionType = 'contact';
    
    // Account lookup for contact conversion
    selectedAccountId;
    
    // User conversion options
    profiles = [];
    roles = [];
    selectedProfileId;
    selectedRoleId;
    
    isLoading = false;
    
    // Get candidate data
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredCandidate({ error, data }) {
        if (data) {
            this.candidateData = data;
            this.error = undefined;
            
            // Check if candidate is eligible for conversion (e.g., has status 'Active')
            const status = this.candidateData.fields.Status__c.value;
            if (status !== 'Active') {
                this.error = 'Only candidates with Active status can be converted.';
            }
        } else if (error) {
            this.candidateData = undefined;
            this.error = 'Error loading candidate: ' + error.body.message;
        }
    }
    
    // Get available profiles for user conversion
    @wire(getAvailableProfiles)
    wiredProfiles({ error, data }) {
        if (data) {
            this.profiles = data.map(profile => ({
                label: profile.Name,
                value: profile.Id
            }));
        } else if (error) {
            this.showToast('Error', 'Error loading profiles: ' + error.body.message, 'error');
        }
    }
    
    // Get available roles for user conversion
    @wire(getAvailableRoles)
    wiredRoles({ error, data }) {
        if (data) {
            this.roles = data.map(role => ({
                label: role.Name,
                value: role.Id
            }));
        } else if (error) {
            this.showToast('Error', 'Error loading roles: ' + error.body.message, 'error');
        }
    }
    
    // Handle conversion type change
    handleConversionTypeChange(event) {
        this.conversionType = event.target.value;
    }
    
    // Handle account selection
    handleAccountSelection(event) {
        this.selectedAccountId = event.detail.value[0];
    }
    
    // Handle profile selection
    handleProfileChange(event) {
        this.selectedProfileId = event.detail.value;
    }
    
    // Handle role selection
    handleRoleChange(event) {
        this.selectedRoleId = event.detail.value;
    }
    
    // Cancel button handler
    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }
    
    // Convert button handler
    handleConvert() {
        // Validate inputs
        if (this.conversionType === 'user' && (!this.selectedProfileId || !this.selectedRoleId)) {
            this.showToast('Error', 'Please select both a Profile and a Role for user conversion', 'error');
            return;
        }
        
        this.isLoading = true;
        
        // Call appropriate conversion method
        if (this.conversionType === 'contact') {
            this.convertToContact();
        } else {
            this.convertToUser();
        }
    }
    
    // Convert to contact
    convertToContact() {
        convertCandidateToContact({
            candidateId: this.recordId,
            accountId: this.selectedAccountId
        })
            .then(contactId => {
                this.isLoading = false;
                this.showToast('Success', 'Candidate has been converted to a Contact', 'success');
                
                // Navigate to the new contact
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: contactId,
                        objectApiName: 'Contact',
                        actionName: 'view'
                    }
                });
                
                this.dispatchEvent(new CustomEvent('close'));
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Error converting candidate: ' + error.body.message, 'error');
            });
    }
    
    // Convert to user
    convertToUser() {
        convertCandidateToUser({
            candidateId: this.recordId,
            profileId: this.selectedProfileId,
            roleId: this.selectedRoleId
        })
            .then(userId => {
                this.isLoading = false;
                this.showToast('Success', 'Candidate has been converted to a User', 'success');
                
                // Navigate to the new user
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: userId,
                        objectApiName: 'User',
                        actionName: 'view'
                    }
                });
                
                this.dispatchEvent(new CustomEvent('close'));
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Error converting candidate: ' + error.body.message, 'error');
            });
    }
}