#!/bin/bash
#
# Author: https://github.com/julskinka
# https://opensource.org/licenses/GPL-3.0
#
# Create blocklists with ipset and firewalld
#
# https://dev.maxmind.com/geoip/geoip2/geolite2/
#
# https://en.wikipedia.org/wiki/List_of_sovereign_states_and_dependent_territories_by_continent_(data_file)

if [[ $(id -u) != "0" ]]
then
  echo $(tput bold)$(tput setaf 1)"> you are not root."$(tput sgr0)
  exit 1
fi

# Continent Code
continent_codes=( AF AS )

# Country Codes
country_codes=( BG PT RO RS RU XK )

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-

dir_tmp_block="/var/tmp/geoip_block"
rm -rf ${dir_tmp_block}
mkdir -pm 0755 ${dir_tmp_block}
cd ${dir_tmp_block}

# Download
echo $(tput bold)$(tput setaf 2)"> Download: GeoLite2-Country-CSV.zip"$(tput sgr0)
wget -q http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country-CSV.zip

echo $(tput bold)$(tput setaf 2)"> Extract GeoLite2-Country-CSV.zip"$(tput sgr0)
unzip GeoLite2-Country-CSV.zip

# Create/add new enties to ipset table
for country_code in "${country_codes[@]}"
do
  #echo "country_code: ${country_code}"
  ipset list maxmind_${country_code} > /dev/null
  maxmind_retvar=$?

  if [[ ${maxmind_retvar} -eq "0" ]]
  then
    #echo "True"
    echo $(tput bold)$(tput setaf 2)"> Ipset table already exist: maxmind_${country_code}"$(tput sgr0)
    sleep 3
  else
    geoname_ids=$(awk -F ',' '$5 == "'${country_code}'" {print($1)}' GeoLite2-Country-CSV_*/GeoLite2-Country-Locations-en.csv)
    for geoname_id in ${geoname_ids}
    do
      #echo "geoname_id: ${geoname_id}"
      networks=$(awk -F ',' '$2 == "'${geoname_id}'" {print($1)}' GeoLite2-Country-CSV_*/GeoLite2-Country-Blocks-IPv4.csv > ${country_code}.networks)
      echo $(tput bold)$(tput setaf 2)"> Create ipset table: maxmind_${country_code}"$(tput sgr0)
      # adjust maxelem size
      ipset_maxelem=$(cat ${country_code}.networks | wc -l)
      let "ipset_maxelem=ipset_maxelem+100"
      ipset -exist create maxmind_${country_code} hash:net maxelem ${ipset_maxelem}
      ipset flush maxmind_${country_code}

      for network in $(cat ${country_code}.networks)
      do
        echo "DROP Network: ${network}"
        ipset -exist -quiet add maxmind_${country_code} ${network}
      done

      # Add DROP rule for ipset table
      if [[ $(firewall-cmd --permanent --direct --query-rule ipv4 filter INPUT 0 -m set --match-set maxmind_${country_code} src -j DROP) != "yes" ]]
      then
        echo $(tput bold)$(tput setaf 2)"> Firewalld rule for: maxmind_${country_code}"$(tput sgr0)
        firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -m set --match-set maxmind_${country_code} src -j DROP
        echo $(tput bold)$(tput setaf 2)"> Firewalld reload"$(tput sgr0)
        firewall-cmd --reload
      else
        echo $(tput bold)$(tput setaf 2)"> Firewalld rule for: maxmind_${country_code} already added."$(tput sgr0)
      fi
    done
  fi
done

# Create/add new enties to ipset table
for continent_code in "${continent_codes[@]}"
do
  #echo "continent_code: ${continent_code}"
  geoname_ids=$(awk -F ',' '$3 == "'${continent_code}'" {print($1)}' GeoLite2-Country-CSV_*/GeoLite2-Country-Locations-en.csv)
  for geoname_id in ${geoname_ids}
  do
    #echo "geoname_id: ${geoname_id}"
    country_code=$(awk -F ',' '$1 == "'${geoname_id}'" {print($5)}' GeoLite2-Country-CSV_*/GeoLite2-Country-Locations-en.csv)
    #echo "country_code: ${country_code}"
    ipset list maxmind_${country_code} > /dev/null
    maxmind_retvar=$?

    if [[ ${maxmind_retvar} -eq "0" ]]
    then
      #echo "True"
      echo $(tput bold)$(tput setaf 2)"> Ipset table already exist: maxmind_${country_code}"$(tput sgr0)
      sleep 3
    else
      geoname_ids=$(awk -F ',' '$5 == "'${country_code}'" {print($1)}' GeoLite2-Country-CSV_*/GeoLite2-Country-Locations-en.csv)
      for geoname_id in ${geoname_ids}
      do
        #echo "geoname_id: ${geoname_id}"
        networks=$(awk -F ',' '$2 == "'${geoname_id}'" {print($1)}' GeoLite2-Country-CSV_*/GeoLite2-Country-Blocks-IPv4.csv > ${country_code}.networks)
        echo $(tput bold)$(tput setaf 2)"> Create ipset table: maxmind_${country_code}"$(tput sgr0)
        # adjust maxelem size
        ipset_maxelem=$(cat ${country_code}.networks | wc -l)
        let "ipset_maxelem=ipset_maxelem+100"
        ipset -exist create maxmind_${country_code} hash:net maxelem ${ipset_maxelem}
        ipset flush maxmind_${country_code}

        for network in $(cat ${country_code}.networks)
        do
          echo "network: ${network}"
          ipset -exist -quiet add maxmind_${country_code} ${network}
        done

        # Add DROP rule for ipset table
        if [[ $(firewall-cmd --permanent --direct --query-rule ipv4 filter INPUT 0 -m set --match-set maxmind_${country_code} src -j DROP) != "yes" ]]
        then
          echo $(tput bold)$(tput setaf 2)"> Firewalld rule for: maxmind_${country_code}"$(tput sgr0)
          firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -m set --match-set maxmind_${country_code} src -j DROP
          echo $(tput bold)$(tput setaf 2)"> Firewalld reload"$(tput sgr0)
          firewall-cmd --reload
        else
          echo $(tput bold)$(tput setaf 2)"> Firewalld rule for: maxmind_${country_code} already added."$(tput sgr0)
        fi
      done
    fi
  done
done

# Show firewalld rules and ipset tables
echo -e "\n\n"
echo $(tput bold)$(tput setaf 2)"> Firewalld direct rules"$(tput sgr0)
firewall-cmd --direct --get-all-rules
echo $(tput bold)$(tput setaf 2)"> ipset list"$(tput sgr0)
#ipset list | grep -A6 'Name: maxmindipset list | grep 'Name: maxmind'
