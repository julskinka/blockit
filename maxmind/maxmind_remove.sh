#!/bin/bash
#
# Remove blocklists with ipset and firewalld

if [[ $(id -u) != "0" ]]
then
  echo $(tput bold)$(tput setaf 1)"> you are not root."$(tput sgr0)
  exit 1
fi

# Remove firewalld rules and tables
for maxmind_list in $(ipset list | grep 'Name: maxmind' | awk -F ' ' '{print($2)}')
do
  if [[ $(firewall-cmd --direct --query-rule ipv4 filter INPUT 0 -m set --match-set ${maxmind_list} src -j DROP) = "yes" ]]
  then
    echo "Removing blocklist: ${maxmind_list}"
    firewall-cmd --permanent --direct --remove-rule ipv4 filter INPUT 0 -m set --match-set ${maxmind_list} src -j DROP
    firewall-cmd --reload
  else
    echo "Firewall rule already removed: ${maxmind_list}"
  fi
  ipset -quiet list ${maxmind_list}
  blocklist_retvar=$?
  if [[ ${blocklist_retvar} -eq "0" ]]
  then
    echo "Removing ipset table: ${maxmind_list}"
    ipset -quiet destroy ${maxmind_list}
  else
    echo "Ipset table already removed: ${maxmind_list}"
  fi
done

# Show firewalld rules and ipset tables
echo -e "\n\n"
echo $(tput bold)$(tput setaf 2)"> Firewalld direct rules"$(tput sgr0)
firewall-cmd --direct --get-all-rules
echo $(tput bold)$(tput setaf 2)"> ipset list"$(tput sgr0)
#ipset list | grep -A6 'Name: maxmind'
ipset list | grep 'Name: maxmind'
