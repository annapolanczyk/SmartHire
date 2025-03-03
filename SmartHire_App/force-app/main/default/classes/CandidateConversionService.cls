/**
 * Service class to handle conversion of Candidates to Contacts/Users
 */
public with sharing class CandidateConversionService {
    
    /**
     * Convert a hired candidate to a Contact
     * @param candidateId Candidate Id to convert
     * @param accountId Optional Account Id to associate with Contact
     * @return Id of created Contact
     */
    public static Id convertCandidateToContact(Id candidateId, Id accountId) {
        try {
            // Verify permissions
            if (!Schema.sObjectType.Contact.isCreateable()) {
                throw new AuraHandledException('You don\'t have permission to create contacts');
            }
            
            // Get candidate details
            Candidate__c candidate = [
                SELECT Id, Name, Email__c, Phone__c, LinkedIn_URL__c, Skills__c
                FROM Candidate__c
                WHERE Id = :candidateId
            ];
            
            // Split name for first/last name (simple logic - can be improved)
            List<String> nameParts = candidate.Name.split(' ', 2);
            String firstName = nameParts[0];
            String lastName = nameParts.size() > 1 ? nameParts[1] : '';
            
            // Create Contact record
            Contact newContact = new Contact(
                FirstName = firstName,
                LastName = lastName,
                Email = candidate.Email__c,
                Phone = candidate.Phone__c,
                Description = 'Skills: ' + candidate.Skills__c,
                AccountId = accountId
            );
            
            // Create custom field on Contact to store LinkedIn URL if needed
            // For now, store in description
            if (!String.isBlank(candidate.LinkedIn_URL__c)) {
                newContact.Description += '\nLinkedIn: ' + candidate.LinkedIn_URL__c;
            }
            
            // Add source information to track conversion
            newContact.Description += '\nConverted from Candidate: ' + candidate.Id;
            
            insert newContact;
            
            // Update candidate status to indicate conversion
            candidate.Status__c = 'Converted';
            update candidate;
            
            return newContact.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error converting candidate: ' + e.getMessage());
        }
    }
    
    /**
     * Convert a hired candidate directly to a User record (for internal hires)
     * @param candidateId Candidate Id to convert
     * @param profileId Profile Id for new user
     * @param roleId Role Id for new user
     * @return Id of created User
     */
    public static Id convertCandidateToUser(Id candidateId, Id profileId, Id roleId) {
        try {
            // Verify permissions
            if (!Schema.sObjectType.User.isCreateable()) {
                throw new AuraHandledException('You don\'t have permission to create users');
            }
            
            // First create Contact
            Id contactId = convertCandidateToContact(candidateId, null);
            
            // Get contact details
            Contact contact = [
                SELECT Id, FirstName, LastName, Email
                FROM Contact
                WHERE Id = :contactId
            ];
            
            // Create User record
            User newUser = new User(
                FirstName = contact.FirstName,
                LastName = contact.LastName,
                Email = contact.Email,
                Username = contact.Email + '.company', // Adjust as needed
                Alias = contact.FirstName.left(1) + contact.LastName.left(4),
                CommunityNickname = contact.FirstName + contact.LastName.left(3) + String.valueOf(Crypto.getRandomInteger()).substring(0, 3),
                ContactId = contactId,
                ProfileId = profileId,
                UserRoleId = roleId,
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                TimeZoneSidKey = 'America/New_York'
            );
            
            // Use a unique value for required fields
            // In a real implementation, you'd collect this information through the UI
            newUser.Username = contact.Email + '.' + System.currentTimeMillis() + '@yourdomain.com';
            
            insert newUser;
            return newUser.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error converting candidate to user: ' + e.getMessage());
        }
    }
    
    /**
     * Get available profiles for user creation
     * @return List of Profile options
     */
    public static List<Profile> getAvailableProfiles() {
        return [
            SELECT Id, Name 
            FROM Profile 
            WHERE UserType = 'Standard' 
            ORDER BY Name
        ];
    }
    
    /**
     * Get available user roles for user creation
     * @return List of UserRole options
     */
    public static List<UserRole> getAvailableRoles() {
        return [
            SELECT Id, Name 
            FROM UserRole 
            ORDER BY Name
        ];
    }
}