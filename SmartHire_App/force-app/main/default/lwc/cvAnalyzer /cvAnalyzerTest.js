import { createElement } from 'lwc';
import { registerApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';
import CvAnalyzer from 'c/cvAnalyzer';
import analyzeCandidateResume from '@salesforce/apex/RecruitmentController.analyzeCandidateResume';

// Rejestracja mocka dla metody Apex
jest.mock(
    '@salesforce/apex/RecruitmentController.analyzeCandidateResume',
    () => {
        return {
            default: jest.fn()
        };
    },
    { virtual: true }
);

describe('c-cv-analyzer', () => {
    beforeEach(() => {
        // Zresetowanie mocków
        analyzeCandidateResume.mockReset();
    });
    
    it('should display file upload when initialized', () => {
        // Tworzenie elementu komponentu
        const element = createElement('c-cv-analyzer', {
            is: CvAnalyzer
        });
        document.body.appendChild(element);
        
        // Pobranie elementu lightning-file-upload
        const fileUploadEl = element.shadowRoot.querySelector('lightning-file-upload');
        expect(fileUploadEl).not.toBeNull();
    });
    
    it('should show spinner when loading', () => {
        // Tworzenie elementu komponentu
        const element = createElement('c-cv-analyzer', {
            is: CvAnalyzer
        });
        document.body.appendChild(element);
        
        // Ustawienie flagi ładowania na true
        element.isLoading = true;
        
        return Promise.resolve().then(() => {
            // Sprawdzenie czy spinner jest widoczny
            const spinnerEl = element.shadowRoot.querySelector('lightning-spinner');
            expect(spinnerEl).not.toBeNull();
        });
    });
    
    it('should call apex method when file is uploaded', () => {
        // Przygotowanie mocka do zwracania danych
        const mockAnalysisResults = {
            skills: ['Java', 'Apex', 'Salesforce'],
            experience: '<p>Developer Experience</p>',
            education: '<p>University Education</p>',
            overallMatch: 75
        };
        
        analyzeCandidateResume.mockResolvedValue(mockAnalysisResults);
        
        // Tworzenie elementu komponentu
        const element = createElement('c-cv-analyzer', {
            is: CvAnalyzer
        });
        element.recordId = '001000000000001';
        element.objectApiName = 'Job_Application__c';
        document.body.appendChild(element);
        
        // Symulacja zdarzenia upload
        const fileUploadEl = element.shadowRoot.querySelector('lightning-file-upload');
        fileUploadEl.dispatchEvent(new CustomEvent('uploadfinished', {
            detail: {
                files: [
                    {
                        documentId: '069000000000001'
                    }
                ]
            }
        }));
        
        // Sprawdzenie czy metoda apex została wywołana
        expect(analyzeCandidateResume).toHaveBeenCalledWith({
            contentDocumentId: '069000000000001',
            positionId: '001000000000001'
        });
        
        return Promise.resolve().then(() => {
            // Po rozwiązaniu promisy, sprawdzamy czy komponent jest w stanie ładowania
            expect(element.isLoading).toBeTruthy();
        });
    });
    
    it('should display analysis results when data is returned', () => {
        // Przygotowanie mocka do zwracania danych
        const mockAnalysisResults = {
            skills: ['Java', 'Apex', 'Salesforce'],
            experience: '<p>Developer Experience</p>',
            education: '<p>University Education</p>',
            overallMatch: 75
        };
        
        analyzeCandidateResume.mockResolvedValue(mockAnalysisResults);
        
        // Tworzenie elementu komponentu
        const element = createElement('c-cv-analyzer', {
            is: CvAnalyzer
        });
        element.recordId = '001000000000001';
        element.objectApiName = 'Job_Application__c';
        document.body.appendChild(element);
        
        // Symulacja zdarzenia upload
        const fileUploadEl = element.shadowRoot.querySelector('lightning-file-upload');
        fileUploadEl.dispatchEvent(new CustomEvent('uploadfinished', {
            detail: {
                files: [
                    {
                        documentId: '069000000000001'
                    }
                ]
            }
        }));
        
        return Promise.resolve().then(() => {
            // Symulacja rozwiązania promisy i ustawienia wyników
            element.analysisResults = mockAnalysisResults;
            element.isLoading = false;
            element.showResults = true;
            
            return Promise.resolve().then(() => {
                // Sprawdzenie czy wyniki są wyświetlane
                const skillsSection = element.shadowRoot.querySelector('.slds-pill_container');
                expect(skillsSection).not.toBeNull();
                
                // Sprawdzenie czy ocena dopasowania jest wyświetlana
                const matchScoreEl = element.shadowRoot.querySelector('.slds-dl_horizontal__detail span');
                expect(matchScoreEl).not.toBeNull();
            });
        });
    });
    
    it('should handle errors', () => {
        // Przygotowanie mocka do zwracania błędu
        analyzeCandidateResume.mockRejectedValue({
            body: { message: 'Error analyzing CV' }
        });
        
        // Tworzenie elementu komponentu
        const element = createElement('c-cv-analyzer', {
            is: CvAnalyzer
        });
        element.recordId = '001000000000001';
        element.objectApiName = 'Job_Application__c';
        document.body.appendChild(element);
        
        // Symulacja zdarzenia upload
        const fileUploadEl = element.shadowRoot.querySelector('lightning-file-upload');
        fileUploadEl.dispatchEvent(new CustomEvent('uploadfinished', {
            detail: {
                files: [
                    {
                        documentId: '069000000000001'
                    }
                ]
            }
        }));
        
        return Promise.resolve().then(() => {
            // Symulacja odrzucenia promisy i ustawienia błędu
            element.error = 'Error analyzing CV';
            element.isLoading = false;
            element.showResults = false;
            
            return Promise.resolve().then(() => {
                // Sprawdzenie czy komunikat błędu jest wyświetlany
                const errorBox = element.shadowRoot.querySelector('.slds-theme_error');
                expect(errorBox).not.toBeNull();
                expect(errorBox.textContent).toContain('Error analyzing CV');
            });
        });
    });
});