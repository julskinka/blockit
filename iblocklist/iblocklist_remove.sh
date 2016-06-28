#!/bin/bash
#
# Author: https://github.com/julskinka
# https://opensource.org/licenses/GPL-3.0
#
# Remove blocklists with ipset and firewalld

if [[ $(id -u) != "0" ]]
then
  echo $(tput bold)$(tput setaf 1)"> you are not root."$(tput sgr0)
  exit 1
fi

# Remove firewalld rules and tables
for iblocklist_list in $(ipset list | grep 'Name: iblocklist' | awk -F ' ' '{print($2)}')
do
  if [[ $(firewall-cmd --direct --query-rule ipv4 filter INPUT 0 -m set --match-set ${iblocklist_list} src -j DROP) = "yes" ]]
  then
    echo $(tput bold)$(tput setaf 1)"> Removing blocklist: ${iblocklist_list}"$(tput sgr0)
    firewall-cmd --permanent --direct --remove-rule ipv4 filter INPUT 0 -m set --match-set ${iblocklist_list} src -j DROP
    firewall-cmd --reload
  else
    echo $(tput bold)$(tput setaf 1)"> Firewall rule already removed: ${iblocklist_list}"$(tput sgr0)
  fi
  ipset -quiet list ${iblocklist_list}
  blocklist_retvar=$?
  if [[ ${blocklist_retvar} -eq "0" ]]
  then
    echo $(tput bold)$(tput setaf 1)"> Removing ipset table: ${iblocklist_list}"$(tput sgr0)
    ipset -quiet destroy ${iblocklist_list}
  else
    echo $(tput bold)$(tput setaf 1)"> Ipset table already removed: ${iblocklist_list}"$(tput sgr0)
  fi
done

# Show firewalld rules and ipset tables
echo -e "\n\n"
echo $(tput bold)$(tput setaf 2)"> Firewalld direct rules"$(tput sgr0)
firewall-cmd --direct --get-all-rules
echo $(tput bold)$(tput setaf 2)"> ipset list"$(tput sgr0)
#ipset list | grep -A6 'Name: iblocklist'
ipset list | grep 'Name: iblocklist'
