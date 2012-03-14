#!/bin/sh
#
# Copyright 2010 Alexandre Gomes, Ricardo Funke
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


#
# Required packages: dig (dns-utils)
# 


function usage() {
	echo
	echo "Uso: $0 <dns_ip_1> <dns_ip_2> <dns_ip_3>..."
	echo
	exit 1
}

[[ $# -eq 0 ]] && usage

DNS=($@)

SERVER=apache-lb01-tst
TEMP=/tmp/tjpr-dns.ping

for dns in ${DNS[@]}; do 
  alldns=$alldns";"$dns
done

HEADER="Date/Time;$alldns"

i=0
while (true); do
	
    now=$(date '+%d/%M/%Y %H:%M:%S')

	# Consulta DNSs
	unset dnsstat
    for dns in ${DNS[@]}; do 
  	  dig @$dns $SERVER > $TEMP"."$dns
	
      querytimeline=$(grep -i "query time" $TEMP"."$dns) 
      querytime=${querytimeline#;; Query time: }

	  dnsstat=${dnsstat}${querytime:=timeout}";"
    done

	# Prepara linha com cabecalho e estatisticas dos DNSs consultados
    stat_line="$HEADER\n$now;$dnsstat"

	# Verifica se Mac ou Linux
	if [[ -n "$(uname -a | grep -i darwin)" ]]; then
		echo="echo" 	# Mac
	else
		echo="echo -e" 	# Linux
	fi

	# Decide se cabecalho sera impresso ou nao
    if [[ "$(( i%5 ))" -eq "0" ]]; then
        $echo "$stat_line" | column -t -s\; 
    else
        $echo "$stat_line" | column -t -s\; | grep -v Date\/Time
    fi

    (( i++ ))
	sleep 5

done
  
