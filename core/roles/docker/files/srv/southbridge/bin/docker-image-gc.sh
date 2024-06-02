#!/bin/sh
# remove only old image
# kubernetes remove old containers

LOCATION="$(cd -P -- "$(dirname -- "$0")" && pwd -P)/.."
# "

if [ -f "$LOCATION/etc/docker-gc.conf.dist" ]; then
  . "$LOCATION/etc/docker-gc.conf.dist"
  if [ -f "$LOCATION/etc/docker-gc.conf" ]; then
    . "$LOCATION/etc/docker-gc.conf"
  fi
  if [ -f "$LOCATION/etc/docker-gc.local.conf" ]; then
    . "$LOCATION/etc/docker-gc.local.conf"
  fi
else
  echo "docker-gc.conf.dist not found"
  exit 0
fi

timestamp=$(date '+%s' -d "-${DAYS} day")
logfile=$(mktemp)

docker image prune -f -a --filter until="$timestamp" 2>&1 | grep -Ev "Total reclaimed space: 0 ?B" > "$logfile"

grep 'unknown flag:' "$logfile" >/dev/null && ( docker image prune -f -a 2>&1 | grep -Ev "Total reclaimed space: 0 ?B" > "$logfile" )

cat "$logfile"
rm -f "$logfile"
