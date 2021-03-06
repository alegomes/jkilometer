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


#
# Required libs:
# bc, netcat
# 

# Must be the same as in jmeteragent.sh
AGENT_PORT=8977

# Max server metrics
MAX_CNX_HTTP=0
MAX_CNX_TOMCAT=0
MAX_SYS_LOAD=0
MAX_THREADS_BLOCKED=0
MAX_DB_CNX_ESTAB=0
MAX_DB_CNX_TW=0

# Timeout in seconds
TIMEOUT=1800

function killJKM() {
	IFS=$'\n'
	for p in $(ps axu | grep -i jmeter | grep $TEST_SUITE | grep -v $0); do
		JMETER_PID=$(echo $p | awk '{print $2}')
		echo "Killing $JMETER_PATH on process $JMETER_PID"
		kill -9 $JMETER_PID
	done
	
	for p in $(ps axu | grep -i ApacheJMeter.jar | grep $TEST_SUITE | grep -v $0); do
		JMETER_PID=$(echo $p | awk '{print $2}')
		echo "Killing JMeter Java on process $JMETER_PID"
		kill -9 $JMETER_PID
	done
	
	for p in $(ps aux | grep jkm.sh | grep -v grep); do
		JKILOMETER_PID=$(echo $p | awk '{print $2}')
		echo -e "\nKilling JKilometer Script on process $JKILOMETER_PID"
		kill -9 $JKILOMETER_PID
	done
	
	exit
}

function usage() {
   	echo 
   	echo "Usage:  ./jkm.sh -t <jmeter_script.jmx> -T <num_of_threads> -r <ramp_up> [-S <appserver_address> -R ip1,ip2,ip3... -c comment -H <proxy_address> -P <proxy_port> ] | -s | -h?"
   	echo 
  	echo -e "\t ** MASTER MODE **"
	  echo 
	  echo -e "\t   Required Arguments"
	  echo -e "\t   -------------------"
   	echo -e "\t   -t A JMeter test plan JMX file"
   	echo
   	echo -e "\t   -T Number of threads to run the test plan"
   	echo
   	echo -e "\t   -r Time (in seconds) JMeter has to start all the specified threads"
   	echo
	  echo -e "\t   Optional Arguments"
	  echo -e "\t   -------------------"
   	echo -e "\t   -S The Java server you wish to monitor during the test plan execution (jkmagent.sh needed)"
  	echo
  	echo -e "\t   -R JMeter slaves for distributed testing"
  	echo
  	echo -e "\t   -c A useful comment to distinguish previous test execution from the next one"
  	echo
  	echo -e "\t   -H Proxy server address"
  	echo
  	echo -e "\t   -P Proxy server port"
    echo
    echo -e "\t   -u Resource to be stressed (e.g. http://10.0.0.10:8080/pagina.html) [NOT READY]"
  	echo
  	echo -e "\t ** HELP MODE **"
  	echo
  	echo -e "\t   -h or -? Prints this help message."
  	echo
  	exit -1
}

function test_jmeter_existence() {

	for JMETER_MATCH in $(find -L . -iname jmeter | grep bin); do
		
		if [[ -f "$JMETER_MATCH" && -x "$JMETER_MATCH" ]]; then
			JMETER_PATH=$JMETER_MATCH
		fi
		
	done
	
	if [ -z "$JMETER_PATH"   ]; then
		echo
		echo "JMeter not found. Tell me where is it exporting JMETER_HOME variable."
		echo
		exit -1
	fi
	
}

function test_required_parameters() {

	JMETER_SERVER_PRESENT=`echo $@ | grep "\-s"`
	TEST_SUITE_PRESENT=`echo $@ | grep "\-t"`
	NUM_THREADS_PRESENT=`echo $@ | grep "\-T"`
	RAMP_UP_PRESENT=`echo $@ | grep "\-r"`

	if [ -z "$JMETER_SERVER_PRESENT" ]; then
	
		# Only if JMeter is not running in server mode
	
		if [ $# -lt "6" ]; then	
			usage;
		else

			if [ -z "$TEST_SUITE_PRESENT" ]; then
				echo "Argument missing: -t"
				usage	
			fi
	
			if [ -z "$NUM_THREADS_PRESENT" ]; then
				echo "Argument missing: -T"
				usage	
			fi
	
			if [ -z "$RAMP_UP_PRESENT" ]; then
				echo "Argument missing: -r"
				usage	
			fi
			
		fi
	fi
}

function test_parameters_consistence() {

	APPSERVER_PRESENT=`echo $@ | grep "\-S"`
	
	if [ ! -z "$APPSERVER_PRESENT" ] && [ -z "$JAVA_SERVER" ]; then
		echo "-S argument present, but no server address specified."
		usage	
	fi

	if [ ! -z "$PROXY_ADDR" ] && [ -z "$PROXY_PORT" ]; then
		echo "Argument missing: -P"
		usage
	fi

}

function update_test_suite() {

  BKP_SUFFIX=".bkp-`date +%Y%m%d%H%M`"

	# No Mac, a sintaxe eh 'sed -i SUFIXO ...'
	# No Linux, a sintaxe eh 'sed -iSUFIXO ...'
	# putafaltadesacanagem

	MAC=`uname -a | grep -i darwin`
	if [ -z "$MAC" ]; then
    # Eh Linux	
    SED_BKP_DIRECTIVE="-i$BKP_SUFFIX"
	else
    # Eh Mac
    SED_BKP_DIRECTIVE="-i $BKP_SUFFIX"
	fi

	# Change the number of threads and ramp up settings

	sed $SED_BKP_DIRECTIVE \
      -e "s/num_threads\">.*</num_threads\">${NUM_THREADS}</" \
	    -e "s/ramp_time\">.*</ramp_time\">${RAMP_UP}</" \
      $TEST_SUITE

  mv $TEST_SUITE$BKP_SUFFIX $BKP_DIR

  if [ "x$TARGET_URL" != "x" ]; then

    echo "Changing target URL..."
    #if [ ]
    #PROTOCOL=
    #sed -i$BKP_SUFFIX "s/domain\">.*</domain\">${NUM_THREADS}</" $TEST_SUITE 
  fi
}

function save_test_metrics() {

	TEST_METRICS=$1
	
  	echo -e $TEST_METRICS >> $TEST_REPORT

}

#
# Monitor JMeter client execution
#
function monitor_jmeter_execution() {

  LOCAL_HEADER=$(echo -e \
		 "Time;" \
		 "JMeterThStarted;" \
		 "JMeterThFinished;" \
		 "JMeterThRatio;" \
		 "JMeterErrors(to,ht,co)")

  JMETER_TH_FINISHED="-1"
  i=0
  while [ $JMETER_TH_FINISHED -lt $NUM_TOTAL_THREADS ] && [ -z $TIME_TO_TIMEOUT ]; do

    if [ "$i" -eq "0" ]; then
        FIRST_LINE=true
    fi

    let title=i%15
    if [ "$title" -eq "0" ]; then
        HAS_HEADER=true
    else
        HAS_HEADER=false
    fi

    NOW=`date '+%H:%M:%S'`

    if [ ! -e $JMETER_LOG_FILE ]; then
      echo
      echo "ERRO: Log file $JMETER_LOG_FILE was not created."
      echo
      exit -1
    fi

    if [ ! -e $LOG_FILE ]; then
      echo
      echo "ERRO: Log file $LOG_FILE was not created."
      echo
      exit -1
    fi

    # awk removes \t from wc output
    JMETER_TH_STARTED=$(cat $JMETER_LOG_FILE | grep "jmeter.threads.JMeterThread: Thread started" | wc -l )
    
    LAST_JMETER_TH_FINISHED=$JMETER_TH_FINISHED
    JMETER_TH_FINISHED=$(grep -E "httpSample"\|"HTTP Request" $LOG_FILE  | wc -l)
    
    if [ $JMETER_TH_FINISHED -ne $LAST_JMETER_TH_FINISHED ]; then
      TIME_LAST_FINISHED=$(date +%s)
    fi

  	JMETER_TH_RATIO=0
  	if [ "$JMETER_TH_STARTED" -gt "0" ]; then 
      JMETER_TH_RATIO=$((  100*${JMETER_TH_FINISHED}/${JMETER_TH_STARTED} ))
    fi

    # JMeter 2.8: httpSample
    # JMeter 2.9: HTTP Request
    JMETER_ERRORS=$(grep -E "httpSample"\|"HTTP Request" $LOG_FILE | grep -v "200,OK" | grep -v "rc=\"200\" rm=\"OK\"" | wc -l)


    # Timeout errors
    JMETER_ERRORS_TIMEOUT=$(grep SocketTimeoutException $LOG_FILE | wc -l)
  	JMETER_ERRORS_TIMEOUT_RATIO=0
    if [ "$JMETER_ERRORS_TIMEOUT" -gt "0" ]; then 
        JMETER_ERRORS_TIMEOUT_RATIO=$((  100*${JMETER_ERRORS_TIMEOUT}/${JMETER_TH_FINISHED} ))
    fi

    # No HTTP Response errors
    JMETER_ERRORS_NOHTTPRESPONSE=$(grep NoHttpResponseException $LOG_FILE | wc -l)
    JMETER_ERRORS_NOHTTPRESPONSE_RATIO=0
    if [ "$JMETER_ERRORS_NOHTTPRESPONSE" -gt "0" ]; then 
        JMETER_ERRORS_NOHTTPRESPONSE_RATIO=$((  100*${JMETER_ERRORS_NOHTTPRESPONSE}/${JMETER_TH_FINISHED} ))
    fi

    # SocketException errors
    JMETER_ERRORS_SOCKET=$(grep SocketException $LOG_FILE | wc -l)
    JMETER_ERRORS_SOCKET_RATIO=0
    if [ "$JMETER_ERRORS_SOCKET" -gt "0" ]; then 
        JMETER_ERRORS_SOCKET_RATIO=$((  100*${JMETER_ERRORS_SOCKET}/${JMETER_TH_FINISHED} ))
    fi

    # HttpHostConnectException

    SERVER=""

    # TODO Extract to function
    if [ ! -z "$JAVA_SERVER" ]; then

      if  $FIRST_LINE; then
          HEADER=$(echo -e "${LOCAL_HEADER};" \
         "ServerCnx:80;" \
         "ServerCnx:8080;" \
  		   "ServerSysLoad;" \
         "ServerJVMThAll;" \
         "ServerJVMThRun;" \
         "ServerJVMThBlk;" \
         "ServerJVMThWai;" \
         "ServerJVMEden;" \
         "ServerJVMOld;" \
         "ServerJVMPerm;" \
         "DbConnEstab;" \
         "DbConnTw" )
      fi

      # Collects app server metrics
      telnet $JAVA_SERVER $AGENT_PORT &> $SERVER_FILE 
      # Exemplo: 0; 0; 0.00; 61; 9; 0; 52; 40.38; 84.87; 99.90; 60; 9
      SERVER=`cat $SERVER_FILE | grep \;`

      if [ -n "$SERVER" ] && [ "$SERVER" != "X;X;X;X;X;X;X;X;X;X;X;X" ]; then
        http_connections=$(echo $SERVER | awk -F\; '{print $1}')
        tomcat_connections=$(echo $SERVER | awk -F\; '{print $2}')
        sysload=$(echo $SERVER | awk -F\; '{print $3}')
        th_blocked=$(echo $SERVER | awk -F\; '{print $6}')
        db_cnx_estab=$(echo $SERVER | awk -F\; '{print $11}')
        db_cnx_tw=$(echo $SERVER | awk -F\; '{print $12}')

        # Server metrics maximum value
        if (( $http_connections > $MAX_CNX_HTTP )); then
            MAX_CNX_HTTP=$http_connections
        fi

        if (( $tomcat_connections > $MAX_CNX_TOMCAT )); then
            MAX_CNX_TOMCAT=$tomcat_connections
        fi

        if [[ $(echo "$sysload > $MAX_SYS_LOAD" | bc) -eq 1 ]]; then
            MAX_SYS_LOAD=$sysload
        fi

        if (( $th_blocked > $MAX_THREADS_BLOCKED )); then
            MAX_THREADS_BLOCKED=$th_blocked
        fi

        if (( $db_cnx_estab > $MAX_DB_CNX_ESTAB )); then
            MAX_DB_CNX_ESTAB=$db_cnx_estab
        fi

        if (( $db_cnx_tw > $MAX_DB_CNX_TW )); then
            MAX_DB_CNX_TW=$db_cnx_tw
        fi
      fi
    fi
   	  
    line_with_header=$(echo $HEADER"\n" \
          "${NOW};" \
          "${JMETER_TH_STARTED};" \
          "${JMETER_TH_FINISHED};" \
          "${JMETER_TH_RATIO}%;" \
          "${JMETER_ERRORS}(${JMETER_ERRORS_TIMEOUT_RATIO}%,${JMETER_ERRORS_NOHTTPRESPONSE_RATIO}%,${JMETER_ERRORS_SOCKET_RATIO}%);" \
          "${SERVER}")

    line_no_header=$(echo "${NOW};" \
	        "${JMETER_TH_STARTED};" \
          "${JMETER_TH_FINISHED};" \
          "${JMETER_TH_RATIO}%;" \
          "${JMETER_ERRORS}(${JMETER_ERRORS_TIMEOUT_RATIO}%,${JMETER_ERRORS_NOHTTPRESPONSE_RATIO}%,${JMETER_ERRORS_SOCKET_RATIO}%);" \
	        "${SERVER}")

    #
    # Imprimir ou nao imprimir o cabecalho?
    #

    if $HAS_HEADER; then

      # In the log file, header must be printed only once 
      if $FIRST_LINE; then 
        TEST_METRICS="$line_with_header"; 
      fi
      
      # With header
      echo -e "$line_with_header" | column -t -s\; 
        
    else 
    
      TEST_METRICS="$line_no_header"

       # Without header	
       echo -e "$line_with_header" | column -t -s\; | grep -v JMeterThStarted
         
    fi

    save_test_metrics "$TEST_METRICS"

    line=""

    (( i = i + 1 ))

    # If requests take too long to be responded...
    NOW=$(date +%s)
    (( TIME_SINCE_LAST_FINISHED = NOW - TIME_LAST_FINISHED ))
    if [ $TIME_SINCE_LAST_FINISHED -gt $TIMEOUT ]; then
      TIME_TO_TIMEOUT="$TIME_SINCE_LAST_FINISHED > $TIMEOUT";
    else
      unset TIME_TO_TIMEOUT
    fi

    sleep 5

  done

  if [ -n "$TIME_TO_TIMEOUT" ]; then
    echo "Test timed out with $JMETER_TH_STARTED started and $JMETER_TH_FINISHED finished threads."
    echo "($TIME_TO_TIMEOUT)"
  fi

}

function process_jmeter_log() {

	# Process JMeter client result
 
  REGEX='Generate Summary Results =[ ]+([0-9]+) in[ ]+ ([0-9.,]+)s =[ ]+([0-9.,]+)\/s Avg:[ ]+([0-9]+) Min:[ ]+([0-9]+) Max:[ ]+([0-9]+) Err:[ ]+ [0-9]+ \(([0-9.,]+)%\)'

	SUMMARY_RESULTS=`grep -E "$REGEX" $TMP_FILE`

	# Parse JMeter 'Generate Summary Results' listener output.
	# e.g Generate Summary Results = 10 in 1.1s = 9.5/s Avg: 133 Min: 93 Max: 165 Err: 0 (0.00%)

  if [[ "$SUMMARY_RESULTS" =~ $REGEX ]] 
	then 

		HEADER="Time;Samples;RampUp;TotalTime;Throughput;Avg;Min;Max;Err;MaxCnxHTTP;MaxCnxTomcat;MaxSysLoad;MaxThBlocked;MaxDbCnxEstab;MaxDbCnxTw"
		
		if [[ ! -z $COMMENT ]]; then
		  echo "#" 		       	>> $SUMMARY_FILE
			echo "# $COMMENT" 	>> $SUMMARY_FILE 
			echo "#"  		     	>> $SUMMARY_FILE
			echo $HEADER     		>> $SUMMARY_FILE
		fi
		
		echo "${START_TIME};${BASH_REMATCH[1]};${RAMP_UP};${BASH_REMATCH[2]};${BASH_REMATCH[3]};${BASH_REMATCH[4]};${BASH_REMATCH[5]};${BASH_REMATCH[6]};${BASH_REMATCH[7]};${MAX_CNX_HTTP};${MAX_CNX_TOMCAT};${MAX_SYS_LOAD};${MAX_THREADS_BLOCKED};${MAX_DB_CNX_ESTAB};${MAX_DB_CNX_TW}"  >> $SUMMARY_FILE
	else
	    echo "JMeter results not in expected format! Is 'Generate Summary Result' listener present in $TEST_SUITE ?"
	    echo "-->${SUMMARY_RESULTS}<--"
      echo "......... $TMP_FILE >>>>>>>>>>>>"
      cat $TMP_FILE
      echo "<<<<<<<<< $TMP_FILE ............"
	    return
	fi

	echo "---------------------------------"
	echo "           FIM DO TESTE"
	echo " veja os ultimos dados coletados"
	echo "---------------------------------"
	tail -5 $SUMMARY_FILE

}

function save_errors() {

  grep -E "httpSample"\|"HTTP Request" $LOG_FILE | grep -v "200,OK" | grep -v "rc=\"200\" rm=\"OK\"" > $ERRORS_FILE
	
}

function backup_log_files {
  mkdir -p $BKP_DIR &> /dev/null

  NOW=$(date +%Y%m%d%H%M)
  echo "Backing up $LOG_FILE, $TMP_FILE and $JMETER_LOG_FILE in timestamp $NOW"
  mv $LOG_FILE        $BKP_DIR/${LOG_FILE}.$NOW
  mv $TMP_FILE        $BKP_DIR/${TMP_FILE}.$NOW
  mv $JMETER_LOG_FILE $BKP_DIR/${JMETER_LOG_FILE}.$NOW
}

function delete_log_files {
  rm $JMETER_LOG_FILE $LOG_FILE $TMP_FILE &> /dev/null
}

function test_suite_existence() {

	if ! [ -a "$TEST_SUITE" ]; then
		echo
		echo "${TEST_SUITE} not found."
		echo
		exit -1
	fi

}

function init_test_report() {

	echo "#" >> $TEST_REPORT
	echo "# $START_TIME Running $TEST_SUITE with $NUM_THREADS threads in $RAMP_UP secs." >> $TEST_REPORT
	echo "#" >> $TEST_REPORT
	
}

function run_jmeter_client() {

	update_test_suite
  delete_log_files

  JMETER_CMD="$JMETER_PATH -n -t $TEST_SUITE -l $LOG_FILE"

  if [ -n "$PROXY_ADDR" ]; then
   JMETER_CMD=$JMETER_CMD" -H $PROXY_ADDR -P $PROXY_PORT"
  fi
  $JMETER_CMD $REMOTE_SERVERS > $TMP_FILE &

  # Time before jmeter.log creation
  (( i = 0 ))
  echo "Waiting for $LOG_FILE file creation..."
  while [ ! -e ${LOG_FILE} ] && [ $i -lt  30 ]; do
    ILLEGAL_STATE_EXCEPTION="$(grep IllegalStateException $TMP_FILE)"
    if [ -n "$ILLEGAL_STATE_EXCEPTION" ]; then
      echo 
      echo "[ERROR] JMeter execution failed: [ $ILLEGAL_STATE_EXCEPTION ]"
      echo
      exit -1
    fi
	 sleep 2 
   (( i++ ))
  done
	
	init_test_report
	
	monitor_jmeter_execution

	process_jmeter_log
	
	save_errors

  backup_log_files
	
	exit $?

}

# ---------------------------------------------------------
# Script starts here
# ---------------------------------------------------------

trap "killJKM" HUP
trap "killJKM" INT
trap "killJKM" QUIT
trap "killJKM" PIPE
trap "killJKM" TERM
trap "killJKM" KILL

test_jmeter_existence

test_required_parameters $@

# Avoiding 'Too Many Open Files'. Increase this value if you still get the error.
ulimit -n 8192

# Files to be used

JMETER_LOG_FILE="jmeter.log"
LOG_FILE="detailed_log.jmeter"
TMP_FILE="summary_results.jmeter"
SERVER_FILE="server_metrics.jmeter"
SUMMARY_FILE="reports/summary_results.csv"
TEST_REPORT="reports/tests_results.csv"
ERRORS_FILE="reports/errors.txt"
BKP_DIR="bkps" 
mkdir -p $BKP_DIR &> /dev/null

rm $LOG_FILE &> /dev/null

if [[ ! -e reports ]]; then mkdir -v reports; fi
	
# Check passed arguments

while getopts "t:T:r:R:c:h:H:P:S:h?" OPT; do
  case "$OPT" in
    "t") TEST_SUITE="$OPTARG" ;;
 	  "T") NUM_THREADS="$OPTARG" ;;
    "r") RAMP_UP="$OPTARG" ;;
    "R") REMOTE_SERVERS="-R$OPTARG" ;;
	  "c") COMMENT="$OPTARG" ;;
    "S") JAVA_SERVER="$OPTARG" ;;
	  "H") PROXY_ADDR="$OPTARG" ;;
	  "P") PROXY_PORT="$OPTARG" ;;
    "u") TARGET_URL="$OPTARG" ;;
    "h") usage;;
    "?") usage;;
  esac
done

SERVERS_QTD=$(( $(echo $REMOTE_SERVERS | grep -o , | wc -l) + 1 ))
NUM_TOTAL_THREADS=$(( NUM_THREADS * SERVERS_QTD))

test_parameters_consistence

test_suite_existence

START_TIME=`date '+%d/%m/%Y %H:%M:%S'`

run_jmeter_client

FINISH_TIME=`date '+%d/%m/%Y %H:%M:%S'`

echo "Test started at ${START_TIME} and ended at ${FINISH_TIME}."
