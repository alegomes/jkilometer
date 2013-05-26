#!/bin/bash

#
# Copyright 2010 Alexandre Gomes
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


PORT=8977

function usage() {

	echo 
	echo "Usage: ./jmeteragent.sh [-c] [-h?] [-p 9999]"
	echo 
	echo -e "\t* no argument starts listening for connections on port 8977."
	echo -e "\t* -c Collects data in the form:\n" \
	 "\t\thttpd_conn|\n" \
	 "\t\ttomcat_conn|\n" \
	 "\t\tsys_load|\n" \
	 "\t\tmem_free|\n" \
	 "\t\tprocsrunning|\n" \
	 "\t\tprocsblocked|\n" \
	 "\t\tliferay_threads|\n" \
	 "\t\tliferay_runnable_threads|\n" \
	 "\t\tliferay_blocked_threads|\n" \
	 "\t\tliferay_waiting_threads|\n" \
	 "\t\tliferay_eden_usage|\n" \
	 "\t\tliferay_old_usage|\n" \
	 "\t\tliferay_perm_usage|\n" \
	 "\t\tdb_conn_estab|\t\t(if database port given with -p)\n" \
	 "\t\tdb_conn_tw\t\t(if database port given with -p)"
	echo -e "\t* -h or -? Shows this (beautiful) message."
	echo

	exit 
}

function killJMeter() {
	IFS=$'\n'
	for p in $(ps axu | grep $0 | grep -v grep); do
		JMETER_PID=$(echo $p | awk '{print $2}')
		echo "Finalizando processo $JMETER_PID"
		kill -9 $JMETER_PID &2> /dev/null
	done
	exit
}

function collect_data() {

	# NOW=`date '+%d/%m/%Y %H:%M:%S'`
	# echo "$NOW - Collecting metrics"

	if [[ `uname` == 'Darwin' ]]; then
		
		echo 
		echo "Sorry, but jkmagent only works on linux machines."
		echo "Want to port it to something else? Fork it you! http://github.com/alegomes/jkilometer ;-)"
		echo

		exit -1
	fi

	# TODO Review not used variables and their names 

	httpd_conn=$(netstat -an | grep -i ":80 " | grep -i estab | wc -l)
	tomcat_conn=$(netstat -an | grep -i ":8080 " | grep -i estab | wc -l) 
	sys_load=$(cat /proc/loadavg | awk '{print $1 }')
	mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')

	procsrunning=$(grep "procs_running" /proc/stat | awk '{print $2}')
	procsblocked=$(grep "procs_blocked" /proc/stat | awk '{print $2}')

	# Testing Tomcat
	javaserver_pid=$(jps | grep -i bootstrap | awk '{print $1}')
	
	# Testing JBoss
	if [[ -z "$javaserver_pid" ]]; then
		javaserver_pid=$(ps aux | grep -i  org.jboss.Main | grep -v grep | awk '{print $2}') 
	fi

	# Testing Glassfish
	if [[ -z "$javaserver_pid" ]]; then
		javaserver_pid=$(ps aux | grep -i com.sun.enterprise.glassfish | grep -v grep | awk '{print $2}') 
	fi

	# No compatiple server
	if [[ -z "$javaserver_pid" ]]; then
		echo 'No java server found!'
		exit 1
	fi
	
	# Getting java process owner
	tomcat_user=$(ps aux | grep -i $javaserver_pid | grep -i java | awk '{print $1}')

	# Sometimes ps shows uid instead of username 
	[[ $(echo $tomcat_user | egrep '^[0-9]+$') ]] && tomcat_user=$(getent passwd $tomcat_user | cut -d: -f1)

    # echo "$(tomcat_user) password can be asked next"

	su - $tomcat_user -c "jstack $javaserver_pid > /tmp/liferay_stack"
	su - $tomcat_user -c "jstat -gcutil $javaserver_pid > /tmp/liferay_stat"

	liferay_threads=$(grep -i java.lang.Thread.State /tmp/liferay_stack | wc -l)
	liferay_blocked_threads=$(grep -i java.lang.Thread.State /tmp/liferay_stack | grep -i block | wc -l)
	liferay_runnable_threads=$(grep -i java.lang.Thread.State /tmp/liferay_stack | grep -i runn | wc -l)
	liferay_waiting_threads=$(grep -i java.lang.Thread.State /tmp/liferay_stack | grep -i wait | wc -l)

	liferay_eden_usage=$(grep -v S0 /tmp/liferay_stat | awk '{print $3}')
	liferay_old_usage=$(grep -v S0 /tmp/liferay_stat | awk '{print $4}')
	liferay_perm_usage=$(grep -v S0 /tmp/liferay_stat | awk '{print $5}')

	if [ $liferay_blocked_threads -gt 300 ]; then
	 cp /tmp/liferay_stack /tmp/liferay_stack_$liferay_blocked_threads 
	fi

	db_conn_estab=$(netstat -an | grep -i -e ":${DBPORT}[ ]*estab" | wc -l)
	db_conn_tw=$(netstat -an | grep -i -e ":${DBPORT}[ ]*time_wait" | wc -l)

	echo "$httpd_conn;" \
	  "$tomcat_conn;" \
	  "$sys_load;" \
	  "$liferay_threads;" \
	  "$liferay_runnable_threads;" \
	  "$liferay_blocked_threads;" \
	  "$liferay_waiting_threads;" \
	  "$liferay_eden_usage;" \
	  "$liferay_old_usage;" \
	  "$liferay_perm_usage;" \
	  "$db_conn_estab;" \
	  "$db_conn_tw"

	exit 0
}

function start_listening_to_jmeter_script() {

        NC="nc -l -p $PORT -vv -c \"$0 -c\""
        
        # There must be a better way to check netcat version
        $(echo $NC) 2> /tmp/nc.log
        if [[ ! -z $(cat /tmp/nc.log | grep -i 'invalid option') ]]; then
           UBUNTU="looks like" 
        fi 

	echo 
	echo "JMeter Agent listeting on port ${PORT}."
	echo "Now you can start your tests...."
	echo
	
	while true; do
    if [[ -z $UBUNTU ]]; then 
		   nc -l -p $PORT -vv -c "$0 -c" 2> /dev/null
    else
    	echo `$0 -c` | nc -l $PORT
    fi
	
		trap "killJMeter" HUP
		trap "killJMeter" INT
		trap "killJMeter" QUIT
		trap "killJMeter" PIPE
		trap "killJMeter" TERM
		trap "killJMeter" KILL

    echo -n "."
	done
}

# -------------------------------------------------------------
# Script execution starts here.
# -------------------------------------------------------------

while getopts "chp?" OPT; do
case "$OPT" in
      "c") collect_data ;;
			"p") DBPORT="$OPTARG";;
      "h") usage;;
      "?") usage;;
  esac
done


start_listening_to_jmeter_script
