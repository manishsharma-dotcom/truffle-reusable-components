public class TF_EX_MindTouchCategoryTreeBatch 
    implements Database.Batchable<SObject>, Database.AllowsCallouts {

    private static final String BASE_URL = TF_EX_Mindtouchutils.base_URL;

    // ─── START ───────────────────────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Id__c, Title__c
            FROM KnowledgeCategoryMap__c
            WHERE Processed__c = false
        ]);
    }

    // ─── EXECUTE ─────────────────────────────────────────────────────────────
    public void execute(Database.BatchableContext bc, 
                        List<KnowledgeCategoryMap__c> scope) {

        List<KnowledgeCategoryMap__c> toInsert = new List<KnowledgeCategoryMap__c>();
        List<KnowledgeCategoryMap__c> toUpdate = new List<KnowledgeCategoryMap__c>();

        for (KnowledgeCategoryMap__c parent : scope) {

            List<Map<String, Object>> children = fetchSubpages(parent.Id__c);

            parent.Processed__c = true;
            toUpdate.add(parent);

            for (Map<String, Object> child : children) {
                KnowledgeCategoryMap__c childRecord = new KnowledgeCategoryMap__c(
                    Name             = TF_EX_MindTouchUtils.normalizeSpaces(String.valueOf(child.get('title')).left(80)),
                    Id__c            = String.valueOf(child.get('id')),
                    Title__c         = TF_EX_MindTouchUtils.normalizeSpaces(String.valueOf(child.get('title')).left(255)),
                    ArticleType__c   = String.valueOf(child.get('articleType')).left(255),
                    Parent__c        = parent.Id,
                    Processed__c     = false,
                    Public__c        = (Boolean) child.get('isPublic'),
                    MindTouchPath__c = String.valueOf(child.get('mindTouchPath')).left(500)  // ← NEW
                );
                toInsert.add(childRecord);
            }
        }

        if (!toInsert.isEmpty()) {
            upsert toInsert Id__c;
            System.debug('Inserted ' + toInsert.size() + ' child records');
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
            System.debug('Marked ' + toUpdate.size() + ' records as processed');
        }
    }

    // ─── FINISH ──────────────────────────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        Integer remaining = [
            SELECT COUNT() 
            FROM KnowledgeCategoryMap__c 
            WHERE Processed__c = false
        ];

        if (remaining > 0) {
            System.debug('Re-launching batch - ' + remaining + ' records still unprocessed');
            Database.executeBatch(new TF_EX_MindTouchCategoryTreeBatch(), 10);
        } else {
            System.debug('=== Tree mapping complete. No unprocessed records remain. ===');
            Integer total = [SELECT COUNT() FROM KnowledgeCategoryMap__c];
            System.debug('Total records mapped: ' + total);
        }
    }

    // ─── HELPER: Fetch subpages from MindTouch API ───────────────────────────
    private List<Map<String, Object>> fetchSubpages(String mindTouchPageId) {
    List<Map<String, Object>> result = new List<Map<String, Object>>();
    Integer offset     = 0;
    Integer pageLimit  = 100;
    Integer totalCount = null; // populated after first call

    do {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            BASE_URL + '/pages/' + mindTouchPageId
            + '/subpages?dream.out.format=json'
            + '&limit=' + pageLimit
            + '&offset=' + offset
        );
        req.setMethod('GET');
        req.setHeader('X-Deki-Token', TF_EX_MindTouchTokenHelper.buildToken());
        req.setHeader('Accept', 'application/json');
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            System.debug('Skipping page ' + mindTouchPageId
                + ' - API returned: ' + res.getStatusCode());
            break;
        }

        Map<String, Object> body =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        // @totalcount = total children on MindTouch side
        // @count      = how many returned in this call
        if (totalCount == null && body.containsKey('@totalcount')) {
            totalCount = Integer.valueOf(String.valueOf(body.get('@totalcount')));
            System.debug('Page ' + mindTouchPageId
                + ' total subpages: ' + totalCount);
        }

        Integer returnedCount = 0;
        Object pagesRaw = body.get('page.subpage');
        List<Object> rawList = new List<Object>();

        if (pagesRaw instanceof List<Object>) {
            rawList = (List<Object>) pagesRaw;
        } else if (pagesRaw instanceof Map<String, Object>) {
            rawList.add(pagesRaw);
        }

        returnedCount = rawList.size();

        for (Object p : rawList) {
            Map<String, Object> page = (Map<String, Object>) p;

            // ── Path ──────────────────────────────────────────────────────────
            Object pathRaw = page.get('path');
            String pathText = '';
            if (pathRaw instanceof Map<String, Object>) {
                pathText = String.valueOf(
                    ((Map<String, Object>) pathRaw).get('#text')
                );
            } else {
                pathText = String.valueOf(pathRaw);
            }

            // ── Public flag ───────────────────────────────────────────────────
            Boolean isPublic = false;
            try {
                Map<String, Object> security =
                    (Map<String, Object>) page.get('security');
                if (security != null) {
                    Map<String, Object> permPage =
                        (Map<String, Object>) security.get('permissions.page');
                    if (permPage != null) {
                        Map<String, Object> restriction =
                            (Map<String, Object>) permPage.get('restriction');
                        if (restriction != null) {
                            isPublic = (String.valueOf(
                                restriction.get('#text')) == 'Public');
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('Could not parse restriction for page '
                    + page.get('@id') + ': ' + e.getMessage());
            }

            result.add(new Map<String, Object>{
                'id'            => String.valueOf(page.get('@id')),
                'title'         => String.valueOf(page.get('title')),
                'articleType'   => String.valueOf(page.get('article')),
                'path'          => pathText,
                'isPublic'      => isPublic,
                'mindTouchPath' => pathText
            });
        }

        offset += returnedCount;

        // Stop if we got nothing back (safety — avoids infinite loop)
        if (returnedCount == 0) break;

    } while (totalCount != null && offset < totalCount);

    System.debug('Page ' + mindTouchPageId
        + ' fetched total subpages: ' + result.size());
    return result;
}
}