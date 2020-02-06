#!/bin/bash -i

banner (){
echo -e "
+-+-+-+-+-+-+-+-+-+-+
|k|e|n|t|s|l|a|v|e|s|
+-+-+-+-+-+-+-+-+-+-+
AUTHOR: KENT BAYRON @Kntx"
}

kill (){
        banner
    echo -e "RECONNAISSANCE TOOL FOR BUGBOUNTY"
    echo "USAGE:./recon.sh domain.com"
    exit 1
}

recon (){
banner
github_token=
mkdir ~/Research/Targets/$1
mkdir ~/Research/Targets/$1/Shodan
mkdir ~/Research/Targets/$1/GitHub
mkdir ~/Research/Targets/$1/Screenshots
mkdir ~/Research/Targets/$1/Wapiti
mkdir ~/Research/Targets/$1/NotScanned/
mkdir ~/Research/Targets/$1/Endpoints
mkdir ~/Research/Targets/$1/Endpoints/gobuster
mkdir ~/Research/Targets/$1/Archived
mkdir ~/Research/Targets/$1/SubdomainTakeover
mkdir ~/Research/Targets/$1/JSFiles
mkdir ~/Research/Targets/$1/Smuggle
echo $1 > ~/Research/Targets/$1/$1.root.txt
cat ~/Research/Targets/$1/$1.root.txt  | grep -Po "[\w\s]+(?=\.)" >> ~/Research/Targets/$1/$1.domain.txt
cd ~/Research/Targets/$1
echo -e "\e[31m[STARTING]\e[0m"

## LAUNCH AMASS
echo -e "\nRUNNING \e[31m[AMASS PASSIVE]\e[0m"
amass enum -config /root/config.ini -passive -d $1 -o ~/Research/Targets/$1/$1.amasspassive.txt 
echo "FOUND SUBDOMAINS [$(cat ~/Research/Targets/$1/$1.amasspassive.txt | wc -l)]"
echo "RUNNING AMASS \e[32mFINISH\e[0m"

## LAUNCH ASSETFINDER
echo -e "\nRUNNING \e[31m[ASSETFINDER]\e[0m"
assetfinder -subs-only $1 > ~/Research/Targets/$1/$1.assetfinder.txt
echo "FOUND SUBDOMAINS [$(cat ~/Research/Targets/$1/$1.assetfinder.txt | wc -l)]"
echo "RUNNING ASSETFINDER \e[32mFINISH\e[0m"

## LAUNCH FINDOMAIN
echo -e "\nRUNNING \e[31m[FINDOMAIN]\e[0m"
findomain -t $1 -o
echo "FOUND SUBDOMAINS [$(cat ~/Research/Targets/$1/$1.txt | wc -l)]"
echo "RUNNING FINDOMAIN \e[32mFINISH\e[0m"

## LAUNCH DNSBUFFER
echo -e "\nRUNNING \e[31m[DNSBUFFEROVER]\e[0m"
curl -s https://dns.bufferover.run/dns?q=.$1 | jq -r .FDNS_A[]|cut -d',' -f2 > ~/Research/Targets/$1/$1.dnsbuffer.txt
echo "FOUND SUBDOMAINS [$(cat ~/Research/Targets/$1/$1.dnsbuffer.txt | wc -l)]"
echo "RUNNING DNSBUFFER \e[32mFINISH\e[0m"

## LAUNCH SUBFINDER
echo -e "\nRUNNING \e[31m[SUBFINDER]\e[0m"
subfinder -d $1 -o ~/Research/Targets/$1/$1.subfinder.txt 
echo "FOUND SUBDOMAINS [$(cat ~/Research/Targets/$1/$1.subfinder.txt | wc -l)]"
echo "RUNNING SUBFINDER \e[32mFINISH\e[0m"

## REMOVING DUPLICATES
sort  ~/Research/Targets/$1/$1.amasspassive.txt ~/Research/Targets/$1/$1.subfinder.txt ~/Research/Targets/$1/$1.txt ~/Research/Targets/$1/$1.assetfinder.txt ~/Research/Targets/$1/$1.dnsbuffer.txt | uniq > ~/Research/Targets/$1/$1.alldomains.txt
echo "REMOVING DUPLICATES \e[32mFINISH\e[0m"

## LAUNCH DNSGEN & MASSDNS
echo -e "\nRUNNING \e[31m[MASSDNS & DNSGEN]\e[0m"
cat ~/Research/Targets/$1/$1.alldomains.txt | dnsgen - | ~/Research/Tools/Massdns/bin/massdns -r ~/Research/Tools/Massdns/lists/resolvers.txt -t A -o S -w ~/Research/Targets/$1/$1.massdns.txt
echo "RESOLVED SUBDOMAINS [$(cat ~/Research/Targets/$1/$1.massdns.txt | wc -l)]"
echo "RUNNING DNSGEN & MASSDNS \e[32mFINISH\e[0m"

## REMOVING DUPLICATES
sort ~/Research/Targets/$1/$1.massdns.txt | awk '{print $1}' | sed 's/\.$//' | uniq > ~/Research/Targets/$1/$1.resolved.txt
wildcheck -i ~/Research/Targets/$1/$1.resolved.txt -t 100 -p |grep "non-wildcard" |cut -d ' ' -f3 > ~/Research/Targets/$1/$1.resolved_no_wildcard.txt
mv ~/Research/Targets/$1/$1.resolved_no_wildcard.txt ~/Research/Targets/$1/$1.resolved.txt
sort ~/Research/Targets/$1/$1.resolved.txt ~/Research/Targets/$1/$1.alldomains.txt |  uniq > ~/Research/Targets/$1/$1.all-final.txt

## LAUNCH LIVEHOSTS
echo -e "\nRUNNING \e[31m[LIVEHOSTS]\e[0m"
cat ~/Research/Targets/$1/$1.all-final.txt | filter-resolved -c 100  >  ~/Research/Targets/$1/$1.all-resolved.txt 
cat ~/Research/Targets/$1/$1.all-final.txt | httprobe -c 100 >>  ~/Research/Targets/$1/$1.all-resolved.txt
cat ~/Research/Targets/$1/$1.all-resolved.txt | httprobe -c 100 >> ~/Research/Targets/$1/$1.livehost.txt
sort ~/Research/Targets/$1/$1.livehost.txt | uniq >> ~/Research/Targets/$1/$1.livehosts.txt
rm ~/Research/Targets/$1/$1.livehost.txt
cat ~/Research/Targets/$1/$1.livehosts.txt | sed 's/https\?:\/\///' > ~/Research/Targets/$1/$1.probed.txt
echo "LIVE HOSTS [$(cat ~/Research/Targets/$1/$1.livehosts.txt | wc -l)]"
echo "RUNNING LIVEHOSTS \e[32mFINISH\e[0m"

## LAUNCH HAKCRAWLER
echo -e "\nRUNNING \e[31m[HAKCRAWLER]\e[0m"
for hak in $(cat ~/Research/Targets/$1/$1.livehosts.txt); do
       hakrawler -url $hak -linkfinder >> ~/Research/Targets/$1/$1.Crawler.txt
done
echo "RUNNING HAKCRAWLER \e[32mFINISH\e[0m"

## RUNNING SHODAN
echo -e "\nRUNNING \e[31m[SHODAN HOST]\e[0m"
dig +short -f ~/Research/Targets/$1/$1.probed.txt > ~/Research/Targets/$1/ips.txt
cat ~/Research/Targets/$1/ips.txt | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' >> ~/Research/Targets/$1/ip.txt
sort ~/Research/Targets/$1/ip.txt | uniq > ~/Research/Targets/$1/$1.ip.txt

iprange="173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/12 172.64.0.0/13 131.0.72.0/22
199.83.128.0/21 198.143.32.0/19 149.126.72.0/21 103.28.248.0/22 45.64.64.0/22 185.11.124.0/22 192.230.64.0/18 107.154.0.0/16 45.60.0.0/16 45.223.0.0/16 185.93.228.0/24 185.93.229.0/24 185.93.230.0/24 185.93.231.0/24
192.124.249.0/24 192.161.0.0/24 192.88.134.0/24 192.88.135.0/24 193.19.224.0/24 193.19.225.0/24 66.248.200.0/24 66.248.201.0/24 66.248.202.0/24 66.248.203.0/24 104.101.221.0/24 184.51.125.0/24 184.51.154.0/24 184.51.157.0/24
184.51.33.0/24 2.16.36.0/24 2.16.37.0/24 2.22.226.0/24 2.22.227.0/24 2.22.60.0/24 23.15.12.0/24 23.15.13.0/24 23.209.105.0/24 23.62.225.0/24 23.74.29.0/24 23.79.224.0/24 23.79.225.0/24 23.79.226.0/24 23.79.227.0/24 23.79.229.0/24
23.79.230.0/24 23.79.231.0/24 23.79.232.0/24 23.79.233.0/24 23.79.235.0/24 23.79.237.0/24 23.79.238.0/24 23.79.239.0/24 63.208.195.0/24 72.246.0.0/24 72.246.1.0/24 72.246.116.0/24 72.246.199.0/24 72.246.2.0/24 72.247.150.0/24
72.247.151.0/24 72.247.216.0/24 72.247.44.0/24 72.247.45.0/24 80.67.64.0/24 80.67.65.0/24 80.67.70.0/24 80.67.73.0/24 88.221.208.0/24 88.221.209.0/24 96.6.114.0/24"
for ip in `cat ~/Research/Targets/$1/$1.ip.txt`; do
        grepcidr "$iprange" <(echo "$ip") >/dev/null && echo "[!] $ip is Known WAF" || echo "$ip" > ~/Research/Targets/$1/ip-clean.txt
 done
echo "[+] $(cat ~/Research/Targets/$1/ip-clean.txt| wc -l) non-waf IPs was collected out of old IPs!"
mv ~/Research/Targets/$1/ip-clean.txt ~/Research/Targets/$1/$1.ip.txt
rm ~/Research/Targets/$1/ips.txt ~/Research/Targets/$1/ip.txt

for ip in $(cat ~/Research/Targets/$1/$1.ip.txt); do shodan host $ip > ~/Research/Targets/$1/Shodan/$ip-shodan.txt; done 
echo "RUNNING SHODAN HOST \e[32mFINISH\e[0m "

## LAUNCH SUBJACK
echo -e "\nRUNNING \e[31m[SUBJACK]\e[0m"
subjack -w ~/Research/Targets/$1/$1.probed.txt -t 100 -a -timeout 30 -c ~/Research/Tools/Others/fingerprints.json -v -m -ssl -o ~/Research/Targets/$1/SubdomainTakeover/$1.result.txt 
echo "RUNNING SUBJACK \e[32mFINISH\e[0m "

## LAUNCH TKO-SUBS
echo -e "\nRUNNING \e[31m[TKO-SUBS]\e[0m"
tko-subs -domains=/root/Research/Targets/$1/$1.probed.txt -data=/root/Research/Tools/Others/providers-data.csv -output=/root/Research/Targets/$1/SubdomainTakeover/output.csv 
echo "RUNNING TKO-SUBS \e[32mFINISH\e[0m "

## LAUNCH WEB-ANALYZE
echo -e "\nRUNNING \e[31m[WEB-ANALYZE]\e[0m"
webanalyze -update
for a in $(cat ~/Research/Targets/$1/$1.livehosts.txt); do
	webanalyze -host $a >> ~/Research/Targets/$1/webanalyze.txt
done
rm apps.json
echo "RUNNING WEB-ANALYZE \e[32mFINISH\e[0m "

## RUNNING AQUATONE
echo -e "\nRUNNING \e[31m[AQUATONE ON SUBDOMAINS]\e[0m"
cat ~/Research/Targets/$1/$1.livehosts.txt | aquatone -threads 50 -out ~/Research/Targets/$1/Screenshots 
echo "RUNNING AQUATONE \e[32mFINISH\e[0m"

## RUNNING SMUGGLER
echo -e "\nRUNNING \e[31m[SMUGGLER]\e[0m"
python3 ~/Research/Tools/Smuggler/smuggler.py -v 1 -t 50 -u ~/Research/Targets/$1/$1.livehosts.txt >> ~/Research/Targets/$1/Smuggle/$1.Smuggled.txt 
echo "RUNNING SMUGGLER \e[32mFINISH\e[0m"

## RUNNING LINKFINDER
echo -e "\nRUNNING \e[31m[LINKFINDER]\e[0m"
sort ~/Research/Targets/$1/$1.livehosts.txt | sed 's/https\?:\/\///' | uniq >> ~/Research/Targets/$1/$1.livehosts-strip.txt
declare -a protocol=("http" "https")
for urlz in `cat ~/Research/Targets/$1/$1.livehosts-strip.txt`; do
        for protoc in ${protocol[@]}; do
                python3 ~/Research/Tools/LinkFinder/linkfinder.py -i $protoc://$urlz -d -o  ~/Research/Targets/$1/JSFiles/$protoc_$urlz-result.html 
        done
done
echo "RUNNING LINKFINDER \e[32mFINISH\e[0m"

##LOOKING FOR KNOWN SECRETS
strings -f -e s ~/Research/Targets/$1/JSFiles/*.html | grep -i 'BROWSER_STACK_ACCESS_KEY=\|BROWSER_STACK_USERNAME=\|browserConnectionEnabled=\|BROWSERSTACK_ACCESS_KEY=\|CHROME_CLIENT_SECRET=\|CHROME_EXTENSION_ID=\|CHROME_REFRESH_TOKEN=\|CI_DEPLOY_PASSWORD=\|CI_DEPLOY_USER=\|CLOUDAMQP_URL=\|CLOUDANT_APPLIANCE_DATABASE=\|CLOUDANT_ARCHIVED_DATABASE=\|CLOUDANT_AUDITED_DATABASE=\|CLOUDANT_ORDER_DATABASE=\|CLOUDANT_PARSED_DATABASE=\|CLOUDANT_PASSWORD=\|CLOUDANT_PROCESSED_DATABASE=\|CONTENTFUL_PHP_MANAGEMENT_TEST_TOKEN=\|CONTENTFUL_TEST_ORG_CMA_TOKEN=\|CONTENTFUL_V2_ACCESS_TOKEN=\|-DSELION_BROWSER_RUN_HEADLESS=\|-DSELION_DOWNLOAD_DEPENDENCIES=\|-DSELION_SELENIUM_RUN_LOCALLY=\|ELASTICSEARCH_PASSWORD=\|ELASTICSEARCH_USERNAME=\|EMAIL_NOTIFICATION=\|ENCRYPTION_PASSWORD=\|END_USER_PASSWORD=\|FBTOOLS_TARGET_PROJECT=\|FDfLgJkS3bKAdAU24AS5X8lmHUJB94=\|FEEDBACK_EMAIL_RECIPIENT=\|FEEDBACK_EMAIL_SENDER=\|FIREBASE_PROJECT_DEVELOP=\|FIREBASE_PROJECT_ID=\|FIREBASE_PROJECT=\|FIREBASE_SERVICE_ACCOUNT=\|FIREBASE_TOKEN=\|GH_NAME=\|GH_NEXT_OAUTH_CLIENT_ID=\|GH_NEXT_OAUTH_CLIENT_SECRET=\|GH_NEXT_UNSTABLE_OAUTH_CLIENT_ID=\|OKTA_OAUTH2_CLIENT_ID=\|OKTA_OAUTH2_CLIENT_SECRET=\|OKTA_OAUTH2_CLIENTID=\|OKTA_OAUTH2_CLIENTSECRET=\|SALESFORCE_BULK_TEST_PASSWORD=\|SALESFORCE_BULK_TEST_SECURITY_TOKEN=\|SALESFORCE_BULK_TEST_USERNAME=\|SALT=\|SELION_SELENIUM_PORT=\|SELION_SELENIUM_SAUCELAB_GRID_CONFIG_FILE=\|SELION_SELENIUM_USE_SAUCELAB_GRID=\|SENDGRID_API_KEY=\|SPACES_SECRET_ACCESS_KEY=\|SPOTIFY_API_ACCESS_TOKEN=\|SPOTIFY_API_CLIENT_ID=\|SPOTIFY_API_CLIENT_SECRET=\|VAULT_APPROLE_SECRET_ID=\|VAULT_PATH=\|VIP_GITHUB_BUILD_REPO_DEPLOY_KEY=\|VIP_GITHUB_DEPLOY_KEY_PASS=\|WAKATIME_PROJECT=\|WATSON_CLIENT=\|WATSON_CONVERSATION_PASSWORD=\|WATSON_CONVERSATION_USERNAME=\|NETLIFY_API_KEY=\|NETLIFY_SITE_ID=\|networkConnectionEnabled=\|NEW_RELIC_BETA_TOKEN=\|NEXUS_PASSWORD=\|POSTGRESQL_DB=\|POSTGRESQL_PASS=\|PREBUILD_AUTH=\|preferred_username=\|PRING.MAIL.USERNAME=\|SOMEVAR=\|SONA_TYPE_NEXUS_USERNAME=\|SONAR_ORGANIZATION_KEY=\|SONAR_PROJECT_KEY=\|SONAR_TOKEN=\|WIDGET_FB_USER_3=\|WIDGET_FB_USER=\|WIDGET_TEST_SERVER=\|WINCERT_PASSWORD=\|WORDPRESS_DB_PASSWORD=\|BROWSERSTACK_BUILD=\|CI_DEPLOY_USERNAME=\|CLOUDANT_DATABASE=\|CLOUDANT_SERVICE_DATABASE=\|CONTENTFUL_V2_ORGANIZATION=\|-DskipTests=\|-DSELION_SELENIUM_USE_GECKODRIVER=\|END_USER_USERNAME=\|FI1_RECEIVING_SEED=\|FIREFOX_CLIENT=\|GH_NEXT_UNSTABLE_OAUTH_CLIENT_SECRET=\|OKTA_OAUTH2_ISSUER=\|SANDBOX_ACCESS_TOKEN=\|SENDGRID_FROM_ADDRESS=\|SPRING.MAIL.PASSWORD=\|VIP_GITHUB_DEPLOY_KEY=\|WATSON_CONVERSATION_WORKSPACE=\|NEXUS_USERNAME=\|PRIVATE_SIGNING_PASSWORD=\|SONATYPE_GPG_KEY_NAME=\|WORDPRESS_DB_USER=\|ALGOLIA_ADMIN_KEY_1=\|ALGOLIA_ADMIN_KEY_2=\|ALGOLIA_ADMIN_KEY_MCM=\|ALGOLIA_API_KEY_MCM=\|ALGOLIA_API_KEY_SEARCH=\|ALGOLIA_APP_ID_MCM=\|ALGOLIA_APP_ID=\|ALGOLIA_APPLICATION_ID_1=\|ALGOLIA_APPLICATION_ID_2=\|ALGOLIA_APPLICATION_ID_MCM=\|ALICLOUD_SECRET_KEY=\|amazon_bucket_name=\|AMAZON_SECRET_ACCESS_KEY=\|AMQP://GUEST:GUEST@=\|ANACONDA_TOKEN=\|ANDROID_DOCS_DEPLOY_TOKEN=\|android_sdk_license=\|android_sdk_preview_license=\|ANSIBLE_VAULT_PASSWORD=\|aos_key=\|APPLICATION_ID=\|applicationCacheEnabled=\|ARGOS_TOKEN=\|ARTIFACTORY_KEY=\|ARTIFACTORY_USERNAME=\|ARTIFACTS_AWS_SECRET_ACCESS_KEY=\|ARTIFACTS_BUCKET=\|ARTIFACTS_KEY=\|ARTIFACTS_REGION=\|ARTIFACTS_SECRET=\|AUTHOR_EMAIL_ADDR=\|AUTHOR_NPM_API_KEY=\|AWS.config.accessKeyId=\|AWS.config.secretAccessKey=\|AWS_ACCESS_KEY_ID=\|BROWSERSTACK_PROJECT_NAME=\|BROWSERSTACK_USE_AUTOMATE=\|BROWSERSTACK_USERNAME=\|BUCKETEER_AWS_ACCESS_KEY_ID=\|BUILT_BRANCH_DEPLOY_KEY=\|BUNDLE_GEM__ZDSYS__COM=\|BUNDLE_GEMS__CONTRIBSYS__COM=\|BUNDLE_ZDREPO__JFROG__IO=\|CLOUDFLARE_API_KEY=\|CLOUDFLARE_AUTH_EMAIL=\|CLOUDFLARE_AUTH_KEY=\|CLOUDFLARE_CREVIERA_ZONE_ID=\|CLOUDFLARE_EMAIL=\|CLOUDFRONT_DISTRIBUTION_ID=\|CLOUDINARY_URL_EU=\|CLOUDINARY_URL_STAGING=\|CLOUDINARY_URL=\|CLU_REPO_URL=\|CONFIGURATION_PROFILE_SID_P2P=\|CONFIGURATION_PROFILE_SID_SFU=\|CONFIGURATION_PROFILE_SID=\|CONSUMER_KEY=\|CONSUMERKEY=\|CONTENTFUL_CMA_TEST_TOKEN=\|CONTENTFUL_INTEGRATION_MANAGEMENT_TOKEN=\|CONTENTFUL_INTEGRATION_SOURCE_SPACE=\|CONVERSATION_USERNAME=\|COREAPI_HOST=\|COS_SECRETS=\|COVERALLS_API_TOKEN=\|COVERALLS_REPO_TOKEN=\|DH_END_POINT_1=\|DH_END_POINT_2=\|DHL_SOLDTOACCOUNTID=\|DIGITALOCEAN_ACCESS_TOKEN=\|DIGITALOCEAN_SSH_KEY_BODY=\|ensureCleanSession=\|env.GITHUB_OAUTH_TOKEN=\|env.HEROKU_API_KEY=\|env.SONATYPE_PASSWORD=\|env.SONATYPE_USERNAME=\|ENV_SDFCAcctSDO_QuipAcctVineetPersonal=\|ENV_SECRET_ACCESS_KEY=\|ENV_SECRET=\|eureka.awsAccessId=\|eureka.awsSecretKey=\|GH_OAUTH_CLIENT_SECRET=\|GH_OAUTH_TOKEN=\|GH_REPO_TOKEN=\|GH_TOKEN=\|GH_UNSTABLE_OAUTH_CLIENT_ID=\|GITHUB_CLIENT_ID=\|GITHUB_CLIENT_SECRET=\|GITHUB_DEPLOY_HB_DOC_PASS=\|GITHUB_DEPLOYMENT_TOKEN=\|GITHUB_HUNTER_TOKEN=\|GITLAB_USER_LOGIN=\|GK_LOCK_DEFAULT_BRANCH=\|GOGS_PASSWORD=\|GOOGLE_ACCOUNT_TYPE=\|GOOGLE_CLIENT_EMAIL=\|GOOGLE_CLIENT_SECRET=\|GOOGLE_MAPS_API_KEY=\|GOOGLE_PRIVATE_KEY=\|GOOGLEAPIS.COM/=\|GOOGLEUSERCONTENT.COM=\|GRADLE_SIGNING_KEY_ID=\|GRADLE_SIGNING_PASSWORD=\|GREN_GITHUB_TOKEN=\|GRGIT_USER=\|groupToShareTravis=\|LEKTOR_DEPLOY_USERNAME=\|LICENSES_HASH_TWO=\|LICENSES_HASH=\|LIGHTHOUSE_API_KEY=\|LINKEDIN_CLIENT_ID=\|LOOKER_TEST_RUNNER_CLIENT_SECRET=\|LOOKER_TEST_RUNNER_ENDPOINT=\|LOTTIE_HAPPO_API_KEY=\|LOTTIE_HAPPO_SECRET_KEY=\|LOTTIE_UPLOAD_CERT_KEY_PASSWORD=\|LOTTIE_UPLOAD_CERT_KEY_STORE_PASSWORD=\|lr7mO294=\|MADRILL=\|MAGENTO_AUTH_PASSWORD=\|ManagementAPIAccessToken=\|MANDRILL_API_KEY=\|MANIFEST_APP_TOKEN=\|MANIFEST_APP_URL=\|MAPBOX_ACCESS_TOKEN=\|MAPBOX_AWS_ACCESS_KEY_ID=\|MAPBOX_AWS_SECRET_ACCESS_KEY=\|MapboxAccessToken=\|marionette=\|MAVEN_STAGING_PROFILE_ID=\|NETLIFY_API_KEY=\|NETLIFY_SITE_ID=\|networkConnectionEnabled=\|NEW_RELIC_BETA_TOKEN=\|NEXUS_PASSWORD=\|NODE_ENV=\|node_pre_gyp_accessKeyId=\|NODE_PRE_GYP_GITHUB_TOKEN=\|node_pre_gyp_secretAccessKey=\|NON_MULTI_ALICE_SID=\|NON_MULTI_CONNECT_SID=\|NON_MULTI_DISCONNECT_SID=\|NON_MULTI_WORKFLOW_SID=\|NON_MULTI_WORKSPACE_SID=\|NON_TOKEN=\|NUNIT=\|OAUTH_TOKEN=\|OBJECT_STORAGE_INCOMING_CONTAINER_NAME=\|OBJECT_STORAGE_PASSWORD=\|OBJECT_STORAGE_PROJECT_ID=\|OBJECT_STORAGE_USER_ID=\|OBJECT_STORE_BUCKET=\|OBJECT_STORE_CREDS=\|OC_PASS=\|OCTEST_APP_PASSWORD=\|OFTA_SECRET=\|OKTA_AUTHN_ITS_MFAENROLLGROUPID=\|OKTA_CLIENT_ORG_URL=\|OKTA_CLIENT_ORGURL=\|OKTA_CLIENT_TOKEN=\|OPENWHISK_KEY=\|org.gradle.daemon=\|ORG_GRADLE_PROJECT_cloudinaryUrl=\|ORG_ID=\|ORG_PROJECT_GRADLE_SONATYPE_NEXUS_PASSWORD=\|ORG_PROJECT_GRADLE_SONATYPE_NEXUS_USERNAME=\|--org=\|OSSRH_USERNAME=\|PACKAGECLOUD_TOKEN=\|PAGERDUTY_APIKEY=\|PAGERDUTY_ESCALATION_POLICY_ID=\|PAGERDUTY_FROM_USER=\|--port=\|POSTGRES_ENV_POSTGRES_DB=\|POSTGRES_ENV_POSTGRES_PASSWORD=\|POSTGRES_ENV_POSTGRES_USER=\|POSTGRESQL_DB=\|POSTGRESQL_PASS=\|PREBUILD_AUTH=\|preferred_username=\|PRING.MAIL.USERNAME=\|S3.AMAZONAWS.COM=\|S3_ACCESS_KEY_ID=\|s3_access_key=\|S3_BUCKET_NAME_APP_LOGS=\|S3_BUCKET_NAME_ASSETS=\|S3_USER_ID=\|S3_USER_SECRET=\|S3-EXTERNAL-3.AMAZONAWS.COM=\|SACLOUD_ACCESS_TOKEN_SECRET=\|SACLOUD_ACCESS_TOKEN=\|SENTRY_DEFAULT_ORG=\|SENTRY_ENDPOINT=\|SERVERAPI_SERVER_ADDR=\|SERVICE_ACCOUNT_SECRET=\|SES_ACCESS_KEY=\|SLASH_DEVELOPER_SPACE_KEY=\|SLASH_DEVELOPER_SPACE=\|SLATE_USER_EMAIL=\|SNOOWRAP_CLIENT_ID=\|SNOOWRAP_CLIENT_SECRET=\|SNOOWRAP_REDIRECT_URI=\|SNOOWRAP_REFRESH_TOKEN=\|SNOOWRAP_USER_AGENT=\|SNOOWRAP_USERNAME=\|SNYK_API_TOKEN=\|SOMEVAR=\|SONA_TYPE_NEXUS_USERNAME=\|SONAR_ORGANIZATION_KEY=\|SONAR_PROJECT_KEY=\|SONAR_TOKEN=\|SONATYPE_GPG_PASSPHRASE=\|SONATYPE_NEXUS_PASSWORD=\|SONATYPE_NEXUS_USERNAME=\|SONATYPE_PASS=\|SONATYPE_PASSWORD=\|SSMTP_CONFIG=\|STAGING_BASE_URL_RUNSCOPE=\|STAR_TEST_AWS_ACCESS_KEY_ID=\|STAR_TEST_BUCKET=\|STAR_TEST_LOCATION=\|STARSHIP_ACCOUNT_SID=\|STARSHIP_AUTH_TOKEN=\|STORMPATH_API_KEY_ID=\|STORMPATH_API_KEY_SECRET=\|STRIP_PUBLISHABLE_KEY=\|TRAVIS_TOKEN=\|TREX_CLIENT_ORGURL=\|TREX_CLIENT_TOKEN=\|TREX_OKTA_CLIENT_ORGURL=\|TREX_OKTA_CLIENT_TOKEN=\|TWITTER_CONSUMER_KEY=\|TWITTER_CONSUMER_SECRET=\|TWITTER=\|TWITTEROAUTHACCESSSECRET=\|TWITTEROAUTHACCESSTOKEN=\|VIRUSTOTAL_APIKEY=\|VISUAL_RECOGNITION_API_KEY=\|VSCETOKEN=\|VU8GYF3BglCxGAxrMW9OFpuHCkQ=\|vzG6Puz8=\|WEB_CLIENT_ID=\|webdavBaseUrlTravis=\|WEBHOOK_URL=\|webStorageEnabled=\|WIDGET_BASIC_PASSWORD_2=\|WIDGET_BASIC_PASSWORD_4=\|WIDGET_BASIC_PASSWORD_5=\|WIDGET_BASIC_PASSWORD=\|WIDGET_BASIC_USER_2=\|WIDGET_BASIC_USER_3=\|WIDGET_BASIC_USER_5=\|WIDGET_BASIC_USER=\|WIDGET_FB_PASSWORD_2=\|WIDGET_FB_PASSWORD_3=\|WIDGET_FB_PASSWORD=\|WIDGET_FB_USER_3=\|WIDGET_FB_USER=\|WIDGET_TEST_SERVER=\|WINCERT_PASSWORD=\|WORDPRESS_DB_PASSWORD=\|YT_ACCOUNT_REFRESH_TOKEN=\|YT_API_KEY=\|YT_CLIENT_ID=\|YT_CLIENT_SECRET=\|YT_PARTNER_CHANNEL_ID=\|YT_PARTNER_CLIENT_SECRET=\|YT_PARTNER_ID=\|YT_PARTNER_REFRESH_TOKEN=\|YT_SERVER_API_KEY=\|YVxUZIA4Cm9984AxbYJGSk=\|ALGOLIA_API_KEY=\|ALGOLIA_APPLICATION_ID=\|ANALYTICS=\|aos_sec=\|ARTIFACTS_AWS_ACCESS_KEY_ID=\|ASSISTANT_IAM_APIKEY=\|AWS_ACCESS_KEY=\|BROWSERSTACK_PARALLEL_RUNS=\|BUCKETEER_BUCKET_NAME=\|BUCKETEER_AWS_SECRET_ACCESS_KEY=\|BUNDLESIZE_GITHUB_TOKEN=\|BX_PASSWORD=\|CLOUDANT_INSTANCE=\|CLOUDANT_USERNAME=\|CLOUDFLARE_ZONE_ID=\|CLU_SSH_PRIVATE_KEY_BASE64=\|CONTENTFUL_ACCESS_TOKEN=\|CONTENTFUL_ORGANIZATION=\|CONTENTFUL_MANAGEMENT_API_ACCESS_TOKEN=\|CONVERSATION_URL=\|COVERALLS_SERVICE_NAME=\|CONVERSATION_PASSWORD=\|CONTENTFUL_MANAGEMENT_API_ACCESS_TOKEN_NEW=\|DIGITALOCEAN_SSH_KEY_IDS=\|-Dsonar.login=\|ENV_KEY=\|ExcludeRestorePackageImports=\|FI1_SIGNING_SEED=\|GH_OAUTH_CLIENT_ID=\|GH_UNSTABLE_OAUTH_CLIENT_SECRET=\|GITHUB_HUNTER_USERNAME=\|GOOGLE_CLIENT_ID=\|gpg.passphrase=\|HAB_AUTH_TOKEN=\|LINKEDIN_CLIENT_SECRET=OR LOTTIE_S3_API_KEY=\|LOTTIE_S3_SECRET_KEY=\|MAGENTO_AUTH_USERNAME= \|MAPBOX_API_TOKEN=\|MG_API_KEY=\|NEXUS_USERNAME=\|NON_MULTI_BOB_SID=\|NOW_TOKEN=\|OBJECT_STORAGE_REGION_NAME=\|OCTEST_APP_USERNAME=\|OKTA_DOMAIN=\|OMISE_KEY=\|ORG_GRADLE_PROJECT_SONATYPE_NEXUS_PASSWORD=\|ORG_GRADLE_PROJECT_SONATYPE_NEXUS_USERNAME=\|OS_AUTH_URL=\|PAGERDUTY_PRIORITY_ID=\|POSTGRES_PORT=\|PRIVATE_SIGNING_PASSWORD=\|S3_KEY_APP_LOGS=\|SACLOUD_API=\|SANDBOX_AWS_ACCESS_KEY_ID=\|SENDGRID_KEY=\|SES_SECRET_KEY=\|SNOOWRAP_PASSWORD=\|SNYK_ORG_ID=\|SONATYPE_GPG_KEY_NAME=\|SONATYPE_TOKEN_PASSWORD=\|SQS_NOTIFICATIONS_INTERNAL=\|STAR_TEST_SECRET_ACCESS_KEY=\|STRIP_SECRET_KEY=\|TRIGGER_API_COVERAGE_REPORTER=\|uiElement=\|VIP_TEST=\|WAKATIME_API_KEY=\|WATSON_DEVICE_PASSWORD=\|WIDGET_BASIC_PASSWORD_3=\|WIDGET_BASIC_USER_4=\|WIDGET_FB_USER_2=\|WORDPRESS_DB_USER=\|YT_PARTNER_CLIENT_ID=\|zendesk-travis-github=\|access_token=\|AccessKeyId=\|account=\|access_token=\|\?AccessKeyId=\|\?account=\|\0GITHUB_TOKEN=\|0HB_CODESIGN_GPG_PASS=\|0HB_CODESIGN_KEY_PASS=\|0KNAME=\|0PUSHOVER_TOKEN=\|0PUSHOVER_USER=\|0VIRUSTOTAL_APIKEY=\|acceptInsecureCerts=\|acceptSslCerts=\|ACCESS_KEY_ID=\|ACCESS_KEY_SECRET=\|ACCESS_KEY=\|ACCESS_SECRET=\|ACCESS_TOKEN=\|accessibilityChecks=\|ACCESSKEY=\|ACCESSKEYID=\|ACCOUNT_SID=\|ADMIN_EMAIL=\|ADZERK_API_KEY=\|AGFA=\|ALARM_CRON=\|ALGOLIA_SEARCH_API_KEY=\|ALGOLIA_SEARCH_KEY_1=\|ALGOLIA_SEARCH_KEY=\|ALIAS_NAME=\|ALIAS_PASS=\|ALICLOUD_ACCESS_KEY=\|API_KEY_MCM=\|API_KEY_SECRET=\|API_KEY_SID=\|API_KEY=\|API_SECRET=\|APIARY_API_KEY=\|APIGW_ACCESS_TOKEN=\|APP_BUCKET_PERM=\|APP_ID=\|APP_NAME=\|APP_REPORT_TOKEN_KEY=\|APP_SECRETE=\|APP_SETTINGS=\|APP_TOKEN=\|appClientSecret=\|APPLE_ID_PASSWORD=\|APPLE_ID_USERNAME=\|APPLICATION_ID_MCM=\|ATOKEN=\|AURORA_STRING_URL=\|AUTH_TOKEN=\|AUTH0_API_CLIENTID=\|AUTH0_API_CLIENTSECRET=\|AUTH0_AUDIENCE=\|AUTH0_CALLBACK_URL=\|AUTH0_CLIENT_ID=\|AUTH0_CLIENT_SECRET=\|AUTH0_CONNECTION=\|AUTH0_DOMAIN=\|AWS_ACCESS=\|AWS_CF_DIST_ID=\|AWS_DEFAULT_REGION=\|AWS_REGION=\|AWS_S3_BUCKET=\|AWS_SECRET_ACCESS_KEY=\|AWS_SECRET_KEY=\|AWS_SECRET=\|AWS_SES_ACCESS_KEY_ID=\|AWS_SES_SECRET_ACCESS_KEY=\|AWSACCESSKEYID=\|AWS-ACCT-ID=\|AWSCN_ACCESS_KEY_ID=\|AWSCN_SECRET_ACCESS_KEY=\|AWS-KEY=\|AWSSECRETKEY=\|AWS-SECRETS=\|aX5xTOsQFzwacdLtlNkKJ3K64=\|B2_ACCT_ID=\|B2_APP_KEY=\|B2_BUCKET=\|baseUrlTravis=\|BINTRAY_API_KEY=\|BINTRAY_APIKEY=\|BINTRAY_GPG_PASSWORD=\|BINTRAY_KEY=\|BINTRAY_TOKEN=\|BINTRAY_USER=\|bintrayKey=\|bintrayUser=\|BLhLRKwsTLnPm8=\|BLUEMIX_ACCOUNT=\|BLUEMIX_API_KEY=\|BLUEMIX_AUTH=\|BLUEMIX_NAMESPACE=\|BLUEMIX_ORG=\|BLUEMIX_ORGANIZATION=\|BLUEMIX_PASS_PROD=\|BLUEMIX_PASS=\|BLUEMIX_PASSWORD=\|BLUEMIX_PWD=\|BLUEMIX_REGION=\|BLUEMIX_SPACE=\|BLUEMIX_USER=\|BLUEMIX_USERNAME=\|BRACKETS_REPO_OAUTH_TOKEN=\|branch=\|--branch=\|BX_USERNAME=\|BXIAM=\|BzwUsjfvIM=\|c6cBVFdks=\|cacdc=\|CACHE_S3_SECRET_KEY=\|CACHE_URL=\|CARGO_TOKEN=\|casc=\|CASPERJS_TIMEOUT=\|CATTLE_ACCESS_KEY=\|CATTLE_AGENT_INSTANCE_AUTH=\|CATTLE_SECRET_KEY=\|CC_TEST_REPORTER_ID=\|CC_TEST_REPOTER_ID=\|cdascsa=\|cdscasc=\|CENSYS_SECRET=\|CENSYS_UID=\|CERTIFICATE_OSX_P12=\|CERTIFICATE_PASSWORD=\|CF_ORGANIZATION=\|CF_PASSWORD=\|CF_PROXY_HOST=\|CF_SPACE=\|CF_USERNAME=\|channelId=\|CHEVERNY_TOKEN=\|CHROME_CLIENT_ID=\|CI_NAME=\|CI_PROJECT_NAMESPACE=\|CI_PROJECT_URL=\|CI_REGISTRY_USER=\|CI_SERVER_NAME=\|CI_USER_TOKEN=\|CLAIMR_DATABASE=\|CLAIMR_DB=\|CLAIMR_SUPERUSER=\|CLAIMR_TOKEN=\|CLI_E2E_CMA_TOKEN=\|CLI_E2E_ORG_ID=\|CLIENT_SECRET=\|clojars_password=\|clojars_username=\|--closure_entry_point=\|CLOUD_API_KEY=\|CLUSTER_NAME=\|CLUSTER=\|CN_ACCESS_KEY_ID=\|CN_SECRET_ACCESS_KEY=\|COCOAPODS_TRUNK_EMAIL=\|COCOAPODS_TRUNK_TOKEN=\|CODACY_PROJECT_TOKEN=\|CODECLIMATE_REPO_TOKEN=\|CODECOV_TOKEN=\|coding_token=\|COMPONENT=\|CONEKTA_APIKEY=\|COVERALLS_TOKEN=\|COVERITY_SCAN_NOTIFICATION_EMAIL=\|COVERITY_SCAN_TOKEN=\|cred=\|csac=\|cssSelectorsEnabled=\|CXQEvvnEow=\|CYPRESS_RECORD_KEY=\|DANGER_GITHUB_API_TOKEN=\|DANGER_VERBOSE=\|DATABASE_HOST=\|DATABASE_NAME=\|DATABASE_PASSWORD=\|DATABASE_PORT=\|DATABASE_USER=\|DATABASE_USERNAME=\|databaseEnabled=\|datadog_api_key=\|datadog_app_key=\|DB_CONNECTION=\|DB_DATABASE=\|DB_HOST=\|DB_PASSWORD=\|DB_PORT=\|DB_PW=\|DB_USER=\|DB_USERNAME=\|DBP=\|-DdbUrl=\|DDG_TEST_EMAIL_PW=\|DDG_TEST_EMAIL=\|DDGC_GITHUB_TOKEN=\|DEPLOY_DIR=\|DEPLOY_DIRECTORY=\|DEPLOY_HOST=\|DEPLOY_PASSWORD=\|DEPLOY_PORT=\|DEPLOY_SECURE=\|DEPLOY_TOKEN=\|DEPLOY_USER=\|DEST_TOPIC=\|-Dgpg.passphrase=\|-Dmaven.javadoc.skip=\|DOCKER_EMAIL=\|DOCKER_HUB_PASSWORD=\|DOCKER_HUB_USERNAME=\|DOCKER_KEY=\|DOCKER_PASS=\|DOCKER_PASSWD=\|DOCKER_PASSWORD=\|DOCKER_POSTGRES_URL=\|DOCKER_RABBITMQ_HOST=\|docker_repo=\|DOCKER_TOKEN=\|DOCKER_USER=\|DOCKER_USERNAME=\|DOCKER=\|DOCKERHUB_PASSWORD=\|dockerhubPassword=\|dockerhubUsername=\|DOCKER-REGISTRY=\|DOORDASH_AUTH_TOKEN=\|DRIVER_NAME=\|DROPBOX_OAUTH_BEARER=\|DROPBOX=\|DROPLET_TRAVIS_PASSWORD=\|-Dsonar.organization=\|-Dsonar.projectKey=\|duration=\|ELASTIC_CLOUD_AUTH=\|ELASTIC_CLOUD_ID=\|ELASTICSEARCH_HOST=\|EXP_PASSWORD=\|EXP_USERNAME=\|EXPORT_SPACE_ID=\|EXTENSION_ID=\|F97qcq0kCCUAlLjAoyJg=\|FACEBOOK=\|FI2_RECEIVING_SEED=\|FI2_SIGNING_SEED=\|FILE_PASSWORD=\|FIREBASE_API_JSON=\|FIREBASE_API_TOKEN=\|FIREBASE_KEY=\|FIREFOX_ISSUER=\|FIREFOX_SECRET=\|FLASK_SECRET_KEY=\|FLICKR_API_KEY=\|FLICKR_API_SECRET=\|FLICKR=\|FOO=\|FOSSA_API_KEY=\|ftp_host=\|FTP_LOGIN=\|FTP_PASSWORD=\|FTP_PW=\|FTP_USER=\|ftp_username=\|fvdvd=\|gateway=\|GCLOUD_BUCKET=\|GCLOUD_PROJECT=\|GCLOUD_SERVICE_KEY=\|GCR_PASSWORD=\|GCR_USERNAME=\|GCS_BUCKET=\|GH_API_KEY=\|GH_EMAIL=\|GH_USER_EMAIL=\|GH_USER_NAME=\|GHB_TOKEN=\|GHOST_API_KEY=\|GIT_AUTHOR_EMAIL=\|GIT_AUTHOR_NAME=\|GIT_COMMITTER_EMAIL=\|GIT_COMMITTER_NAME=\|GIT_EMAIL=\|GIT_NAME=\|GIT_TOKEN=\|GIT_USER=\|GITHUB_ACCESS_TOKEN=\|GITHUB_API_KEY=\|GITHUB_API_TOKEN=\|GITHUB_AUTH_TOKEN=\|GITHUB_AUTH_USER=\|GITHUB_AUTH=\|GITHUB_KEY=\|GITHUB_OAUTH_TOKEN=\|GITHUB_OAUTH=\|GITHUB_PASSWORD=\|GITHUB_PWD=\|GITHUB_RELEASE_TOKEN=\|GITHUB_REPO=\|GITHUB_TOKEN=\|GITHUB_TOKENS=\|GITHUB_USER=\|GITHUB_USERNAME=\|GITLAB_USER_EMAIL=\|GPG_EMAIL=\|GPG_ENCRYPTION=\|GPG_EXECUTABLE=\|GPG_KEY_NAME=\|GPG_KEYNAME=\|GPG_NAME=\|GPG_OWNERTRUST=\|GPG_PASSPHRASE=\|GPG_PRIVATE_KEY=\|GPG_SECRET_KEYS=\|gradle.publish.key=\|gradle.publish.secret=\|HAB_KEY=\|handlesAlerts=\|hasTouchScreen=\|HB_CODESIGN_GPG_PASS=\|HB_CODESIGN_KEY_PASS=\|HEROKU_API_KEY=\|HEROKU_API_USER=\|HEROKU_EMAIL=\|HEROKU_TOKEN=\|HOCKEYAPP_TOKEN=\|HOMEBREW_GITHUB_API_TOKEN=\|HOOKS.SLACK.COM=\|HOST=\|--host=\|hpmifLs=\|HUB_DXIA2_PASSWORD=\|--ignore-ssl-errors=\|IJ_REPO_PASSWORD=\|IJ_REPO_USERNAME=\|IMAGE=\|INDEX_NAME=\|INSTAGRAM=\|INTEGRATION_TEST_API_KEY=\|INTEGRATION_TEST_APPID=\|INTERNAL-SECRETS=\|IOS_DOCS_DEPLOY_TOKEN=\|IRC_NOTIFICATION_CHANNEL=\|isbooleanGood=\|ISDEVELOP=\|isParentAllowed=\|iss=\|ISSUER=\|ITEST_GH_TOKEN=\|java.net.UnknownHostException=\|javascriptEnabled=\|JDBC:MYSQL=\|jdbc_host=\|jdbc_user=\|JWT_SECRET=\|jxoGfiQqqgvHtv4fLzI=\|KAFKA_ADMIN_URL=\|KAFKA_INSTANCE_NAME=\|KAFKA_REST_URL=\|KEY=\|KEYID=\|KEYSTORE_PASS=\|KOVAN_PRIVATE_KEY=\|KUBECFG_S3_PATH=\|KUBECONFIG=\|KXOlTsN3VogDop92M=\|LEANPLUM_APP_ID=\|LEANPLUM_KEY=\|LEKTOR_DEPLOY_PASSWORD=\|LINODE_INSTANCE_ID=\|LINODE_VOLUME_ID=\|LINUX_SIGNING_KEY=\|LL_API_SHORTNAME=\|LL_PUBLISH_URL=\|LL_SHARED_KEY=\|LL_USERNAME=\|LOCATION_ID=\|locationContextEnabled=\|LOGNAME=\|LOGOUT_REDIRECT_URI=\|LOOKER_TEST_RUNNER_CLIENT_ID=\|MAGENTO_PASSWORD=\|MAGENTO_USERNAME=\|MAIL_PASSWORD=\|MAIL_USERNAME=\|mailchimp_api_key=\|MAILCHIMP_KEY=\|mailchimp_list_id=\|mailchimp_user=\|MAILER_HOST=\|MAILER_PASSWORD=\|MAILER_TRANSPORT=\|MAILER_USER=\|MAILGUN_API_KEY=\|MAILGUN_APIKEY=\|MAILGUN_DOMAIN=\|MAILGUN_PASSWORD=\|MAILGUN_PRIV_KEY=\|MAILGUN_PUB_APIKEY=\|MAILGUN_PUB_KEY=\|MAILGUN_SECRET_API_KEY=\|MAILGUN_TESTDOMAIN=\|MANAGE_KEY=\|MANAGE_SECRET=\|MANAGEMENT_TOKEN=\|MG_DOMAIN=\|MG_EMAIL_ADDR=\|MG_EMAIL_TO=\|MG_PUBLIC_API_KEY=\|MG_SPEND_MONEY=\|MG_URL=\|MH_APIKEY=\|MH_PASSWORD=\|MILE_ZERO_KEY=\|MINIO_ACCESS_KEY=\|MINIO_SECRET_KEY=\|mobileEmulationEnabled=\|MONGO_SERVER_ADDR=\|MONGOLAB_URI=\|MULTI_ALICE_SID=\|MULTI_BOB_SID=\|MULTI_CONNECT_SID=\|MULTI_DISCONNECT_SID=\|MULTI_WORKFLOW_SID=\|MULTI_WORKSPACE_SID=\|MY_SECRET_ENV=\|jdbc_databaseurl=\|MYSQL_DATABASE=\|MYSQL_HOSTNAME=\|MYSQL_PASSWORD=\|MYSQL_ROOT_PASSWORD=\|MYSQL_USER=\|MYSQL_USERNAME=\|MYSQLMASTERUSER=\|MYSQLSECRET=\|nativeEvents=\|nexusPassword=\|nexusUrl=\|nexusUsername=\|NfZbmLlaRTClBvI=\|NGROK_AUTH_TOKEN=\|NGROK_TOKEN=\|NPM_API_KEY=\|NPM_API_TOKEN=\|NPM_AUTH_TOKEN=\|NPM_CONFIG_AUDIT=\|NPM_CONFIG_STRICT_SSL=\|NPM_EMAIL=\|NPM_PASSWORD=\|NPM_SECRET_KEY=\|NPM_TOKEN=\|NPM_USERNAME=\|NQc8MDWYiWa1UUKW1cqms=\|NtkUXxwH10BDMF7FMVlQ4zdHQvyZ0=\|NUGET_API_KEY=\|NUGET_APIKEY=\|NUGET_KEY=\|NUMBERS_SERVICE_PASS=\|NUMBERS_SERVICE_USER=\|NUMBERS_SERVICE=\|OCTEST_PASSWORD=\|OCTEST_SERVER_BASE_URL_2=\|OCTEST_SERVER_BASE_URL=\|OCTEST_USERNAME=\|OFTA_KEY=\|OFTA_REGION=\|OMISE_PKEY=\|OMISE_PUBKEY=\|OMISE_SKEY=\|ONESIGNAL_API_KEY=\|ONESIGNAL_USER_AUTH_KEY=\|OPEN_WHISK_KEY=\|OS_PASSWORD=\|OS_PROJECT_NAME=\|OS_REGION_NAME=\|OS_TENANT_ID=\|OS_TENANT_NAME=\|OS_USERNAME=\|OSSRH_JIRA_PASSWORD=\|OSSRH_JIRA_USERNAME=\|OSSRH_PASS=\|OSSRH_PASSWORD=\|OSSRH_SECRET=\|OSSRH_USER=\|PAGERDUTY_SERVICE_ID=\|PAGERDUTY=\|PANTHEON_SITE=\|PARSE_APP_ID=\|PARSE_JS_KEY=\|PASS=\|PASSWORD=\|--password=\|passwordTravis=\|PAT=\|PAYPAL_CLIENT_ID=\|PAYPAL_CLIENT_SECRET=\|PERCY_PROJECT=\|PERCY_TOKEN=\|PERSONAL_KEY=\|PERSONAL_SECRET=\|PG_DATABASE=\|PG_HOST=\|PHP_BUILT_WITH_GNUTLS=\|PLACES_API_KEY=\|PLACES_APIKEY=\|PLACES_APPID=\|PLACES_APPLICATION_ID=\|PLOTLY_APIKEY=\|PLOTLY_USERNAME=\|PLUGIN_PASSWORD=\|PLUGIN_USERNAME=\|POLL_CHECKS_CRON=\|POLL_CHECKS_TIMES=\|PROD.ACCESS.KEY.ID=\|PROD.SECRET.KEY=\|PROD_BASE_URL_RUNSCOPE=\|PROD_PASSWORD=\|PROD_USERNAME=\|PROJECT_CONFIG=\|props.disabled=\|PUBLISH_ACCESS=\|PUBLISH_KEY=\|PUBLISH_SECRET=\|PUSHOVER_TOKEN=\|PUSHOVER_USER=\|PYPI_PASSOWRD=\|PYPI_PASSWORD=\|PYPI_USERNAME=\QIITA_TOKEN=\|QIITA=\|qQ=\|QUIP_TOKEN=\|RABBITMQ_PASSWORD=\|RABBITMQ_SERVER_ADDR=\|raisesAccessibilityExceptions=\|RANDRMUSICAPIACCESSTOKEN=\|REDIS_STUNNEL_URLS=\|REDISCLOUD_URL=\|REFRESH_TOKEN=\|REGISTRY_PASS=\|REGISTRY_SECURE=\|REGISTRY_USER=\|REGISTRY=\|RELEASE_GH_TOKEN=\|RELEASE_TOKEN=\|remoteUserToShareTravis=\|REPO=\|REPORTING_WEBDAV_PWD=\|REPORTING_WEBDAV_URL=\|REPORTING_WEBDAV_USER=\|repoToken=\|REST_API_KEY=\|RestoreUseCustomAfterTargets=\|RINKEBY_PRIVATE_KEY=\|RND_SEED=\|ROPSTEN_PRIVATE_KEY=\|rotatable=\|route53_access_key_id=\|RTD_ALIAS=\|RTD_KEY_PASS=\|RTD_STORE_PASS=\|RUBYGEMS_AUTH_TOKEN=\|RUNSCOPE_TRIGGER_ID=\|S3_KEY_ASSETS=\|S3_KEY=\|S3_PHOTO_BUCKET=\|S3_SECRET_APP_LOGS=\|S3_SECRET_ASSETS=\|S3_SECRET_KEY=\|SANDBOX_AWS_SECRET_ACCESS_KEY=\|SANDBOX_LOCATION_ID=\|SAUCE_ACCESS_KEY=\|SAUCE_USERNAME=\|SCRUTINIZER_TOKEN=\|SDM4=\|sdr-token=\|SECRET ACCESS KEY=\|SECRET_0=\|SECRET_1=\|SECRET_10=\|SECRET_11=\|SECRET_2=\|SECRET_3=\|SECRET_4=\|SECRET_5=\|SECRET_6=\|SECRET_7=\|SECRET_8=\|SECRET_9=\|SECRET_KEY_BASE=\|SECRET=\|SECRETACCESSKEY=\|SECRETKEY=\|SEGMENT_API_KEY=\|SELION_LOG_LEVEL_DEV=\|SELION_LOG_LEVEL_USER=\|SELION_SELENIUM_HOST=\|SENDGRID_PASSWORD=\|SENDGRID_USER=\|SENDGRID_USERNAME=\|SENDGRID=\||SENDWITHUS_KEY=\|SENTRY_AUTH_TOKEN=\|setDstAccessKey=\|setDstSecretKey=\|setSecretKey=\|setWindowRect=\|SGcUKGqyoqKnUg=\|SIGNING_KEY_PASSWORD=\|SIGNING_KEY_SECRET=\|SIGNING_KEY_SID=\|SIGNING_KEY=\|SLACK_CHANNEL=\|SLACK_ROOM=\|SLACK_WEBHOOK_URL=\|SNYK_TOKEN=\|SOCRATA_APP_TOKEN=\|SOCRATA_PASSWORD=\|SOCRATA_USER=\|SOCRATA_USERNAME=\|SOME_VAR=\|SONATYPE_TOKEN_USER=\|SONATYPE_USER=\|SONATYPE_USERNAME=\|sonatypePassword=\|sonatypeUsername=\|SOUNDCLOUD_CLIENT_ID=\|SOUNDCLOUD_CLIENT_SECRET=\|SOUNDCLOUD_PASSWORD=\|SOUNDCLOUD_USERNAME=\|SPA_CLIENT_ID=\|SPACES_ACCESS_KEY_ID=\|sqsAccessKey=\|sqsSecretKey=\|SQUARE_READER_SDK_REPOSITORY_PASSWORD=\|SRC_TOPIC=\|SRCCLR_API_TOKEN=\|SSHPASS=\|STRIPE_PRIVATE=\|STRIPE_PUBLIC=\|SUBDOMAIN=\|SURGE_LOGIN=\|SURGE_TOKEN=\|SVN_PASS=\|SVN_USER=\|takesElementScreenshot=\|takesHeapSnapshot=\|takesScreenshot=\|TEAM_EMAIL=\|ted_517c5824cb79_iv=\|TESCO_API_KEY=\|TEST_GITHUB_TOKEN=\|TEST_TEST=\|test=\|tester_keys_password=\|THERA_OSS_ACCESS_ID=\|THERA_OSS_ACCESS_KEY=\|token_core_java=\|--token=\|TRAVIS_ACCESS_TOKEN=\|TRAVIS_API_TOKEN=\|TRAVIS_BRANCH=\|TRAVIS_COM_TOKEN=\|TRAVIS_E2E_TOKEN=\|TRAVIS_GH_TOKEN=\|TRAVIS_PULL_REQUEST=\|TRAVIS_SECURE_ENV_VARS=\|TRV=\|TWILIO_ACCOUNT_ID=\|TWILIO_ACCOUNT_SID=\|TWILIO_API_KEY=\|TWILIO_API_SECRET=\|TWILIO_CHAT_ACCOUNT_API_SERVICE=\|TWILIO_CONFIGURATION_SID=\|TWILIO_SID=\|TWILIO_TOKEN=\|TWILO=\|TWINE_PASSWORD=\|TWINE_USERNAME=\|UNITY_PASSWORD=\|UNITY_SERIAL=\|UNITY_USERNAME=\|URBAN_KEY=\|URBAN_MASTER_SECRET=\|URBAN_SECRET=\|USABILLA_ID=\|USE_SAUCELABS=\|USE_SSH=\|US-EAST-1.ELB.AMAZONAWS.COM=\|USER_ASSETS_ACCESS_KEY_ID=\|USER_ASSETS_SECRET_ACCESS_KEY=\|user=\|USERNAME=\||--username=\|userToShareTravis=\|userTravis=\|V_SFDC_CLIENT_ID=\|V_SFDC_CLIENT_SECRET=\|V_SFDC_PASSWORD=\|V_SFDC_USERNAME=\|V3GNcE1hYg=\|VAULT_ADDR=\|WATSON_DEVICE_TOPIC=\|WATSON_DEVICE=\|WATSON_PASSWORD=\|WATSON_TEAM_ID=\|WATSON_TOPIC=\|WATSON_USERNAME=\|WORKSPACE_ID=\|WPJM_PHPUNIT_GOOGLE_GEOCODE_API_KEY=\|WPORG_PASSWORD=\|WPT_DB_HOST=\|WPT_DB_NAME=\|WPT_DB_PASSWORD=\|WPT_DB_USER=\|WPT_PREPARE_DIR=\|WPT_REPORT_API_KEY=\|WPT_SSH_CONNECT=\|WPT_SSH_PRIVATE_KEY_BASE64=\|WPT_TEST_DIR=\|WWW.GOOGLEAPIS.COM=\|xsax=\|YANGSHUN_GH_PASSWORD=\|YANGSHUN_GH_TOKEN=\|YEi8xQ=\|YHrvbCdCrtLtU=\|YO0=\|Yszo3aMbp2w=\|YT_ACCOUNT_CHANNEL_ID=\|YT_ACCOUNT_CLIENT_ID=\|YT_ACCOUNT_CLIENT_SECRET=\|zenSonatypePassword=\|zenSonatypeUsername=\|ZHULIANG_GH_TOKEN=\|ZOPIM_ACCOUNT_KEY=\|jdbc' > ~/Research/Targets/$1/$1.JSSecretScrape.txt

## LAUNCH OTXURLS
echo -e "\nRUNNING \e[31m[OTXURLS]\e[0m"
cat ~/Research/Targets/$1/$1.all-final.txt | otxurls | uniq  >  ~/Research/Targets/$1/Endpoints/$1.otxurl.txt
echo "FOUND ENDPOINTS [$(cat ~/Research/Targets/$1/Endpoints/$1.otxurl.txt | wc -l)]"
echo "RUNNING OTXURLS \e[32mFINISH\e[0m"

## LAUNCH WAYBACKURLS
echo -e "\nRUNNING \e[31m[WAYBACKURLS]\e[0m"
echo $1 | waybackurls | sort -u > ~/Research/Targets/$1/Endpoints/$1.waybackruls.txt
echo "FOUND ENDPOINTS [$(cat ~/Research/Targets/$1/Endpoints/$1.waybackruls.txt | wc -l)]"
echo "RUNNING WAYBACKURLS \e[32mFINISH\e[0m"

## LAUNCH COMMONCRAWL
echo -e "\nRUNNING \e[31m[COMMONCRAWL]\e[0m"
curl -sX GET "http://index.commoncrawl.org/CC-MAIN-2018-22-index?url=*.$(cat ~/Research/Targets/$1/$1.domain.txt)&output=json" | jq -r .url | uniq > ~/Research/Targets/$1/Endpoints/$1.commoncrawl.txt 
echo "FOUND ENDPOINTS [$(cat ~/Research/Targets/$1/Endpoints/$1.commoncrawl.txt | wc -l)]"
echo "RUNNING COMMONCRAWL \e[32mFINISH\e[0m"

## LAUNCH GITHUB ENDPOINTS
echo -e "\nRUNNING \e[31m[GITHUB ENDPOINTS]\e[0m"
for git in $(cat ~/Research/Targets/$1/$1.root.txt);do python3 ~/Research/Tools/GitHubTool/github-endpoints.py -t $github_token -d $git -s -r > ~/Research/Targets/$1/GitHub/$git-endpoints.txt; done 
echo "FOUND ENDPOINTS [$(cat ~/Research/Targets/$1/GitHub/$git-endpoints.txt | wc -l)]"
echo "FOUND ENDPOINTS \e[32mFINISH\e[0m"

## REMOVING DUPLICATES
echo -e "\nTOTAL \e[31m[ENDPOINTS]\e[0m"
cat ~/Research/Targets/$1/GitHub/$1-endpoints.txt |grep -i "$1" |sort -u > ~/Research/Targets/$1/Endpoints/$1-giturls.txt
cat ~/Research/Targets/$1/Endpoints/$1-giturls.txt ~/Research/Targets/$1/Endpoints/$1.otxurl.txt ~/Research/Targets/$1/Endpoints/$1.waybackruls.txt ~/Research/Targets/$1/Endpoints/$1.commoncrawl.txt > ~/Research/Targets/$1/Endpoints/all-endpoints.txt
echo "TOTAL FOUND ENDPOINTS [$(cat ~/Research/Targets/$1/Endpoints/all-endpoints.txt | wc -l)]"

## REMOVING UNIQUE
cat ~/Research/Targets/$1/Endpoints/all-endpoints.txt | qsreplace -a  > ~/Research/Targets/$1/Endpoints/unique-endpoints.txt

## SEGRAGATING JSFILES
cat ~/Research/Targets/$1/Endpoints/all-endpoints.txt | grep "\.js$" > ~/Research/Targets/$1/Endpoints/jsfles.txt
echo "TOTAL FOUND JS ENDPOINTS [$(cat ~/Research/Targets/$1/Endpoints/jsfles.txt | wc -l)]"
echo "TOTAL FOUND UNIQUE ENDPOINTS [$(cat ~/Research/Targets/$1/Endpoints/unique-endpoints.txt | wc -l)]"
echo -e "\nEndpoints \e[32mCreated\e[0m "

## CREATING DICTIONARY OUT OF JS LINKS
cat ~/Research/Targets/$1/$1.Crawler.txt |grep linkfinder |cut -d ' ' -f2 |sed 's/\"//g' | sed 's/^[^a-zA-Z]*[0-9]*//' |sort -u > ~/Research/Targets/$1/Endpoints/dict-endpoints.txt
cat ~/Research/Targets/$1/GitHub/$1-endpoints.txt |unfurl paths |sort -u >> ~/Research/Targets/$1/Endpoints/dict-endpoints.txt
cat ~/Research/Targets/$1/Endpoints/dict-endpoints.txt |sort -u > ~/Research/Targets/$1/Endpoints/dict-endpoints2.txt
cat ~/Research/Targets/$1/Endpoints/unique-endpoints.txt |unfurl paths |sort -u >> ~/Research/Targets/$1/Endpoints/dict-endpoints2.txt
mv ~/Research/Targets/$1/Endpoints/dict-endpoints2.txt ~/Research/Targets/$1/Endpoints/dict-endpoints.txt
echo -e "\nDict \e[32mCreated\e[0m "

## LAUNCH GoBuster
echo -e "\nRUNNING \e[31m[GOBUSTER]\e[0m"
for go in $(cat ~/Research/Targets/$1/$1.livehosts.txt); do
       gobuster dir -u $go -e -l -s 200,204,401,403 -t 100 -w ~/Research/Targets/$1/Endpoints/dict-endpoints.txt -o ~/Research/Targets/$1/Endpoints/gobuster/$(echo $go | cut -d\? -f1 | sed 's/\//_/g' | sed 's/\:/_/g').gobuster.txt
done

## APPEND DIR BRUTE TO ENDPOINTS AND UNIQ
mv ~/Research/Targets/$1/Endpoints/gobuster/*www.$1.gobuster.txt ~/Research/Targets/$1/NotScanned/
for i in $(ls ~/Research/Targets/$1/Endpoints/gobuster); do
        size=$(cat ~/Research/Targets/$1/Endpoints/gobuster/"$i" | wc -l)
        if (( $size >= 50 )); then
                mv ~/Research/Targets/$1/Endpoints/gobuster/"$i" ~/Research/Targets/$1/NotScanned/
        else
                echo "$size Endpoint To Scan >> $i"
        fi
done

cat ~/Research/Targets/$1/Endpoints/gobuster/*.gobuster.txt |grep "Status:" |cut -d " " -f1 >> ~/Research/Targets/$1/Endpoints/unique-endpoints.txt
cat ~/Research/Targets/$1/Endpoints/unique-endpoints.txt |sort -u > ~/Research/Targets/$1/Endpoints/unique-endpoints_brute.txt
mv ~/Research/Targets/$1/Endpoints/unique-endpoints_brute.txt ~/Research/Targets/$1/Endpoints/unique-endpoints.txt
echo "RUNNING GOBUSTER \e[32mFINISH\e[0m"

## LAUNCH BRUTEX
echo -e "\nRUNNING \e[31m[BRUTEX]\e[0m"
for i in `cat ~/Research/Targets/$1/$1.probed.txt`; do
        stat_code=$(curl -s -o /dev/null -w "%{http_code}" "$i" --max-time 10)
        if [ 401 == $stat_code ]; then
                brutex $i >> ~/Research/Targets/$1/$1.brutex_creds.txt
        else
                echo "$stat_code >> $i"
        fi
done
echo "RUNNING BRUTEX \e[32mFINISH\e[0m"
mv ~/Research/Targets/$1/$1.amasspassive.txt ~/Research/Targets/$1/$1.assetfinder.txt ~/Research/Targets/$1/$1.dnsbuffer.txt ~/Research/Targets/$1/$1.domain.txt ~/Research/Targets/$1/$1.livehosts-strip.txt ~/Research/Targets/$1/$1.massdns.txt ~/Research/Targets/$1/$1.probed.txt ~/Research/Targets/$1/$1.resolved.txt ~/Research/Targets/$1/$1.root.txt ~/Research/Targets/$1/$1.txt ~/Research/Targets/$1/ip.txt ~/Research/Targets/$1/$1.alldomains.txt ~/Research/Targets/$1/$1.subfinder.txt ~/Research/Targets/$1/$1.Crawler.txt ~/Research/Targets/$1/$1.all-final.txt ~/Research/Targets/$1/Archived

##LAUNCH SQLMAP
echo -e "\nRUNNING \e[31m[SQLMAP]\e[0m"
for sql in $(cat ~/Research/Targets/$1/Endpoints/unique-endpoints.txt |grep "=" |fff | grep 200 | cut -d ' ' -f1); do
       sqlmap -u $sql --answer="redirect=N" --current-user --batch --threads=10
done
echo "RUNNING SQLMAP \e[32mFINISH\e[0m"

##LAUNCH SQLMAP
echo -e "\nRUNNING \e[31m[SQLMAP on NotScanned]\e[0m"
for i in $(ls ~/Research/Targets/$1/NotScanned); do
       sqlmap -u $(sort -t ' ' -nk5 ~/Research/Targets/$1/NotScanned/* -u |grep "=" | grep 200 | cut -d ' ' -f1) --answer="redirect=N" --current-user --batch --threads=10
done
echo "RUNNING SQLMAP on NotScanned \e[32mFINISH\e[0m"

## LAUNCH WAPITI
echo -e "\nRUNNING \e[31m[WAPITI]\e[0m"
cat ~/Research/Targets/$1/Endpoints/unique-endpoints.txt |fff |grep ' 200'| cut -d ' ' -f1 | while read url; do wapiti --scope url --flush-session -u "$url"/ -f txt -o ~/Research/Targets/$1/Wapiti/wapiti-$(echo $url | cut -d\? -f1 | sed 's/\//_/g' | sed 's/\:/_/g').txt ;done
echo "RUNNING WAPITI \e[32mFINISH\e[0m"

echo -e "\nRUNNING \e[31m[SUMMARY]\e[0m"

echo "[+] $(cat ~/Research/Targets/$1/Endpoints/unique-endpoints.txt) Interesting Files Found"
cat ~/Research/Targets/$1/Endpoints/unique-endpoints.txt |grep '\py$\|\rb$\|\php$\|\bak$\|\bkp$\|\cache$\|\cgi$\|\conf$\|\csv$\|\inc$\|\jar$\|\json$\|\jsp$\|\lock$\|\log$\|\rar$\|\old$\|\sql$\|\swp$\|\tar$\|\txt$\|\wadl$\|\zip$' |grep -v robots.txt | fff |grep 200 | awk '{print $1}' > ~/Research/Targets/$1/InterestingFiles.txt
echo "Files can be seen at InterestingFiles.txt"

echo "[+] SubDomain Takeover Tools Found $(cat ~/Research/Targets/$1/SubdomainTakeover/$1.result.txt |grep Vulnerable |wc -l) Vulnerable Hosts"
cat ~/Research/Targets/$1/SubdomainTakeover/$1.result.txt |grep -v "Not Vulnerable"

echo "[+] SQLMAP Found $(grep ',B\|,E\|,U\|,T,\|,S\|cross-site' ~/.sqlmap/output/*.csv |wc -l) Exploitable Endpoints"
grep ',B\|,E\|,U\|,T,\|,S\|cross-site' ~/.sqlmap/output/*.csv

echo "[+] Smuggler Found $(cat ~/Research/Targets/$1/Smuggle/$1.result.txt |grep VULNERABLE |wc -l) Vulnerable Endpoints"
cat ~/Research/Targets/$1/Smuggle/$1.Smuggled.txt |grep "VULNERABLE"

echo "[+] Wapiti Found $(cat ~/Research/Targets/$1/wapiti* |grep -i -A 2 'evil' |wc -l) Vulnerable Endpoints"
cat ~/Research/Targets/$1/wapiti* |grep -i -A 2 'evil'

echo "[+] Subdomains Not Scanned $(cat ~/Research/Targets/$1/NotScanned* |grep -i -A 2 'evil' |wc -l)"
ls ~/Research/Targets/$1/NotScanned

}

if [ -z "$1" ]
  then
    kill
else
        recon $1
fi
