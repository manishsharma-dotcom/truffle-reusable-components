public class TF_EX_MindTouchUpdateInternalArtLinks implements Database.Batchable<SObject>, Database.Stateful {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT id ,KnowledgeContent__c FROM Knowledge__kav WHERE publishstatus = 'draft' AND Createdby.Name = 'Nipun Garg' order by ArticleNumber ASC
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Knowledge__kav> scope) {
        Map<String,Knowledge__kav> urlNameToArt = new Map<String,Knowledge__kav>();
        List<Knowledge__kav> articles = [SELECT id,urlName FROM Knowledge__kav WHERE publishStatus = 'Draft' AND Createdby.Name = 'Nipun Garg' AND IsVisibleInCsp = false AND IsVisibleInPkb = false AND IsVisibleInPrm = false];
        for(Knowledge__kav art : articles){
            urlNameToArt.put(art.urlName,art);
        }
        if (scope == null || scope.isEmpty()) return;

        List<Knowledge__kav> toUpdate = new List<Knowledge__kav>();

        for (Knowledge__kav record : scope) {
            String htmlContent = record.KnowledgeContent__c;
            htmlContent = rewriteArticleLinks(htmlContent,urlNameToArt);
            record.KnowledgeContent__c = htmlContent;
            toUpdate.add(record);
        }    
        if(toUpdate != null && !toUpdate.isEmpty()){
            update toUpdate;
        }
    }
    
    public void finish(Database.BatchableContext bc) {
    
    }
    
    public static String rewriteArticleLinks(String html,Map<String,Knowledge__kav> urlNameToArt) {
        MindTouch_Config__mdt config = [
            SELECT SiteURL__c,matchingPattern__c,internal_url__c
            FROM MindTouch_Config__mdt where SiteURL__c != NULL and matchingPattern__c != NULL
            LIMIT 1
        ];
        
        String matchingPattern = 'href="(https://patientpop--scully\\.sandbox\\.my\\.site\\.com/CustomerCommunity/s/article/[^"]*)"';
        Pattern p = Pattern.compile(matchingPattern);
        Matcher m = p.matcher(html);

        List<String> links = new List<String>();
        while (m.find()) {
            links.add(m.group(1));
        }

        System.debug('Links found to rewrite: ' + links.size());
        Integer count = 0;
        for (String link : links) {
            system.debug('link--->' + link);
            String lastPart = link.substringAfterLast('/');
            if(lastPart != null && lastPart != ''){
                if(urlNameToArt != null && !urlNameToArt.isEmpty() && urlNameToArt.containsKey(lastPart)){
                    String newLink = config.internal_url__c + '/lightning/r/Knowledge__kav/' + urlNameToArt.get(lastPart).id + '/view';
                    html = html.replace(link, newLink);
                }
            }
        }
            
        return html;
    } 
}