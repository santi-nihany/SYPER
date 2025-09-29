for ip in $(cat devices.txt); do
    whois $ip | grep -i "CIDR\|NetRange" | head -1 >> ip_blocks_temp.txt
done
sort -u ip_blocks_temp.txt > ip_blocks.txt