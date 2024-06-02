#!/bin/bash
#
# script for saving current pstree for each running docker container


readonly TMP_DIR='/tmp/docker-pstree.tmp'
if [[ ! -d "${TMP_DIR}" ]]; then
  mkdir "${TMP_DIR}"
else
  if [[ -d "${TMP_DIR}.old" ]]; then
    rm -r "${TMP_DIR}.old"
  fi
  mv "${TMP_DIR}"{,.old}
  mkdir "${TMP_DIR}"
fi

for cid in $(docker ps -q); do
    cpid=$(docker inspect -f '{{.State.Pid}}' "${cid}")

    if [[ -d "/proc/${cpid}" ]]; then
	pstree -Ucp "${cpid}" > "${TMP_DIR}/${cid}"
    fi
done
