
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
	cat urls | gf ssrf | anew -q ssrf
	cat urls | gf xss | anew -q xss
	cat urls | gf sqli | anew -q sqli

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
	subjack -w domains -t 100 -timeout 30 -c ${tools}/fingerprints.json -o sub_takeovers.txt -ssl

	#Dns takeover
	cat domains | dnstake -s -o dns_takeover.txt

	#Directory search
	# echo " "
	# echo "Fuzzing"
	# parallel -j 6 -a $dir/http "dirsearch -q -u {} -e php,asp,aspx,jsp,py,txt,conf,config,bak,backup,swp,old,db,sqlasp,aspx,aspx~,asp~,py,bak,bkp,cache,cgi,conf,csv,html,jar,json,jsp,jsp~,lock,log,sql,sql.gz,sql.zip,sql.tar.gz,sql~,tar,tar.bz2,tar.gz,txt,zip -i 200 -t 50 --full-url"
	# echo "Dirsearch Done!"
	cd ..
done
