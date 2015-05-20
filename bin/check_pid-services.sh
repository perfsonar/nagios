#!/bin/bash
##############################################
#Simple Nagios checks on services
# author: Ivan Garnizov 03.2015
#
# compatible with 'regular_testing', 'ls_cache_daemon'
##############################################

NO_ARGS=1
EXIT_UNKNOWN=3
EXIT_CRITICAL=2
EXIT_WARNING=1
EXIT_OK=0


if [ $# -lt "$NO_ARGS" ]
then
  echo "Usage: `basename $0` -s <servicename>"
  exit $EXIT_UNKNOWN
fi

while getopts ":s:" Option
do
  case $Option in
    s     ) svc=$OPTARG;;
    *     ) echo "Unimplemented option chosen."; exit $EXIT_UNKNOWN;
  esac
done

stat=`/bin/cat /var/run/$svc.pid`
code=$?
if [[ $code -gt 0 ]]; then
  exit $EXIT_CRITICAL
fi

stat=`/bin/ps -p $stat`
code=$?

if [[ $code -gt 0 ]]; then
  exit $EXIT_CRITICAL
fi
exit $EXIT_OK
