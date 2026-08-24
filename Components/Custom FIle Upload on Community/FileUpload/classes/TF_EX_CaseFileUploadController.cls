/**
 * @class       TF_EX_CaseFileUploadController
 * @testClass   TF_EX_CaseFileUploadControllerTest
 * @createdBy   Truffle Consulting
 * @description Apex controller for the caseFileUpload LWC used in Experience Cloud.
 *              Handles file upload, deletion, and retrieval of ContentVersion records.
 *              Declared without sharing to allow file operations for community users
 *              regardless of record-level access.
 */
public with sharing class TF_EX_CaseFileUploadController {

    /**
     * @description Creates a ContentVersion from a base64-encoded file payload and returns
     *              the system-generated ContentDocumentId. Called by the LWC when a user
     *              selects a file to attach before submitting a new Case.
     * @param       fileName     Original file name (e.g. 'invoice.pdf').
     * @param       base64Data   Raw base64-encoded file content with no data-URL prefix.
     * @param       contentType  MIME type of the file (e.g. 'application/pdf').
     * @return      String — ContentDocumentId of the newly created ContentDocument.
     */
    @AuraEnabled
    public static String uploadFile(String fileName, String base64Data, String contentType) {
        if (String.isBlank(fileName) || String.isBlank(base64Data)) {
            throw new AuraHandledException('File name and content are required.');
        }
        ContentVersion cv = new ContentVersion();
        cv.Title          = fileName;
        cv.PathOnClient   = fileName;
        cv.VersionData    = EncodingUtil.base64Decode(base64Data);
        cv.IsMajorVersion = true;
        insert cv;

        ContentVersion inserted = [
            SELECT ContentDocumentId
            FROM   ContentVersion
            WHERE  Id = :cv.Id
            AND    ContentDocumentId != null
            LIMIT  1
        ];
        return inserted.ContentDocumentId;
    }

    /**
     * @description Deletes one or more ContentDocument records by Id.
     *              Called when the user removes an individual file from the upload list,
     *              or when the New Case modal is cancelled to clean up orphaned documents
     *              that were uploaded but never linked to a Case.
     * @param       contentDocumentIds  List of ContentDocumentIds to delete.
     */
    @AuraEnabled
    public static void deleteFiles(List<Id> contentDocumentIds) {
        if (contentDocumentIds == null || contentDocumentIds.isEmpty()) return;
        List<ContentDocument> toDelete = new List<ContentDocument>();
        for (Id cdId : contentDocumentIds) {
            toDelete.add(new ContentDocument(Id = cdId));
        }
        delete toDelete;
    }

    /**
     * @description Re-fetches ContentVersion details for a list of ContentDocumentIds.
     *              Called by the LWC on connectedCallback when the Screen Flow re-renders
     *              after a validation error, to restore the uploaded file list display.
     * @param       contentDocumentIds  List of ContentDocumentIds to look up.
     * @return      List<ContentVersion> — latest version records with Title and ContentSize.
     */
    @AuraEnabled
    public static List<ContentVersion> getFileDetails(List<Id> contentDocumentIds) {
        if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            return new List<ContentVersion>();
        }
        return [
            SELECT ContentDocumentId, Title, ContentSize
            FROM   ContentVersion
            WHERE  ContentDocumentId IN :contentDocumentIds
            AND    IsLatest = true
        ];
    }
}