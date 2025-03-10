declare module "@salesforce/apex/ApplicationController.getApplicationsByPosition" {
  export default function getApplicationsByPosition(param: {positionId: any}): Promise<any>;
}
declare module "@salesforce/apex/ApplicationController.getApplicationsByCandidate" {
  export default function getApplicationsByCandidate(param: {candidateId: any}): Promise<any>;
}
declare module "@salesforce/apex/ApplicationController.getApplicationById" {
  export default function getApplicationById(param: {applicationId: any}): Promise<any>;
}
declare module "@salesforce/apex/ApplicationController.createApplication" {
  export default function createApplication(param: {application: any}): Promise<any>;
}
declare module "@salesforce/apex/ApplicationController.updateApplicationStatus" {
  export default function updateApplicationStatus(param: {applicationId: any, status: any, comments: any}): Promise<any>;
}
declare module "@salesforce/apex/ApplicationController.getApplicationHistory" {
  export default function getApplicationHistory(param: {applicationId: any}): Promise<any>;
}
