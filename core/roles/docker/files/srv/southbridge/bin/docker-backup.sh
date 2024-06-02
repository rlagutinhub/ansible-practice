#!/bin/bash
#
# Backup Script for service in docker container

LOCATION="$(cd -P -- "$(dirname -- "$0")" && pwd -P)/.."
# "
VER=0.1 # Version Number
LOGFILE=$BACKUPDIR/$DBHOST-`date +%N`.log # Logfile Name
LOGERR=$BACKUPDIR/ERRORS_$DBHOST-`date +%N`.log # Logfile Name

if [ -f "$LOCATION/etc/docker-backup.conf.dist" ]; then
    . "$LOCATION/etc/docker-backup.conf.dist"
    if [ -f "$LOCATION/etc/docker-backup.conf" ]; then
        . "$LOCATION/etc/docker-backup.conf"
    fi
    if [ -f "$LOCATION/etc/docker-backup.local.conf" ]; then
        . "$LOCATION/etc/docker-backup.local.conf"
    fi
else
    echo "docker-backup.conf.dist not found"
    exit 0
fi

if [ "x$docker_backup" != "xyes" ]; then
  exit 0
fi

if /sbin/pidof -x $(basename $0) > /dev/null; then
  for p in $(/sbin/pidof -x $(basename $0)); do
    if [ $p -ne $$ ]; then
      ALERT=${HN}$'\n'"Script $0 is already running: exiting"
      echo "$ALERT" | mail -s "ERRORS REPORTED: DockerContainers Backup error log $HN" root
      exit
    fi
  done
fi


data_backup() {
  local type=$1
  local container=$2
  local warning=1
  if [ "$SHOW_WARNING" == "yes" ]; then
    for mount_point in `/usr/bin/docker inspect --format='{{range .Mounts}} {{.Destination}} {{end}}' $container`; do
      if [ "$mount_point" == "/var/backups/$type" ]; then
        warning=0
      fi
    done
  else
    warning=0
  fi
  if [ $warning -ne 0 ]; then
    echo "~~~" >&2
    echo "WARNING [$type backup] Backup catalog /var/backups/$type not mount outside container" >&2
  fi
  local tmplog=`mktemp`
  docker exec $container $type-backup.sh >$tmplog 2>&1
  status=$?
  if [ $status -ne 0 ]; then
    echo "~~~" >&2
    echo "ERROR [$type backup]" >&2
    cat $tmplog >&2
  else
    cat $tmplog
  fi
  rm -f "$tmplog"
}

service_backup() {
  local type=$1
  local container=$2
  local backup=${type}_backup
  local exclude=${type}_exclude_containers
  if [ "${!backup}" = "yes" ]; then
    if [[ ! ${!exclude} =~ \ $container\  ]]; then
      data_backup $type $container
    else
      echo "Container $container exclude from $type backup"
    fi
  else
    echo "$type backup disable"
  fi
}

# IO redirection for logging.
touch $LOGFILE
exec 6>&1 # Link file descriptor #6 with stdout.
# Saves stdout.
exec > $LOGFILE # stdout replaced with file $LOGFILE.

touch $LOGERR
exec 7>&2 # Link file descriptor #7 with stderr.
# Saves stderr.
exec 2> $LOGERR # stderr replaced with file $LOGERR.

# When a desire is to receive log via e-mail then we close stdout and stderr.
[ "x$MAILCONTENT" == "xlog" ] && exec 6>&- 7>&-

for service_item in $SERVICE_LIST; do
  service_port=${service_item%:*}
  service_name=${service_item#*:}
  tmp_=${service_name}_containers
  service_containers=" "${!tmp_}" "
  tmp_=${service_name}_exclude_containers
  service_exclude_containers=" "${!tmp_}" "

  echo "###"
  echo "Backup log for: $service_name"
  echo "###"
  echo

  # backup containers autodetect
  if [ "$AUTODETECT" = "yes" ]; then
    for d in `/usr/bin/docker ps --format '{{ .Names }}'`; do
      port_i=0
      exposed_port='-'
      for exposed_port in `/usr/bin/docker inspect --format='{{range $p, $conf := .Config.ExposedPorts}} {{$p}} {{end}}' $d`; do
        if [ "$exposed_port" == "$service_port" ]; then
          service_containers=${service_containers# $d }
          echo "###"
          echo "AUTODETECT CONTAINER: $service_name $d"
          echo
          service_backup $service_name $d
        fi
      done
    done
  fi
  # backup containers from list
  for d in $service_containers; do
    echo "###"
    echo "LISTED CONTAINER: $service_name $d"
    echo
    service_backup $service_name $d
  done
done

# Clean up IO redirection if we plan not to deliver log via e-mail.
[ ! "x$MAILCONTENT" == "xlog" ] && exec 1>&6 2>&7 6>&- 7>&-

if [ "$MAILCONTENT" = "log" ]
    then
    cat "$LOGFILE" | mail -s "Mongo Backup Log for $HOST - $DATE" $MAILADDR
    if [ -s "$LOGERR" ]; then
            cat "$LOGERR"
            (cat "$LOGERR";echo "stdout log:" ; cat "$LOGFILE") | mail -s "ERRORS REPORTED: DockerContainers Backup error Log for $HOST - $DATE" $MAILADDR
    fi

elif [ "$MAILCONTENT" = "quiet" ]
    then
    if [ -s "$LOGERR" ]
    then
        (cat "$LOGERR";echo "stdout log:" ; cat "$LOGFILE") | mail -s "ERRORS REPORTED: DockerContainers Backup error Log for $HOST - $DATE" $MAILADDR
        cat "$LOGFILE" | mail -s "DockerContainers Backup Log for $HOST - $DATE" $MAILADDR
    fi
else
    if [ -s "$LOGERR" ]
        then
        cat "$LOGFILE"
        echo
        echo "###### WARNING ######"
        echo "STDERR written to during mongodump execution."
        echo "The backup probably succeeded, as docker-backup sometimes writes to STDERR, but you may wish to scan the error log below:"
        cat "$LOGERR"
    else
        cat "$LOGFILE"
    fi
fi

STATUS=0
if [ -s "$LOGERR" ]; then
  STATUS=1
fi

# Clean up Logfile
eval rm -f "$LOGFILE"
eval rm -f "$LOGERR"
