#!/bin/bash
##############################################
#Simple Nagios checks on services
# author: Ivan Garnizov 03.2015
#
# compatible with 'oppd', 'postgresql', 'cassandra', 'httpd', 'ls_registration_daemon'
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

stat=`service $svc status`
code=$?
#echo "your exit code is $code"

if [[ $code -gt 0 ]]; then
  exit $EXIT_CRITICAL
fi

#stat="not running"
res=`expr match "$stat" '.*\(not running\.*\)'`

if [[ $res = "" ]]; then
  res=`expr match "$stat" '.*\( running\.*\)'`
  if [[ $res = "" ]]; then
    exit $EXIT_CRITICAL
  else
    exit $EXIT_OK
  fi
fi

exit $EXIT_CRITICAL
