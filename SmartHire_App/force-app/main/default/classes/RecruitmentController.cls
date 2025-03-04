/**
 * Base controller class for recruitment functionality
 * This class is now deprecated - use domain-specific controllers instead
 */
public with sharing class RecruitmentController {
    
    /**
     * @deprecated Use PositionController.getActivePositions() instead
     */
    @AuraEnabled(cacheable=true)
    public static List<Position__c> getActivePositions() {
        try {
            return PositionService.getActivePositions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use PositionController.getPositionById() instead
     */
    @AuraEnabled(cacheable=true)
    public static Position__c getPositionById(Id positionId) {
        try {
            return PositionService.getPositionById(positionId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use PositionController.createPosition() instead
     */
    @AuraEnabled
    public static Id createPosition(Position__c position) {
        try {
            return PositionService.createPosition(position);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use PositionController.updatePosition() instead
     */
    @AuraEnabled
    public static void updatePosition(Position__c position) {
        try {
            PositionService.updatePosition(position);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use PositionController.getApplicationStatistics() instead
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getApplicationStatistics(Id positionId) {
        try {
            return PositionService.getApplicationStatistics(positionId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use CandidateController.getAllCandidates() instead
     */
    @AuraEnabled(cacheable=true)
    public static List<Candidate__c> getAllCandidates() {
        try {
            return CandidateService.getAllCandidates();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use CandidateController.searchCandidates() instead
     */
    @AuraEnabled(cacheable=true)
    public static List<Candidate__c> searchCandidates(String searchTerm) {
        try {
            return CandidateService.searchCandidates(searchTerm);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use CandidateController.getCandidateById() instead
     */
    @AuraEnabled(cacheable=true)
    public static Candidate__c getCandidateById(Id candidateId) {
        try {
            return CandidateService.getCandidateById(candidateId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use CandidateController.createCandidate() instead
     */
    @AuraEnabled
    public static Id createCandidate(Candidate__c candidate) {
        try {
            return CandidateService.createCandidate(candidate);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use CandidateController.updateCandidate() instead
     */
    @AuraEnabled
    public static void updateCandidate(Candidate__c candidate) {
        try {
            CandidateService.updateCandidate(candidate);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use CandidateController.isEmailExist() instead
     */
    @AuraEnabled
    public static Boolean isEmailExist(String email, Id candidateId) {
        try {
            return CandidateService.isEmailExist(email, candidateId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use ApplicationController.getApplicationById() instead
     */
    @AuraEnabled(cacheable=true)
    public static Job_Application__c getApplicationById(Id applicationId) {
        try {
            return JobApplicationService.getApplicationById(applicationId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use ApplicationController.getApplicationsByPosition() instead
     */
    @AuraEnabled(cacheable=true)
    public static List<Job_Application__c> getApplicationsByPosition(Id positionId) {
        try {
            return JobApplicationService.getApplicationsByPosition(positionId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use ApplicationController.createApplication() instead
     */
    @AuraEnabled
    public static Id createApplication(Job_Application__c application) {
        try {
            return JobApplicationService.createApplication(application);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use ApplicationController.updateApplicationStatus() instead
     */
    @AuraEnabled
    public static void updateApplicationStatus(Id applicationId, String status, String notes) {
        try {
            JobApplicationService.updateApplicationStatus(applicationId, status, notes);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use ApplicationController.assignReviewer() instead
     */
    @AuraEnabled
    public static void assignReviewer(Id applicationId, Id reviewerId) {
        try {
            JobApplicationService.assignReviewer(applicationId, reviewerId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use CandidateConversionController.convertCandidateToContact() instead
     */
    @AuraEnabled
    public static Id convertCandidateToContact(Id candidateId, Id accountId) {
        try {
            return CandidateConversionService.convertCandidateToContact(candidateId, accountId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use CandidateConversionController.convertCandidateToUser() instead
     */
    @AuraEnabled
    public static Id convertCandidateToUser(Id candidateId, Id profileId, Id roleId) {
        try {
            return CandidateConversionService.convertCandidateToUser(candidateId, profileId, roleId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use CandidateConversionController.getAvailableProfiles() instead
     */
    @AuraEnabled(cacheable=true)
    public static List<Profile> getAvailableProfiles() {
        try {
            return CandidateConversionService.getAvailableProfiles();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use CandidateConversionController.getAvailableRoles() instead
     */
    @AuraEnabled(cacheable=true)
    public static List<UserRole> getAvailableRoles() {
        try {
            return CandidateConversionService.getAvailableRoles();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @deprecated Use CVAnalysisController.analyzeCandidateResume() instead
     */
    @AuraEnabled
    public static Map<String, Object> analyzeCandidateResume(Id contentDocumentId, Id positionId, Boolean bypassCache) {
        try {
            return CVAnalysisService.analyzeCandidateResume(contentDocumentId, positionId, bypassCache != null ? bypassCache : false);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
    