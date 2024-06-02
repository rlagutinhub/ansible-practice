#!/bin/sh

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

docker container prune -f --filter until="$timestamp" | grep -Ev "Total reclaimed space: 0 ?B"
docker image prune -f -a --filter until="$timestamp" | grep -Ev "Total reclaimed space: 0 ?B"
