#!/bin/bash

# Require seq 

function usage() {
	echo
	echo "./jkmcycle.sh -C <number_of_cycles> -s <sleep_time_between_tests> <same_args_as_jkm.sh>"
	echo 
	echo "   e.g. "
	echo "           Z:\> ./jkmcycle.sh -C 3 -s 00:02:00 -t portal.jmx -T 100 -r 1 -S 172.20.1.29"
	echo "   where"
	echo "           test suite = portal.jmx"
	echo "           number of threads = 100"
	echo "           ramp up = 1 sec"
	echo "           java server to collect data from = 172.20.1.29.3"
	echo "           repeat it 3 times"
	echo "           wait 2 seconds between each test"
	echo
	exit 1
}

function countdown {
  OLD_IFS=${IFS}
  IFS=":"
  local ARR=( $1 )
  local SECONDS=$(( (ARR[0]*60*60) + (ARR[1]*60) + (ARR[2]) ))
  local START=$(date +%s)
  local END=$((START + SECONDS))
  local CUR=$START

  while [[ $CUR -lt $END ]]; do
    CUR=$(date +%s)
    LEFT=$((END-CUR))
    
    printf "\r%02d:%02d:%02d" $((LEFT/3600)) $(( (LEFT/60)%60)) $((LEFT%60))
    sleep 1
  done
  
  IFS="${OLD_IFS}"
  echo "         "
}


#############################################

if [ "$#" -lt "2" ]; then	
	usage;
fi

while getopts "C:s:t:T:r:R:c:H:P:S:h?" OPT; do
  case "$OPT" in
      "C") CYCLES="$OPTARG" ;;
      "s") SLEEP="$OPTARG" ;;
      "t") TEST_SUITE="$OPTARG" ;;
 	  "T") NUM_THREADS="$OPTARG" ;;
      "r") RAMP_UP="$OPTARG" ;;
      "R") JMETER_ARGS="-R $OPTARG" ;;
	  "c") COMMENT="$OPTARG" ;;
	  "H") PROXY_ADDR="$OPTARG" ;;
	  "P") PROXY_PORT="$OPTARG" ;;
	  "S") JAVA_SERVER="$OPTARG" ;;
      "h") usage;;
      "?") usage;;
  esac
done

sudo ./jkm.sh $@
[ "$?" != "0" ] && exit 1

for i in `seq $CYCLES`; do
	echo "Wait. Server relaxing..."; countdown $SLEEP
	sudo ./jkm.sh -t $TEST -T $THREADS -r $RAMP -R $JMETER_ARGS -H $PROXY_ADDR -P $PROXY_PORT -S $JAVA_SERVER
	[ "$?" != "0" ] && exit 1
done