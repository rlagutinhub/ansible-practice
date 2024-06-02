#!/bin/bash
#
# try to figure out whether oom-killed'ed process was a child of docker container or not

readonly DOCKER_PSTREE_DIRS='/tmp/docker-pstree.tmp /tmp/docker-pstree.tmp.old'
echo
echo "Will search for docker child pids in ${DOCKER_PSTREE_DIRS}"

readonly LOGFILE='/var/log/messages'
if [[ ! -f "${LOGFILE}" ]]; then
  echo
  echo "Cant read logfile: ${LOGFILE}"
  echo "Nothing to do"
  exit
fi

readonly STAMP=$(date +%Y%m%d%H%M)
readonly OUTFILE=/tmp/docker-oom_${STAMP}.tmp

readonly PROCESSED_PIDS_FILE='/tmp/docker-oom-processed-pids'
if [[ ! -f "${PROCESSED_PIDS_FILE}" ]]; then
  touch "${PROCESSED_PIDS_FILE}"
fi

SUBJECT="$(hostname) Docker OOM-killer report"

#
# -- mail report about oom killer --
# -- per process basis
#
function mail_report() {
cat - ${OUTFILE} << EOF | sendmail -oi -t
To: root
Subject: ${SUBJECT}
Content-Type: text/html; charset=utf8
Content-Transfer-Encoding: 8bit
MIME-Version: 1.0

EOF

return $?
}
# --


for pp in $(grep -n 'out of memory' "${LOGFILE}" | sed -r s/^\([0-9]\+\):.*.out.of.memory..Kill.process.\([0-9]\+\)..\([a-zA-Z0-9_.-]\+\).*/\\1:\\2:\\3/g); do
  line=$(echo "${pp}" | cut -d ':' -f1)
  pid=$(echo "${pp}" | cut -d ':' -f2)
  cmd=$(echo "${pp}" | cut -d ':' -f3)
  for d in ${DOCKER_PSTREE_DIRS}; do
    if [[ ! -d ${d} ]]; then
      echo
      echo "Cant search for {cmd}(pid). No such directory: ${d}"
      echo "/srv/southbridge/bin/docker-pstree.sh should fill this directory"
      continue
    fi
    cd "${d}"
    for cid in $(grep -sRHE "\{?${cmd}\}?\(${pid}\)" | cut -d ':' -f1); do
      if grep -sq "${pid}:${cmd}" "${PROCESSED_PIDS_FILE}"; then
        echo
        echo "${cmd}(${pid}) is already processed"
        continue
      fi
      echo "###Docker container" >> "${OUTFILE}"
      echo "~~~" >> "${OUTFILE}"
      echo "${cmd}(${pid}) found within container ${cid}" >> "${OUTFILE}"
      echo "~~~" >> "${OUTFILE}"
      
      echo "###Stack trace" >> "${OUTFILE}"
      echo "~~~" >> "${OUTFILE}"
      sed -n "$[${line}-40],${line}p" "${LOGFILE}" | sed -n "/${cmd} invoked oom-killer/,+40p" >> "${OUTFILE}"
      echo "~~~" >> "${OUTFILE}"

      echo "###Docker inspect" >> "${OUTFILE}"
      echo "~~~" >> "${OUTFILE}"
      docker inspect ${cid} >> "${OUTFILE}" 2>&1
      echo "~~~" >> "${OUTFILE}"

      echo "###Docker container logs" >> "${OUTFILE}"
      echo "~~~" >> "${OUTFILE}"
      docker logs --tail 100 ${cid} >> "${OUTFILE}" 2>&1
      echo "~~~" >> "${OUTFILE}"

      if mail_report; then
        echo "${pid}:${cmd}" >> "${PROCESSED_PIDS_FILE}"
      fi
    done
    cd - > /dev/null
  done
done

# Delete old OOM reports
find /tmp -maxdepth 1 -type f -name 'docker-oom_*.tmp' -mtime +5 -delete
