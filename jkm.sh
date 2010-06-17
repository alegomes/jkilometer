#!/bin/bash

#
# Required libs:
# bc, netcat
# 

# Must be the same as in jmeteragent.sh
AGENT_PORT=8977

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
	
	for p in $(ps axu | grep -i jkm.sh | grep -v $0); do
		JKILOMETER_PID=$(echo $p | awk '{print $2}')
		echo "Killing JKilometer Script on process $JKILOMETER_PID"
		kill -9 $JKILOMETER_PID
	done
	
	exit
}

function usage() {
   echo 
   echo "Usage:  ./jkm.sh -t jmeter_script.jmx -T <num_of_threads> -r <ramp_up> -S <appserver_address> [-R ip1,ip2,ip3...] [-c comment] | -s | -h?"
   echo 
   exit -1
}

function test_jmeter_existence() {

	for JMETER_MATCH in $(find . -iname jmeter | grep bin); do
		
		if [[ -f "$JMETER_MATCH" && -x "$JMETER_MATCH" ]]; then
			JMETER_PATH=$JMETER_MATCH
		fi
		
	done
	
	if [ -z "$JMETER_PATH"   ]; then
		echo
		echo "JMeter not found. Put it in the same level as jkm.sh script."
		echo
		echo -e "\tmy_dir/"
		echo -e "\tmy_dir/jkm.sh"
		echo -e "\tmy_dir/jakarta-jmeter-2.3.4/"
		echo
		exit -1
	fi
	
}

function test_required_parameters() {

	JMETER_SERVER_PRESENT=`echo $@ | grep "\-s"`
	TEST_SUITE_PRESENT=`echo $@ | grep "\-t"`
	NUM_THREADS_PRESENT=`echo $@ | grep "\-T"`
	RAMP_UP_PRESENT=`echo $@ | grep "\-r"`
	APPSERVER_PRESENT=`echo $@ | grep "\-S"`

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
			
			if [ -z "$APPSERVER_PRESENT" ]; then
				echo "Argument missing: -S"
				usage	
			fi
			
			if [ "$#" -eq "7" ]; then
				echo "Something wrong. -c argument is missing?"
				usage
			fi
		fi
	fi
}

function run_jmeter_server() {
	
	echo "Running JMeter Server..."
	
	# TODO Parametize proxy settings and JMeter path
	#SCRIPT_PATH=$0
	# ${SCRIPT_PATH%/*}/jakarta-jmeter-2.3.4/bin/jmeter -s > $TMP_FILE
	$JMETER_PATH -s > $TMP_FILE 
	exit $?

}

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

	sed -i$BKP_SUFFIX "s/num_threads\">.*</num_threads\">${NUM_THREADS}</" $TEST_SUITE 
	sed -i$BKP_SUFFIX "s/ramp_time\">.*</ramp_time\">${RAMP_UP}</" $TEST_SUITE

}

function save_test_metrics() {

	TEST_METRICS=$1
	
  	echo -e $TEST_METRICS >> $TEST_REPORT

}

#
# Monitor JMeter client execution
#
function monitor_jmeter_execution() {

	HEADER=$(echo -e \
			 "Time," \
	         "JMeterThStarted," \
             "JMeterThFinished," \
			 "JMeterThRatio," \
			 "JMeterErrors," \
             "ServerCnx:80," \
             "ServerCnx:8080," \
			 "ServerSysLoad," \
             "ServerJVMThAll," \
             "ServerJVMThRun," \
             "ServerJVMThBlk," \
             "ServerJVMThWai," \
             "ServerJVMEden," \
             "ServerJVMOld," \
             "ServerJVMPerm")

    JMETER_TH_FINISHED="0" 
	while [ $JMETER_TH_FINISHED -lt $NUM_THREADS ]; do
  
	  NOW=`date '+%H:%M:%S'`

	  # awk removes \t from wc output
	  JMETER_TH_STARTED=$(cat jmeter.log | grep -i thread | grep -i started | wc -l | awk '{ print $1 }')
	  # JMETER_TH_FINISHING=$(cat jmeter.log | grep -i thread | grep -i ending | wc -l | awk '{ print $1 }')
	  JMETER_TH_FINISHED=$(cat jmeter.log | grep -i thread | grep -i finished | wc -l | awk '{ print $1 }')

	  JMETER_ERRORS=$(grep -i \<httpsample $LOG_FILE | grep -v rc=\"200 | grep -v rc=\"3 | wc -l)

	  if [ "$JMETER_TH_STARTED" -gt "0" ]; then 
		JMETER_TH_RATIO=$((  100*${JMETER_TH_FINISHED}/${JMETER_TH_STARTED} ))
	  fi

	  # Collects app server metrics
	  telnet $JAVA_SERVER $AGENT_PORT &> $SERVER_FILE 
	  # Exemplo: 0| 0| 0.00| 61| 9| 0| 52| 40.38| 84.87| 99.90
      SERVER=`cat $SERVER_FILE | grep \,`
	  
	  if [ -z "$SERVER" ]; then
		SERVER="There's no,jkmagent.sh,listening on,$JAVA_SERVER"
	  fi
   	  
	  line_with_header=$(echo $HEADER"\n" \
	            "${NOW}," \
	          	"${JMETER_TH_STARTED}," \
	          	"${JMETER_TH_FINISHED}," \
				"${JMETER_TH_RATIO}%," \
				"${JMETER_ERRORS}," \
				"${SERVER}")

      line_no_header=$(echo "${NOW}," \
  				 "${JMETER_TH_STARTED}," \
	          	 "${JMETER_TH_FINISHED}," \
				 "${JMETER_TH_RATIO}%," \
				 "${JMETER_ERRORS}," \
				 "${SERVER}")

	  #
	  # Imprimir ou nao imprimir o cabecalho?
	  #

	  let title=i%15
	  if [ $title -eq 0 ]; then
		
		TEST_METRICS="$line_with_header"
		
	    # With header
	    echo -e "$line_with_header" | column -t -s\, 
				
	  else 

		TEST_METRICS="$line_no_header"

	     # Without header	
		 echo -e "$line_with_header" | column -t -s\, | grep -v JMeterThStarted
	
	  fi

      save_test_metrics "$TEST_METRICS"

	  line=""

	  trap "killJKM" HUP
	  trap "killJKM" INT
	  trap "killJKM" QUIT
	  trap "killJKM" PIPE
	  trap "killJKM" TERM
	  trap "killJKM" KILL

	  sleep 5
	
  	  (( i = i + 1 ))
	done

}

function process_jmeter_log() {

	# Process JMeter client result
 
	NUM_SAMPLES=`cat $TEST_SUITE | grep \<HTTPSampler | wc -l`
	TOTAL_SAMPLES=$(( NUM_SAMPLES * NUM_THREADS ))
	SUMMARY_RESULTS=`grep "$TOTAL_SAMPLES in" $TMP_FILE`

	# Parse JMeter 'Generate Summary Results' listener output.
	# e.g Generate Summary Results = 10 in 1.1s = 9.5/s Avg: 133 Min: 93 Max: 165 Err: 0 (0.00%)

	if [[ "$SUMMARY_RESULTS" =~ Generate\ Summary\ Results\ =[\ ]+([0-9]+)[\ ]+in[\ ]+([0-9.]+)s[\ ]+=[\ ]+([0-9.]+)/s[\ ]+Avg:[\ ]+([0-9]+)[\ ]+Min:[\ ]+([0-9]+)[\ ]+Max:[\ ]+([0-9]+)[\ ]+Err:[\ ]+[0-9]+[\ ]+\(([0-9.]+)%\).* ]] 
	then 

		if [[ ! -z $COMMENT ]]; then
		   	echo "#" 			>> $SUMMARY_FILE
			echo "# $COMMENT" 	>> $SUMMARY_FILE 
			echo "#"  			>> $SUMMARY_FILE
			echo $HEADER   		>> $SUMMARY_FILE
		fi
		
		echo "${START_TIME},${BASH_REMATCH[1]},${RAMP_UP},${BASH_REMATCH[2]},${BASH_REMATCH[3]},${BASH_REMATCH[4]},${BASH_REMATCH[5]},${BASH_REMATCH[6]},${BASH_REMATCH[7]}"  >> $SUMMARY_FILE
	else
	    echo "Resultado do JMeter nao corresponde ao esperado! "
	    echo "-->${SUMMARY_RESULTS}<--"
	    exit -1
	fi

	echo "---------------------------------"
	echo "           FIM DO TESTE"
	echo " veja os ultimos dados coletados"
	echo "---------------------------------"
	tail -5 $SUMMARY_FILE

}

function save_errors() {

	grep -i \<httpsample $LOG_FILE | grep -v rc=\"200 | grep -v rc=\"3 > $ERRORS_FILE
	
	# [TODO] How to handle things like this?
	
	 # <httpSample t="93006" lt="93006" ts="1276713131811" s="true" lb="http://proxyerror.inep.gov.br/index.html?Time=16%2FJun%2F2010%3A15%3A32%3A01%20-0300&amp;ID=0042687649&amp;Client_IP=172.29.11.193&amp;User=-&amp;Site=172.29.9.32&amp;URI=web%2Fguest%3Bjsessionid%3D8B10290211FEC52FBC7CD7E4A6C57F39&amp;Status_Code=502&amp;Decision_Tag=ALLOW_CUSTOMCAT_1090519041-DefaultGroup-Servidores_Vips-NONE-NONE-DefaultRouting&amp;URL_Cat=Sites%20Liberados&amp;WBRS=ns&amp;DVS_Verdict=-&amp;DVS_ThreatName=-&amp;Reauth_URL=-" rc="200" rm="OK" tn="Thread Group 1-5630" dt="text" by="3950"/>
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

	rm jmeter.log &> /dev/null

	# TODO Parametize proxy settings
	#SCRIPT_PATH=$0
	$JMETER_PATH -n -t $TEST_SUITE -H proxy.inep.gov.br -P 8080 -l $LOG_FILE > $TMP_FILE &
	sleep 3 # Time before jmeter.log creation
	
	init_test_report
	
	monitor_jmeter_execution

	process_jmeter_log
	
	save_errors
	
	exit $?

}

# ---------------------------------------------------------
# Script starts here
# ---------------------------------------------------------

test_jmeter_existence

test_required_parameters $@

# Avoiding 'Too Many Open Files'. Increase this value if you still get the error.
ulimit -n 8192

# Files to be used

LOG_FILE=".detailed_log.jmeter"
TMP_FILE=".summary_results.jmeter"
SERVER_FILE=".server_metrics.jmeter"
SUMMARY_FILE="reports/summary_results.csv"
TEST_REPORT="reports/tests_results.csv"
ERRORS_FILE="reports/errors.txt"
HEADER="Samples,RampUp,Time,Throughput,Avg,Min,Max,Err,MaxCnxHTTP,MaxCnxTomcat,MaxSysLoad,"

rm $LOG_FILE &> /dev/null

if [[ ! -e reports ]]; then mkdir -v reports; fi
	
# Check passed arguments

while getopts "t:T:r:R:c:S:sh?" OPT; do
  case "$OPT" in
      "t") TEST_SUITE="$OPTARG" ;;
 	  "T") NUM_THREADS="$OPTARG" ;;
      "r") RAMP_UP="$OPTARG" ;;
      "R") JMETER_ARGS="-R $OPTARG" ;;
	  "c") COMMENT="$OPTARG" ;;
	  "S") JAVA_SERVER="$OPTARG" ;;
	  "s") run_jmeter_server ;;
      "h") usage;;
      "?") usage;;
  esac
done

test_suite_existence

START_TIME=`date '+%d/%m/%Y %H:%M:%S'`

run_jmeter_client

FINISH_TIME=`date '+%d/%m/%Y %H:%M:%S'`

echo "Test started at ${START_TIME} and ended at ${FINISH_TIME}."
