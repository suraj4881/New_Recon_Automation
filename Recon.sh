#!/bin/bash

# Script to automate bug bounty recon process

# Variables
domain="<target_domain>"
output_dir="<output_directory>"
subdomains_file="$output_dir/subdomains.txt"
ips_file="$output_dir/ips.txt"
waybackurls_file="$output_dir/waybackurls.txt"
waybackrobots_file="$output_dir/waybackrobots.txt"
massdns_file="$output_dir/massdns.txt"
ffuf_wordlist="<path_to_wordlist>"
gittools_dir="$output_dir/gittools"
xsshunter_dir="$output_dir/xsshunter"

# Make output directory
if [ ! -d "$output_dir" ]; then
  mkdir $output_dir
fi

# Subdomain enumeration
echo "Running subdomain enumeration..."
subfinder -d $domain -o $subdomains_file
sublist3r -d $domain -o $subdomains_file
echo "Subdomain enumeration complete."

# Resolve subdomains to IPs
echo "Resolving subdomains to IPs..."
cat $subdomains_file | xargs -n1 -P10 dig +short | sort -u > $ips_file
echo "Subdomains resolved to IPs."

# Port scan
echo "Running port scan..."
nmap -iL $ips_file -T4 -p- -oN $output_dir/nmap.txt
echo "Port scan complete."

# Vulnerability scanning
echo "Running vulnerability scans..."
vulners -d $domain
getallurls $domain | httprobe | nuclei -t cves/
echo "Vulnerability scans complete."

# Directory enumeration
echo "Running directory enumeration..."
cat $subdomains_file | xargs -I{} sh -c "dirsearch -u 'http://{}' -w $ffuf_wordlist -e php,asp,aspx,jsp,html,txt -t 50 -r -f -o $output_dir/{}.txt"
echo "Directory enumeration complete."

# Wayback Machine analysis
echo "Running Wayback Machine analysis..."
cat $subdomains_file | waybackurls | tee $waybackurls_file | waybackrobots > $waybackrobots_file
echo "Wayback Machine analysis complete."

# DNS brute forcing
echo "Running DNS brute forcing..."
massdns -r /usr/share/massdns/lists/resolvers.txt -t A -o S -w $massdns_file $subdomains_file
echo "DNS brute forcing complete."

# Git reconnaissance
echo "Running Git reconnaissance..."
mkdir $gittools_dir
gittools -d $domain -w -o $gittools_dir
gitallsecrets -i $gittools_dir -o $gittools_dir
echo "Git reconnaissance complete."

# Cross-site scripting (XSS) hunting
echo "Running XSS hunting..."
mkdir $xsshunter_dir
cat $subdomains_file | xargs -I{} sh -c "python3 xsshunter.py -t {} -c $xsshunter_dir/cookies.txt -o $xsshunter_dir/{}"
echo "XSS hunting complete."

# Server-side request forgery (SSRF) detection
echo "Running SSRF detection..."
cat $subdomains_file | xargs -I{} sh -c "ssrfdetector -u http://{}"
echo "SSRF detection complete."

# SQL injection (SQLi) testing
echo "Running SQLi testing..."
cat $subdomains_file | xargs -I{} sh -c "sqlmap -u http://{} --batch --crawl=1 --random-agent --threads=10
