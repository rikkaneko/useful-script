#!/bin/bash
if [[ "$1" == "--help" ]]; then
  echo "Usage: Scan and ban malicious IPs from old logs file"
  echo "$0 <log-file> <filter-name> <jail-name>"
  exit
fi

fail2ban-regex "$1" "$2" "$3" --print-all-matched > f2b-matches.txt
grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" f2b-matches.txt | sort -u > f2b-ips-to-ban.txt
for ip in $(cat f2b-ips-to-ban.txt); do
  echo "Banning $ip..."
  fail2ban-client set "$3" banip $ip &> /dev/null
done