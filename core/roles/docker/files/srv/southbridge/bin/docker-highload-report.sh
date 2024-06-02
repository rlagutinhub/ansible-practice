#!/bin/bash

readonly PATH="/sbin:/usr/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/local/bin"

RRUN=$(pgrep -c docker-highload-report)
RRUN=0$RRUN
if [ "$RRUN" -gt 2 ]; then
  echo "Highload Report alredy running"
  exit
fi

STAMP=$(date +%Y%m%d%H%M)
LOGFILE=/tmp/docker-highload_${STAMP}.tmp
FLAGD=$(date +%s)
REPORT=""

if [ -f /tmp/highload-report.flag ]; then
  FLAGL=$(head -1 /tmp/highload-report.flag)
  CNTL=$(tail -1 /tmp/highload-report.flag)
  DELTA=$((FLAGD-FLAGL))
  if [ "$DELTA" -gt 280 ] && [ "$CNTL" -eq 1 ]; then
    echo "$FLAGD" > /tmp/highload-report.flag
    echo 5 >> /tmp/highload-report.flag
    REPORT="5"
    DELTA=0
  fi
  if [ "$DELTA" -gt 280 ] && [ "$CNTL" -ne 10 ]; then
    echo "$FLAGD" > /tmp/highload-report.flag
    echo 10 >> /tmp/highload-report.flag
    REPORT="10"
    DELTA=0
  fi
  if [ "$DELTA" -gt 1180 ]; then
    echo "$FLAGD" > /tmp/highload-report.flag
    echo 1 >> /tmp/highload-report.flag
    REPORT="100"
  fi
else
  echo "$FLAGD" > /tmp/highload-report.flag
  echo 1 >> /tmp/highload-report.flag
  REPORT="1"
fi

# shellcheck disable=SC2129
{
    echo "ADDSUBJSTRING High LA"
    echo "##HighLoad report from $(hostname -f) $MYIP"
} >> "$LOGFILE"

echo "###Tail /var/log/monit" >> "$LOGFILE"
echo "~~~" >> "$LOGFILE"
/usr/bin/tail -20 /var/log/monit >> "$LOGFILE" 2>&1
echo "~~~" >> "$LOGFILE"

echo "###Load average" >> "$LOGFILE"
echo "~~~" >> "$LOGFILE"
top -b | head -5 >> "$LOGFILE" 2>&1
echo "~~~" >> "$LOGFILE"

echo "###Memory process list (top100)" >> "$LOGFILE"
echo "~~~" >> "$LOGFILE"
ps -ewwwo pid,size,state,command --sort -size | head -100 | awk '{ pid=$1 ; printf("%7s ", pid) }{ hr=$2/1024 ; printf("%8.2f Mb ", hr) } { for ( x=3 ; x<=NF ; x++ ) { printf("%s ",$x) } print "" }' >> "$LOGFILE" 2>&1
echo "~~~" >> "$LOGFILE"

echo "###CPU process list (top100)" >> "$LOGFILE"
echo "~~~" >> "$LOGFILE"
ps -ewwwo pcpu,pid,user,state,command --sort -pcpu | head -100 >> "$LOGFILE" 2>&1
echo "~~~" >> "$LOGFILE"

echo "###Connections report (top10)" >> "$LOGFILE"
echo "~~~" >> "$LOGFILE"
if [ -x /usr/sbin/ss ]; then
  ss -nat | grep -E -v "Local|Active" |  awk '{print $4,$5,$1}' |  sed 's/:[0-9a-z]*//2' | sort | uniq -c | sort -n | tail -15 | column -t >> "$LOGFILE" 2>&1
else
  netstat -nat | grep -E -v "Local|Active" | awk '{print $4,$5,$6}' |  sed 's/:[0-9]*//2' | sort | uniq -c | sort -n | tail -15 | column -t >> "$LOGFILE" 2>&1
fi
{
    echo "~~~"
    echo "###Syn tcp/udp session"
    echo "~~~"
} >> "$LOGFILE"
if [ -x /usr/sbin/ss ]; then
    echo $(( $(ss -t4 state syn-recv | wc -l) + $(ss -t4 state syn-sent | wc -l) )) >> "$LOGFILE" 2>&1
else
    netstat -n | grep -E '(tcp|udp)' | grep -c SYN >> "$LOGFILE" 2>&1
fi
echo "~~~" >> "$LOGFILE"

if $(command -v docker) -v >/dev/null 2>&1 && systemctl status docker >/dev/null 2>&1; then
{
    echo "###Docker containers (running)"
    echo "~~~"
    docker ps
    echo "~~~"
} >> "${LOGFILE}"

    ftmp=$(mktemp)
    ( docker stats --no-stream --format 'table {{.Container}}\t{{.CPUPerc}}\t{{.MemPerc}}\t{{.MemUsage}}\t{{.BlockIO}}\t{{.PIDs}}' )>"${ftmp}" 2>&1 &   # run some program in subshell
    cPID=$!                              # get PID of subshell
    sleep 2
    timeout=35
    status=0
    if [[ ${timeout} -gt 0 ]]; then
	# shellcheck disable=SC2009
      while [[ $( ps | grep -o -G "^${cPID}"; ) -eq ${cPID} && ${status} -eq 0 ]]; do
        status=$((timeout-- ? 0 : 1)); sleep 1
      done
    fi
    if [[ ${status} -eq 1 ]]; then
      eval 'kill -9 ${cPID}' &>/dev/null;  # If timeout occured - kill child process
      {
	  echo "###Docker stats (common)"
	  echo "~~~"
	  echo "Timeout occured...."
	  echo "~~~"
      } >> "${LOGFILE}"
    else
      docker_stats=$(cat "$ftmp")
      header=$(echo "${docker_stats}" | head -n1)
      stats=$(echo "${docker_stats}" | tail -n+2)

      # top_cpu=$(echo "${stats}" | sort -rgk2)
      # top_mem=$(echo "${stats}" | sort -rgk3)
      # top_io=$(echo "${stats}" | sort -h -k5)

      {
	  echo "###Docker stats (common)"
	  echo "~~~"
	  echo "${header}"
	  echo "${stats}"
	  echo "~~~"
      } >> "${LOGFILE}"
    fi
    rm -f "$ftmp"
fi

SUBJECT="$(hostname) HighLoad report"

if [ -n "$REPORT" ]; then
cat - "${LOGFILE}" <<EOF | sendmail -oi -t
To: root
Subject: ${SUBJECT}
Content-Type: text/html; charset=utf8
Content-Transfer-Encoding: 8bit
MIME-Version: 1.0

EOF

fi

# Delete old HighLoad Report
find /tmp -maxdepth 1 -type f -name 'docker-highload_*.tmp' -mtime +5 -delete
