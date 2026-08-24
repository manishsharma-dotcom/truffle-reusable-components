# MIAW Logged in User Script and Omni Flow Setup

**Owner:** Sandeep
**Type:** Metadata bundle (Omni-Channel / Messaging for In-App and Web configuration) + embedded JavaScript snippet — not a single Apex/LWC artifact, this is a guided multi-component deployment.

## Description
Quick-start setup for Messaging for In-App and Web (MIAW): an embedded site script captures
the logged-in Experience Site user's Id and passes it into the Omni-Channel routing flow,
which uses it to identify and update the corresponding messaging user's Contact Id.

## Features
- Full Omni-Channel/Messaging metadata bundle: `QueueRoutingConfig`, `Queue`, `ServiceChannel`, custom fields (`PreChat_Data__c`, `Source__c` on `MessagingSession`), a routing Flow, `MessagingChannel`, and `EmbeddedServiceConfig`.
- Prechat form collecting First Name, Last Name, and Email, plus a hidden field carrying the logged-in user's Id.
- Embedded JS snippet that reads the current Experience Site user's Id via `$A.get('$SObjectType.CurrentUser.Id')` and passes it to the Embedded Service prechat API as a hidden field when the chat button is clicked.
- Routing flow (`DemoOrg_Message_Routing`) that matches the conversation to a Contact using three inputs — `MessagingEndUser.ContactId`, the hidden user Id, and Email — and updates the messaging user record accordingly.
- Optional: restrict the channel to logged-in users only via the Messaging Channel's user-authentication setting.

## Known Issues
- **Hidden field name mismatch in the original guide:** the write-up text refers to the hidden prechat field as `userHiddenId`, but the JS snippet actually sets the key `userIdHidden` (`setHiddenPrechatFields({"userIdHidden": userId})`). Confirm which one matches your actual Embedded Service Config's configured hidden field API name before relying on this — as written, these two names don't match each other.
- **All metadata is named after a demo deployment ("DemoOrg")** — `ESW_DemoOrg_...` Site Name, `DemoOrg_Message_Routing` flow name, etc. These must be renamed to match your org's actual Embedded Service Deployment name, or the deployable metadata folder must be adjusted, before deploying to a non-demo org.
- **Deployment order is not optional if deploying piecemeal** — deploying out of the documented sequence produces dependency errors (see Installation below).
- The JS snippet relies on the Aura global `$A.get(...)`. The original guide doesn't specify which Experience Site template (Aura vs. LWR) this was validated against — verify it works on your site's actual template before assuming it's portable.
- This is a manual, guide-driven deployment (pre-steps → ordered metadata deploy → post-activation steps), not a single-command package install.

## Dependencies
- Omni-Channel enabled, with Presence Configurations and Presence Statuses configured (e.g. "Available for Messaging").
- Messaging enabled (Setup → Messaging Settings).
- Digital Experiences (Sites) enabled, with an existing site or one being built as part of the project. If embedding into a non-Salesforce website instead, enabling the setting alone is sufficient.
- An Embedded Service Deployment already created in the target org, with its generated Site Name available to plug into the metadata.
- Contact records that can be matched via `ContactId`/Email for the routing flow to resolve correctly.

## Installation
**Pre-deployment:**
1. Enable Omni-Channel; configure Presence Configurations and Presence Statuses.
2. Enable Messaging (Setup → Messaging Settings).
3. Enable Digital Experiences if not already (Setup → Digital Experiences → Settings).
4. Create a new Embedded Service Deployment (e.g. named `DemoOrg`, or adjust the metadata folder to match a different name).
5. Copy the generated Site Name (e.g. `ESW_DemoOrg_17458182031751`) and update the `embeddedServiceConfig` XML in the deployable folder with it.

**Deploy:**
1. Try deploying the full package first.
2. If dependency errors occur, deploy in this order instead:

| Step | Component | Details |
|---|---|---|
| 1 | `QueueRoutingConfig` | Defines how work gets assigned to queues |
| 2 | `Queue` | Queues that work routes into |
| 3 | `ServiceChannel` | The LiveMessage (Chat) channel |
| 4 | Custom Fields | `PreChat_Data__c` and `Source__c` on `MessagingSession` |
| 5 | Flow | `DemoOrg_Message_Routing` (routing logic) |
| 6 | `MessagingChannel` | Messaging Channel config |
| 7 | `EmbeddedServiceConfig` | Embedded Service settings |

**Post-deployment:**
1. Activate the newly deployed Messaging Channel (Setup → Messaging).
2. Publish the Embedded Service Deployment (Embedded Service Deployments → open it → Publish).
3. Activate the latest version of the `DemoOrg_Message_Routing` flow (Setup → Flows).
4. Add agent users to the new Queues and assign them Presence Statuses so they're available for Messaging.

## Usage
1. Add the following script to the Digital Experience site's header:
   ```html
   <script type='text/javascript'>
     var userId;

     function callPrechatAPI() {
         // get UserId of the logged in Experience Site User
         userId = $A.get('$SObjectType.CurrentUser.Id');
         console.log('Passing UserId = userId (currently Logged In User Id, or ' + userId + ')');
         embeddedservice_bootstrap.prechatAPI.setHiddenPrechatFields({
             "userIdHidden": userId
         });
     }

     function trapButtonClick() {
         console.log('Looking for embeddedMessagingConversationButton...');
         var b = document.getElementById('embeddedMessagingConversationButton');
         if (b != null) {
             console.log('Found it, attaching to onClick event');
             b.addEventListener('click', callPrechatAPI);
         } else {
             console.log('No button yet; wait a second and try again');
             setTimeout(trapButtonClick, 1000);
         }
     }

     window.addEventListener("onEmbeddedMessagingReady", () => {
         console.log('Received the onEmbeddedMessagingReady event...');
         callPrechatAPI();
     });
     window.addEventListener("load", trapButtonClick);
   </script>
   ```
   (See Known Issues above regarding the `userIdHidden` field name before deploying this as-is.)
2. The Prechat form collects First Name, Last Name, and Email alongside the hidden user Id field.
3. The Messaging Channel invokes the `DemoOrg_Message_Routing` flow, which uses `MessagingEndUser.ContactId`, the hidden user Id, and Email to locate and update the matching messaging user record. Adjust the flow/prechat parameters if your Contact-matching logic needs to differ.
4. To restrict the channel to logged-in users only, enable user authentication in the Messaging Channel settings.

## Confluence
_Not yet created — add the link here once the 1-pager exists, per the repo's contribution process._
