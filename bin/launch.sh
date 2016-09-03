#!/bin/sh

# Copyright 2014 RethinkDB.
# Portions from Frank Trampe and Novell used with permission.
# Modified for snapd by Mark Shuttleworth, Canonical

# This looks in $SNAP_COMMON/config/ for rethinkdb config files and launches,
# stops, or examines each instance described there.


set -e -u
umask 022

itask="${1:-}"

rtdbbin=$SNAP/bin/rethinkdb ;
rtdbconfigdir=$SNAP_COMMON/config ;

# parse a line from the config file
conf_read_line () {
    local _val="${1#*=}"
    local _key="${1%%=*}"
    if [ "$_val" = "$1" ]; then
        unset -v $2
        unset -v $3
        false
    else
        read -r $2 <<EOF
`echo $_key`
EOF
        read -r $3 <<EOF
${_val# }
EOF
    fi
}

# conf_read <file> <var>
# read the config file file into the variable var
conf_read () {
    local _dict="#"
    local line sect key val
    while read -r full_line; do
        line=${full_line%%#*}
        if conf_read_line "$line" key val; then
            _dict="$_dict$key=$val#"
        elif [ "`echo -n $line`" != "" ]; then
            # ignore parse errors
            true
        fi
    done < $1 && read -r $2 <<EOF
$_dict
EOF
}

# get <conf> <key> [var]
# extract the value of key from the parsed config conf
# into the variable var or if var is not passed, into the variable key
get () {
    local _valp="${1#*#$2=}"
    local _val="${_valp%%#*}"
    if [ "$_valp" = "$1" ]; then
        unset -v ${3:-$2}
        return 1
    else
        read -r ${3:-$2} <<EOF
$_val
EOF
    fi
}

default_ports_available=true

default_driver_port=28015
default_cluster_port=29015
default_http_port=28080
default_port_offset=0

# is_running <pid>
# test if the process exists
is_running () {
    ps -p "$1" > /dev/null
}

usage_fail () {
    echo "Usage: rethinkdb-launch.sh [start|stop|restart|force-restart|status]"
    exit 1
}

case "$itask" in
    start|stop|restart|force-restart|status)
        true
        ;;
    "")
        usage_fail
        ;;
    *)
        echo "$0: error: unknown action $1"
        usage_fail
        ;;
esac

# We make our top-level config directories
if [ ! -e "$rtdbconfigdir" ]; then
  if mkdir -p "$rtdbconfigdir"; then
    # chown "rethinkdb:rethinkdb" "$rtdbconfigdir"
    echo "rethinkdb: Created $rtdbconfigdir"
  fi
fi
if [ ! -e "$SNAP_COMMON/data" ]; then
  if mkdir -p "$SNAP_COMMON/data"; then
    # chown "rethinkdb:rethinkdb" "$SNAP_COMMON/data"
    echo "rethinkdb: Created $SNAP_COMMON/data"
  fi
fi
if [ ! -e "$SNAP_COMMON/run" ]; then
  if mkdir -p "$SNAP_COMMON/run"; then
    # chown "rethinkdb:rethinkdb" "$SNAP_COMMON/run"
    echo "rethinkdb: Created $SNAP_COMMON/run"
  fi
fi

# We check for active configurations .
if ! ls "$rtdbconfigdir"/*.conf >/dev/null 2>/dev/null ; then
    echo "rethinkdb: No instances defined in $rtdbconfigdir/<instance>.conf"
    echo "rethinkdb: Creating default instance..."
    echo "driver-port=$default_driver_port" > "$rtdbconfigdir/default.conf"
    echo "cluster-port=$default_cluster_port" >> "$rtdbconfigdir/default.conf"
    echo "http-port=$default_http_port" >> "$rtdbconfigdir/default.conf"
    echo "port-offset=$default_port_offset" >> "$rtdbconfigdir/default.conf"
    echo "rethinkdb: See http://www.rethinkdb.com/docs/guides/startup/ for more information" ;
fi

for rtdbconffile in "$rtdbconfigdir"/*.conf ;
do
    if ! conf_read "$rtdbconffile" conf; then
        continue
    fi

    instance_name=`basename "$rtdbconffile" .conf`

    # $@ will contain the options we pass to rethinkdb
    set --
    set -- --config-file "$rtdbconffile"

    if get "$conf" runuser; then
        echo "rethinkdb: Skipping $instance_name, please remove runuser from config."
        continue
    fi
    if get "$conf" rungroup; then
        echo "rethinkdb: Skipping $instance_name, please remove rungroup from config."
        continue
    fi

    # The rethinkdb snap requires pid files to be in $SNAP_COMMON and
    # disallows setting them in the config file. make sure the parent folder has the correct permissions
    if ! get "$conf" pid-file rtdbpidfile; then
        rtdbpidfile="$SNAP_COMMON/run/$instance_name.pid"
    else
        echo "rethinkdb: Skipping $instance_name, please remove pid-file from config."
        continue
    fi
    parent_directory="`dirname "$rtdbpidfile"`"
    if [ ! -e "$parent_directory" ]; then
      if mkdir -p "$parent_directory"; then
        # chown "rethinkdb:rethinkdb" "$parent_directory"
        echo "rethinkdb: Created $parent_directory"
      fi
    fi

    set -- "$@" --pid-file "$rtdbpidfile"

    # The rethinkdb snap requires the database files to be in $SNAP_DATA and
    # disallows setting them in the config file.
    if ! get "$conf" directory rtdb_directory; then
        rtdb_directory="$SNAP_COMMON/data/$instance_name"
        if [ ! -e "$rtdb_directory" ]; then
            if mkdir -p "$rtdb_directory"; then
                # chown "rethinkdb:rethinkdb" "$rtdb_directory"
                echo "rethinkdb: Created $rtdb_directory"
            fi
        fi
        set -- "$@" --directory "$rtdb_directory"
    else
        echo "rethinkdb: Skipping $instance_name, please remove 'directory' from config."
        continue
    fi

    # Only one of the instances can use the default ports
    get "$conf" driver-port driver_port || :
    get "$conf" cluster-port cluster_port || :
    get "$conf" http-port http_port || :
    get "$conf" port-offset port_offset || :
    port_offset=${port_offset:-0}
    if [ "${driver_port:-$((default_driver_port+port_offset))}" = "$default_driver_port" -o \
         "${cluster_port:-$((default_cluster_port+port_offset))}" = "$default_cluster_port" -o \
         "${http-port:-$((default_http_port+port_offset))}" = "$default_http_port" ]; then
        if $default_ports_available; then
            default_ports_available=false
        else
            echo "rethinkdb: $instance_name: error: the default ports are already used by another instance"
            echo "rethinkdb: $instance_name: error: please use non-default values for driver-port, cluster-port and http-port in $rtdbconffile"
            continue
        fi
    fi

    if [ "$itask" = "stop" -o "$itask" = "restart" -o "$itask" = "force-restart" ] ; then
        # stop rethinkdb

        if [ ! -e "$rtdbpidfile" ] ; then
            echo "rethinkdb: $instance_name: The instance is not running (there is no pid file)"
        elif is_running "`cat "$rtdbpidfile"`" ; then
            echo -n "rethinkdb: $instance_name: Waiting for instance to stop (pid `cat "$rtdbpidfile"`) ..."
            instance_pid=`cat "$rtdbpidfile"`
            kill -INT "$instance_pid"
            while is_running "$instance_pid"; do
                echo -n "."
                sleep 1
            done
            echo " Stopped."
        else
            rm -f "$rtdbpidfile"
        fi
    fi

    if [ "$itask" = "start" -o "$itask" = "restart" -o "$itask" = "force-restart" ] ; then
        # start rethinkdb

        if ! get "$conf" bind x; then
            echo "rethinkdb: $instance_name: will only listen on local network interfaces."
            echo "rethinkdb: $instance_name: to expose rethinkdb on the network, add 'bind=all' to $rtdbconffile"
        fi

        if [ -e "$rtdbpidfile" ] && is_running "$(cat "$rtdbpidfile")"; then
            echo "rethinkdb: $instance_name: already started!"
        else
            if [ -e "$rtdbpidfile" ] ; then
                rm "$rtdbpidfile"
            fi
            if ! get "$conf" log-file rtdblogfile; then
                rtdblogfile=$rtdb_directory/log_file
            else
              # The snap of rethinkdb expects the log file to be in
              # $SNAP_COMMON and disallows setting it in config
              echo "rethinkdb: Skipping $instance_name, please remove 'log-file' from config."
              continue
            fi
            echo "rethinkdb: $instance_name: Started, logging to \`$rtdblogfile'"
            "$rtdbbin" --daemon "$@"
        fi
    fi

    if [ "$itask" = "status" ] ; then
        # show the rethinkdb status

        if [ -e "$rtdbpidfile" ] ; then
            if ! is_running "$(cat "$rtdbpidfile")"; then
                echo "rethinkdb: $instance_name: stop/crashed"
            else
                echo "rethinkdb: $instance_name: start/running, pid `cat "$rtdbpidfile"`"
            fi
        else
            echo "rethinkdb: $instance_name: stop/waiting"
        fi
    fi
done
