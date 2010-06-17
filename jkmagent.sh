#!/bin/bash

PORT=8977

function usage() {

	echo 
	echo "Usage: ./jmeteragent.sh [-c] [-h?]"
	echo 
	echo -e "\t* no argument starts listening for connections on port 8977."
	echo -e "\t* -c Collects data in the form:\n" \
	 "\t\thttpd_conn|liferay_conn|\n" \
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
	 "\t\tliferay_perm_usage"
	echo -e "\t* -h or -? Shows this (beautiful) message."
	echo
}

function killJMeter() {
	IFS=$'\n'
	for p in $(ps axu | grep -i jmeteragent | grep -v $0); do
		JMETER_PID=$(echo $p | awk '{print $2}')
		echo "Finalizando processo $JMETER_PID"
		kill -9 $JMETER_PID
	done
	exit
}

function collect_data() {

	# NOW=`date '+%d/%m/%Y %H:%M:%S'`
	# echo "$NOW - Collecting metrics"

	# TODO Review not used variables and their names 

	httpd_conn=$(netstat -an | grep -i ":80 " | grep -i estab | wc -l)
	liferay_conn=$(netstat -an | grep -i ":8080 " | grep -i estab | wc -l) # 'liferay' could be easly replaced by 'tomcat'
	sys_load=$(cat /proc/loadavg | awk '{print $1 }')
	mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')

	procsrunning=$(grep "procs_running" /proc/stat | awk '{print $2}')
	procsblocked=$(grep "procs_blocked" /proc/stat | awk '{print $2}')

	liferay_pid=$(jps | grep -i bootstrap | awk '{print $1}')
	tomcat_user=$(ps aux | grep -i $liferay_pid | grep -i java | awk '{print $1}')

	su $tomcat_user -c "jstack $liferay_pid > /tmp/liferay_stack"
	su $tomcat_user -c "jstat -gcutil $liferay_pid > /tmp/liferay_stat"

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

	echo "$httpd_conn," \
	  "$liferay_conn," \
	  "$sys_load," \
	  "$liferay_threads," \
	  "$liferay_runnable_threads," \
	  "$liferay_blocked_threads," \
	  "$liferay_waiting_threads," \
	  "$liferay_eden_usage," \
	  "$liferay_old_usage," \
	  "$liferay_perm_usage"
	
	exit 0
}

function start_listening_to_jmeter_script() {

	echo 
	echo "JMeter Agent listeting on port ${PORT}."
	echo "Now you can start your tests...."
	echo
	
	while true; do
		nc -l -p $PORT -vv -c "$0 -c" 2> /dev/null
	
		trap "killJMeter" HUP
		trap "killJMeter" INT
		trap "killJMeter" QUIT
		trap "killJMeter" PIPE
		trap "killJMeter" TERM
		trap "killJMeter" KILL
	done
}

# -------------------------------------------------------------
# Script execution starts here.
# -------------------------------------------------------------

while getopts "ch?" OPT; do
case "$OPT" in
      "c") collect_data ;;
      "h") usage;;
      "?") usage;;
  esac
done


start_listening_to_jmeter_script