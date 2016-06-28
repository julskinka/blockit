#!/bin/bash
#
# Author: https://github.com/julskinka
# https://opensource.org/licenses/GPL-3.0
#
# Create blocklists with ipset and firewalld
#
# https://www.iblocklist.com/

if [[ $(id -u) != "0" ]]
then
  echo $(tput bold)$(tput setaf 1)"> you are not root."$(tput sgr0)
  exit 1
fi

# Get more lists here: https://www.iblocklist.com/lists.php
# <name>="<name>:<id>"
ads="ads:dgxtneitpuvgqqcpfulq"
edu="edu:imlmncgrkbnacgcwfjvh"
level1="level1:ydxerpxkpcfqjaybcssw"
level2="level2:gyisgnzbhppbvsphucsw"
level3="level3:uwnukjqktoggdknzrhgh"
spyware="spyware:llvtlsjyoyiczbkjsxpf"
badpeers="badpeers:cwworuawihqvocglcoss"
spider="spider:mcvxsnihddgutbjfbghy"
hijacked="hijacked:usrcshglbiilevmyfhse"
dshield="dshield:xpbqleszmajjesnzddhv"
forumspam="forumspam:ficutxiwawokxlcyoeye"
webexploit="webexploit:ghlzqtqxnzctvvajwwag"
DROP="DROP:zbdlwrqkabxbcppvrnos"

# Lists to use
blocklists=( ${ads} ${edu} ${level1} ${spyware} ${badpeers} ${spider} ${hijacked} ${dshield} ${forumspam} ${webexploit} ${DROP} )

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-

# Temp directory
dir_tmp_iblocklist="/var/tmp/iblocklist"
rm -rf ${dir_tmp_iblocklist}
mkdir -pm 0755 ${dir_tmp_iblocklist}
cd ${dir_tmp_iblocklist}

# Download and create/add new enties to ipset table
for blocklist in "${blocklists[@]}"
do
  blocklist_name=$(echo ${blocklist} | awk -F ':' '{print($1)}')
  blocklist_id=$(echo ${blocklist} | awk -F ':' '{print($2)}')

  ipset list iblocklist_${blocklist_name} > /dev/null
  blocklist_retvar=$?
  if [[ ${blocklist_retvar} -eq "0" ]]
  then
    echo $(tput bold)$(tput setaf 2)"> Ipset table already exist: iblocklist_${blocklist_name}"$(tput sgr0)
  else
    echo $(tput bold)$(tput setaf 2)"> Download: ${blocklist_name} ${blocklist_id}"$(tput sgr0)
    wget -q -O ${blocklist_name}_${blocklist_id}.gz "http://list.iblocklist.com/?list=${blocklist_id}&fileformat=p2p&archiveformat=gz"

    echo $(tput bold)$(tput setaf 2)"> Extract ${blocklist_name}: ${blocklist_id}.gz"$(tput sgr0)
    gunzip ${blocklist_name}_${blocklist_id}.gz

    echo $(tput bold)$(tput setaf 2)"> Create ipset table: iblocklist_${blocklist_name}"$(tput sgr0)
    # adjust maxelem size
    ipset_maxelem=$(cat ${blocklist_name}_${blocklist_id} | wc -l)
    let "ipset_maxelem=ipset_maxelem+100"
    ipset -exist create iblocklist_${blocklist_name} hash:net maxelem ${ipset_maxelem}
    ipset flush iblocklist_${blocklist_name}

    for blocklist_range in $(cat ${blocklist_name}_${blocklist_id} | awk -F ':' '{print($2)}' | grep -vE '(^#|^$)')
    do
      #echo $(tput bold)$(tput setaf 2)"> ${blocklist_range}"$(tput sgr0)
      ipset -exist -quiet add iblocklist_${blocklist_name} ${blocklist_range}
    done
  fi
done

# Add DROP rule for ipset table
for blocklist in "${blocklists[@]}"
do
  blocklist_name=$(echo ${blocklist} | awk -F ':' '{print($1)}')
  blocklist_id=$(echo ${blocklist} | awk -F ':' '{print($2)}')

  if [[ $(firewall-cmd --permanent --direct --query-rule ipv4 filter INPUT 0 -m set --match-set iblocklist_${blocklist_name} src -j DROP) != "yes" ]]
  then
    echo $(tput bold)$(tput setaf 2)"> Firewalld rule for: iblocklist_${blocklist_name}"$(tput sgr0)
    firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -m set --match-set iblocklist_${blocklist_name} src -j DROP
    echo $(tput bold)$(tput setaf 2)"> Firewalld reload"$(tput sgr0)
    firewall-cmd --reload
  else
    echo $(tput bold)$(tput setaf 2)"> Firewalld rule for: iblocklist_${blocklist_name} already added."$(tput sgr0)
  fi
done

# Show firewalld rules and ipset tables
echo -e "\n\n"
echo $(tput bold)$(tput setaf 2)"> Firewalld direct rules"$(tput sgr0)
firewall-cmd --direct --get-all-rules
echo $(tput bold)$(tput setaf 2)"> ipset list"$(tput sgr0)
#ipset list | grep -A6 'Name: iblocklist'
ipset list | grep 'Name: iblocklist'
