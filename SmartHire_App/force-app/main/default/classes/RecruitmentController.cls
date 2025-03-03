/**
 * Controller to expose recruitment services to Lightning components
 */
public with sharing class RecruitmentController {
    
    // Position related methods
    
    @AuraEnabled(cacheable=true)
    public static List<Position__c> getActivePositions() {
        try {
            return PositionService.getActivePositions();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Position__c getPositionById(Id positionId) {
        try {
            return PositionService.getPositionById(positionId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id createPosition(Position__c position) {
        try {
            return PositionService.createPosition(position);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void updatePosition(Position__c position) {
        try {
            PositionService.updatePosition(position);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getApplicationStatistics(Id positionId) {
        try {
            return PositionService.getApplicationStatistics(positionId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Candidate related methods
    
    @AuraEnabled(cacheable=true)
    public static List<Candidate__c> getAllCandidates() {
        try {
            return CandidateService.getAllCandidates();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Candidate__c> searchCandidates(String searchTerm) {
        try {
            return CandidateService.searchCandidates(searchTerm);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Candidate__c getCandidateById(Id candidateId) {
        try {
            return CandidateService.getCandidateById(candidateId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id createCandidate(Candidate__c candidate) {
        try {
            return CandidateService.createCandidate(candidate);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void updateCandidate(Candidate__c candidate) {
        try {
            CandidateService.updateCandidate(candidate);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Boolean isEmailExist(String email, Id candidateId) {
        try {
            return CandidateService.isEmailExist(email, candidateId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Job Application related methods
    
    @AuraEnabled(cacheable=true)
    public static Job_Application__c getApplicationById(Id applicationId) {
        try {
            return JobApplicationService.getApplicationById(applicationId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Job_Application__c> getApplicationsByPosition(Id positionId) {
        try {
            return JobApplicationService.getApplicationsByPosition(positionId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id createApplication(Job_Application__c application) {
        try {
            return JobApplicationService.createApplication(application);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void updateApplicationStatus(Id applicationId, String status, String notes) {
        try {
            JobApplicationService.updateApplicationStatus(applicationId, status, notes);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void assignReviewer(Id applicationId, Id reviewerId) {
        try {
            JobApplicationService.assignReviewer(applicationId, reviewerId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Candidate Conversion methods
    
    @AuraEnabled
    public static Id convertCandidateToContact(Id candidateId, Id accountId) {
        try {
            return CandidateConversionService.convertCandidateToContact(candidateId, accountId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id convertCandidateToUser(Id candidateId, Id profileId, Id roleId) {
        try {
            return CandidateConversionService.convertCandidateToUser(candidateId, profileId, roleId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Profile> getAvailableProfiles() {
        try {
            return CandidateConversionService.getAvailableProfiles();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<UserRole> getAvailableRoles() {
        try {
            return CandidateConversionService.getAvailableRoles();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }