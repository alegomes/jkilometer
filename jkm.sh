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
TIMEOUT=300

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
   	echo -e "\t   -T The number of threads to run the test plan"
   	echo
   	echo -e "\t   -r The time (in seconds) JMeter has to start all the specified threads"
   	echo
	  echo -e "\t   Optional Arguments"
	  echo -e "\t   -------------------"
   	echo -e "\t   -S The Java server you wish to monitor during the test plan execution (jkmagent.sh needed)"
  	echo
  	echo -e "\t   -R Set of JMeter Slaves addresses to help on test plan execution !!! NOT TESTED !!!"
  	echo
  	echo -e "\t   -c A useful comment to distinguish previous test execution from the next one"
  	echo
  	echo -e "\t   -H Proxy server address"
  	echo
  	echo -e "\t   -P Proxy server port"
    echo
    echo -e "\t   -u Resource to be stressed (e.g. http://10.0.0.10:8080/pagina.html)"
  	echo
  	# echo -e "\t ** SLAVE MODE **"
  	# echo
  	# echo -e "\t   -s Start JMeter in slave mode for remote testing (see http://jakarta.apache.org/jmeter/usermanual/remote-test.html) !!! NOT TESTED !!!"
  	# echo
  	echo -e "\t ** HELP MODE **"
  	echo
  	echo -e "\t   -h or -? Prints this help message."
  	echo
  	exit -1
}

function test_jmeter_existence() {

  #if [ ! -z "$JMETER_HOME" ]; then
  #  echo -e "JMETER_HOME=$JMETER_HOME"
  #  JMETER_PATH="$JMETER_HOME/bin/jmeter"
  #  return
  #fi

	for JMETER_MATCH in $(find -L . -iname jmeter | grep bin); do
		
		if [[ -f "$JMETER_MATCH" && -x "$JMETER_MATCH" ]]; then
			JMETER_PATH=$JMETER_MATCH
		fi
		
	done
	
	if [ -z "$JMETER_PATH"   ]; then
		echo
		echo "JMeter not found. Tell me where is it exporting JMETER_HOME variable."
		echo
		#echo -e "\tmy_dir/"
		#echo -e "\tmy_dir/jkm.sh"
		#echo -e "\tmy_dir/jakarta-jmeter-2.3.4/"
		#echo
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

# function run_jmeter_server() {
	
# 	echo "Running JMeter Server..."
	
# 	$JMETER_PATH -s > $TMP_FILE 
# 	exit $?

# }

function update_test_suite() {

	# No Mac, a sintaxe eh 'sed -i SUFIXO ...'
	# No Linux, a sintaxe eh 'sed -iSUFIXO ...'
	# putafaltadesacanagem

	MAC=`uname -a | grep -i darwin`
	if [ -z "$MAC" ]; then
		# Eh Mac	
		BKP_SUFFIX=".bkp-`date +%Y%m%d%H%M`"
	else
	    # Eh Linux
		BKP_SUFFIX=" .bkp-`date +%Y%m%d%H%M`"
	fi

	# Change the number of threads and ramp up settings

	sed -i$BKP_SUFFIX \
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
		 "JMeterErrors(timeout)")

  JMETER_TH_FINISHED="-1"
  i=0
  while [ $JMETER_TH_FINISHED -lt $NUM_THREADS ] && [ -n $TIME_TO_TIMEOUT ]; do

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
    # JMETER_TH_FINISHING=$(cat jmeter.log | grep -i thread | grep -i ending | wc -l | awk '{ print $1 }')
    #JMETER_TH_FINISHED=$(cat $JMETER_LOG_FILE | grep -i thread | grep -i finished | wc -l | awk '{ print $1 }')
    
    LAST_JMETER_TH_FINISHED=$JMETER_TH_FINISHED
    JMETER_TH_FINISHED=$(cat $LOG_FILE | wc -l)
    
    if [ $JMETER_TH_FINISHED -ne $LAST_JMETER_TH_FINISHED ]; then
      TIME_LAST_FINISHED=$(date +%s)
    fi

  	JMETER_TH_RATIO=0
  	if [ "$JMETER_TH_STARTED" -gt "0" ]; then 
      JMETER_TH_RATIO=$((  100*${JMETER_TH_FINISHED}/${JMETER_TH_STARTED} ))
    fi


    #JMETER_ERRORS=$(grep -i \<httpsample $LOG_FILE | grep -v rc=\"200 | grep -v rc=\"3 | wc -l)
    JMETER_ERRORS=$(grep -v 200,OK $LOG_FILE | wc -l)

    # Timeout errors
    JMETER_ERRORS_TIMEOUT=$(grep SocketTimeoutException $LOG_FILE | wc -l)
  	JMETER_ERRORS_TIMEOUT_RATIO=0
    if [ "$JMETER_ERRORS_TIMEOUT" -gt "0" ]; then 
        JMETER_ERRORS_TIMEOUT_RATIO=$((  100*${JMETER_ERRORS_TIMEOUT}/${JMETER_TH_STARTED} ))
    fi

    # No HTTP Response errors
    JMETER_ERRORS_NOHTTPRESPONSE=$(grep NoHttpResponseException $LOG_FILE | wc -l)
    JMETER_ERRORS_NOHTTPRESPONSE_RATIO=0
    if [ "$JMETER_ERRORS_NOHTTPRESPONSE" -gt "0" ]; then 
        JMETER_ERRORS_NOHTTPRESPONSE_RATIO=$((  100*${JMETER_ERRORS_NOHTTPRESPONSE}/${JMETER_TH_STARTED} ))
    fi

    # SocketException errors
    JMETER_ERRORS_SOCKET=$(grep SocketException $LOG_FILE | wc -l)
    JMETER_ERRORS_SOCKET_RATIO=0
    if [ "$JMETER_ERRORS_SOCKET" -gt "0" ]; then 
        JMETER_ERRORS_SOCKET_RATIO=$((  100*${JMETER_ERRORS_SOCKET}/${JMETER_TH_STARTED} ))
    fi

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
      #   SERVER="There's no;jkmagent.sh;listening on;$JAVA_SERVER"
      # else
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

    NOW=$(date +%s)
    (( TIME_SINCE_LAST_FINISHED = NOW - TIME_LAST_FINISHED ))
    if [ $TIME_SINCE_LAST_FINISHED -gt $TIMEOUT ]; then
      TIME_TO_TIMEOUT=true;
    fi

    sleep 5

  done


}

function process_jmeter_log() {

	# Process JMeter client result
 
  REGEX='Generate Summary Results =[ ]+([0-9]+) in[ ]+ ([0-9.,]+)s =[ ]+([0-9.,]+)\/s Avg:[ ]+([0-9]+) Min:[ ]+([0-9]+) Max:[ ]+([0-9]+) Err:[ ]+ [0-9] \(([0-9.,]+)%\)'

	NUM_SAMPLES=`cat $TEST_SUITE | grep \<HTTPSampler | wc -l`
	TOTAL_SAMPLES=$(( NUM_SAMPLES * NUM_THREADS ))
	SUMMARY_RESULTS=`grep -E "$REGEX" $TMP_FILE`
  #REGEX_COM_PONTO="Generate\ Summary\ Results\ =[\ ]+([0-9]+)[\ ]+in[\ ]+([0-9.]+)s[\ ]+=[\ ]+([0-9.]+)/s[\ ]+Avg:[\ ]+([0-9]+)[\ ]+Min:[\ ]+([0-9]+)[\ ]+Max:[\ ]+([0-9]+)[\ ]+Err:[\ ]+[0-9]+[\ ]+\(([0-9.]+)%\).*" 
  #REGEX_COM_VIRGULA="Generate\ Summary\ Results\ =[\ ]+([0-9]+)[\ ]+in[\ ]+([0-9,]+)s[\ ]+=[\ ]+([0-9,]+)/s[\ ]+Avg:[\ ]+([0-9]+)[\ ]+Min:[\ ]+([0-9]+)[\ ]+Max:[\ ]+([0-9]+)[\ ]+Err:[\ ]+[0-9]+[\ ]+\(([0-9,]+)%\).*"

	# Parse JMeter 'Generate Summary Results' listener output.
	# e.g Generate Summary Results = 10 in 1.1s = 9.5/s Avg: 133 Min: 93 Max: 165 Err: 0 (0.00%)

	# Debian requires quotes around the regex. Does it work on MacOS et. al.?  
	# if [[ "$SUMMARY_RESULTS" =~ $REGEX_COM_PONTO || "$SUMMARY_RESULTS" =~ $REGEX_COM_VIRGULA ]] 
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
	    return
	fi

	echo "---------------------------------"
	echo "           FIM DO TESTE"
	echo " veja os ultimos dados coletados"
	echo "---------------------------------"
	tail -5 $SUMMARY_FILE

}

function save_errors() {

	#grep -i \<httpsample $LOG_FILE | grep -v rc=\"200 | grep -v rc=\"3 > $ERRORS_FILE
  grep -v 200,OK $LOG_FILE > $ERRORS_FILE
	
	# [TODO] How to handle things like this?
	
	 # <httpSample t="93006" lt="93006" ts="1276713131811" s="true" lb="http://proxyerror.inep.gov.br/index.html?Time=16%2FJun%2F2010%3A15%3A32%3A01%20-0300&amp;ID=0042687649&amp;Client_IP=172.29.11.193&amp;User=-&amp;Site=172.29.9.32&amp;URI=web%2Fguest%3Bjsessionid%3D8B10290211FEC52FBC7CD7E4A6C57F39&amp;Status_Code=502&amp;Decision_Tag=ALLOW_CUSTOMCAT_1090519041-DefaultGroup-Servidores_Vips-NONE-NONE-DefaultRouting&amp;URL_Cat=Sites%20Liberados&amp;WBRS=ns&amp;DVS_Verdict=-&amp;DVS_ThreatName=-&amp;Reauth_URL=-" rc="200" rm="OK" tn="Thread Group 1-5630" dt="text" by="3950"/>
}

function backup_log_files {
  mkdir -p bkps $> /dev/null

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

	#rm jmeter.log &> /dev/null

  JMETER_CMD="$JMETER_PATH -n -t $TEST_SUITE -l $LOG_FILE"

  if [ -n "$PROXY_ADDR" ]; then
   JMETER_CMD=$JMETER_CMD" -H $PROXY_ADDR -P $PROXY_PORT"
  fi

  # if [ -n "$REMOTE_SERVERS" ]; then
  $JMETER_CMD $REMOTE_SERVERS > $TMP_FILE &
  # fi

	# if [ ! -z "$PROXY_ADDR" ]; then
	# 	$JMETER_PATH -n -t $TEST_SUITE -H $PROXY_ADDR -P $PROXY_PORT -l $LOG_FILE > $TMP_FILE &
	# else
	# 	$JMETER_PATH -n -t $TEST_SUITE -l $LOG_FILE $REMOTE_SERVERS > $TMP_FILE &
	# fi
	sleep 5 # Time before jmeter.log creation
	
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
LOG_FILE=".detailed_log.jmeter"
TMP_FILE=".summary_results.jmeter"
SERVER_FILE=".server_metrics.jmeter"
SUMMARY_FILE="reports/summary_results.csv"
TEST_REPORT="reports/tests_results.csv"
ERRORS_FILE="reports/errors.txt"
BKP_DIR="bkps" 

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

test_parameters_consistence

test_suite_existence

START_TIME=`date '+%d/%m/%Y %H:%M:%S'`

run_jmeter_client

FINISH_TIME=`date '+%d/%m/%Y %H:%M:%S'`

echo "Test started at ${START_TIME} and ended at ${FINISH_TIME}."
