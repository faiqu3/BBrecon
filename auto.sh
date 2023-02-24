
for maindomain in $@
do
	dir=$(pwd)
	. ./reconftw.cfg
	mkdir $maindomain
	cd $maindomain
	#Subdomain enumeration
	echo " "
	echo "[-] Subdomain enumeration"
	amass enum -config ${AMASS_CONFIG} -silent -d $maindomain -o domains
	echo "Amass Done!"
	subfinder -d $maindomain -silent | anew -q domains
	echo "Subfinder Done!"
	cat domains | goaltdns -w ${goaltdns} | httprobe -prefer-https -p http:8080 -p http:3000 -p http:8000 -p http:8888 | anew http
	echo "goaltdns Done!"
	#network enumeration
	echo "[-] Network enumeration"
	echo " "
	parallel -a domains "nmap {}" | tee nmapscan
	echo "Nmap Done!"	

	#url
	echo " "
	echo "[-] Url Gather"
	echo " "
	cat domains | waybackurls | anew -q urls

	#vulnerable_endpoints
	echo " "
	echo "[-] SSRF XSS SQLi"
	echo " "
	cat urls | gf ssrf > ssrf
	cat urls | gf xss >  xss
	cat urls | gf sqli >  sqli

	#scan
	echo " "
	echo "[-] Scan"
	echo " "
	nuclei -l http -t ~/nuclei-templates/takeovers/ -iserver cdacbpb4s04cr9d1dme0cycbzy4m9s1f4.oast.me -o takeovers
	echo "Takeover scan Done!"
	nuclei -l http -t ~/nuclei-templates/ssrf_nagli.yaml -iserver cdacbpb4s04cr9d1dme0cycbzy4m9s1f4.oast.me -o ssrf
	echo "SSRF scan Done!"
	nuclei -l http -t ~/nuclei-templates/cves -iserver cdacbpb4s04cr9d1dme0cycbzy4m9s1f4.oast.me -o cvescan
	echo "Cves scan Done!"
	nuclei -l http -t ~/nuclei-templates/exposed-panels -iserver cdacbpb4s04cr9d1dme0cycbzy4m9s1f4.oast.me -o exposed-panels
	echo "exposed-panels scan Done!"


	#screenshot
	echo ""
	echo "[-] Screenshot"
	echo ""
	python3 ~/EyeWitness/Python/EyeWitness.py -f http --web 	

	#subdomain takeover
	echo ""
	subjack -w domains -t 100 -timeout 30 -c ${tools}/fingerprints.json -o sub_takeovers.txt -ssl
	echo "subjack Done!"
	
	#Dns takeover
	cat domains | dnstake -s -o dns_takeover.txt
	echo "dnstake Done!"

	#Secret in JS file
	cat urls | grep -E "*.js" > jsfiles
	nuclei -silent -l jsfiles -t ~/FindSecret/js-secret.yaml -o jssecrets

	# make a directory search automation
	# /secure/ConfigurePortalPages!default.jspa?view=popular
	# /secure/ManageFilters.jspa?filterView=search&Search=Search&filterView=search&sortColumn=favcount&sortAscending=false
	# /secure/ContactAdministrators!default.jspa
	# /servicedesk/customer/user/login
	# /issues/?jql=
	# /plugins/servlet/oauth/users/icon-uri?consumerUri=http://google.com/
	# /rest/api/latest/groupuserpicker?query=1&maxResults=50000&showAvatar=true
	# /plugins/servlet/gadgets/makeRequest?url=https://example.com/
	# /plugins/servlet/Wallboard/?dashboardId=10000&dashboardId=10000&cyclePeriod=alert(document.domain)
	# /secure/QueryComponent!Default.jspa
	# /secure/ViewUserHover.jspa
	# /ViewUserHover.jspa?username=Admin
	# /rest/api/2/dashboard?maxResults=100
	# /pages/%3CIFRAME%20SRC%3D%22javascript%3Aalert(‘XSS’)%22%3E.vm
	# /rest/api/2/user/picker?query=admin
	# /s/thiscanbeanythingyouwant/_/META-INF/maven/com.atlassian.jira/atlassian-jira-webapp/pom.xml
	# /rest/api/2/user/picker?query=admin
	# /s/
	# /plugins/servlet/oauth/users/icon-uri?consumerUri=https://www.google.nl/
	# /secure/ConfigurePortalPages!default.jspa?view=search&searchOwnerUserName=x2rnu%3Cscript%3Ealert(1)%3C%2fscript%3Et1nmk&Search=Search
	# ConfigurePortalPages.jspa
	# /plugins/servlet/Wallboard/?dashboardId=10100&dashboardId=10101&cyclePeriod=(function(){alert(document.cookie);return%2030000;})()&transitionFx=none&random=true

	#Directory search
	# echo " "
	# echo "Fuzzing"
	# parallel -j 6 -a $dir/http "dirsearch -q -u {} -e php,asp,aspx,jsp,py,txt,conf,config,bak,backup,swp,old,db,sqlasp,aspx,aspx~,asp~,py,bak,bkp,cache,cgi,conf,csv,html,jar,json,jsp,jsp~,lock,log,sql,sql.gz,sql.zip,sql.tar.gz,sql~,tar,tar.bz2,tar.gz,txt,zip -i 200 -t 50 --full-url"
	# echo "Dirsearch Done!"
	cd ..
done
