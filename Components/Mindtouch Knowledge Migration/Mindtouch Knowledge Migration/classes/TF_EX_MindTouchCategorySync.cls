public class TF_EX_MindTouchCategorySync {

    private static final String BASE_URL = TF_EX_MindtouchUtils.base_URL;
        
    // Main method - call this from Anonymous Apex
    public static void syncTopLevelCategories() {
        List<Map<String, Object>> pages = fetchSubpages('home', null);
        upsertCategoryRecords(pages, null);
    }

    // Fetch subpages for a given page ID or 'home'
    private static List<Map<String, Object>> fetchSubpages(
        String pageId,
        String parentMindTouchId
    ) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            BASE_URL + '/pages/' + pageId + '/subpages?dream.out.format=json'
        );
        req.setMethod('GET');
        req.setHeader('X-Deki-Token', TF_EX_MindTouchTokenHelper.buildToken());
        req.setHeader('Accept', 'application/json');
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            System.debug('ERROR fetching page ' + pageId + ': ' + res.getStatusCode());
            return new List<Map<String, Object>>();
        }

        Map<String, Object> body =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        Object pagesRaw = body.get('page.subpage');
        List<Object> rawList = new List<Object>();
        if (pagesRaw instanceof List<Object>) {
            rawList = (List<Object>) pagesRaw;
        } else if (pagesRaw instanceof Map<String, Object>) {
            rawList.add(pagesRaw);
        }

        List<Map<String, Object>> result = new List<Map<String, Object>>();

        for (Object p : rawList) {
            Map<String, Object> page = (Map<String, Object>) p;

            // ── Path ─────────────────────────────────────────────────────────
            Object pathRaw = page.get('path');
            String pathText = '';
            if (pathRaw instanceof Map<String, Object>) {
                pathText = String.valueOf(
                    ((Map<String, Object>) pathRaw).get('#text')
                );
            } else {
                pathText = String.valueOf(pathRaw);
            }

            // ── Public flag from security.permissions.page.restriction.#text ─
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
                'parentId'      => parentMindTouchId,
                'isPublic'      => isPublic,
                'mindTouchPath' => pathText  // ← NEW: same pathText, stored separately for clarity
            });
        }

        return result;
    }

    // Upsert KnowledgeCategoryMap__c records
    private static void upsertCategoryRecords(
        List<Map<String, Object>> pages,
        Id parentSalesforceId
    ) {
        List<KnowledgeCategoryMap__c> toUpsert = new List<KnowledgeCategoryMap__c>();

        for (Map<String, Object> page : pages) {
            KnowledgeCategoryMap__c record = new KnowledgeCategoryMap__c(
                Name             = TF_EX_MindTouchUtils.normalizeSpaces(String.valueOf(page.get('title')).left(80)),
                Id__c            = String.valueOf(page.get('id')),
                Title__c         = TF_EX_MindTouchUtils.normalizeSpaces(String.valueOf(page.get('title')).left(255)),
                ArticleType__c   = String.valueOf(page.get('articleType')).left(255),
                Parent__c        = parentSalesforceId,
                Public__c        = (Boolean) page.get('isPublic'),
                MindTouchPath__c = String.valueOf(page.get('mindTouchPath')).left(500)  // ← NEW
            );
            toUpsert.add(record);
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert Id__c;
            System.debug('Upserted ' + toUpsert.size() + ' category records');
            for (KnowledgeCategoryMap__c r : toUpsert) {
                System.debug('Saved: '    + r.Title__c
                    + ' | Id__c: '        + r.Id__c
                    + ' | Public: '       + r.Public__c
                    + ' | Path: '         + r.MindTouchPath__c);
            }
        }
    }
}