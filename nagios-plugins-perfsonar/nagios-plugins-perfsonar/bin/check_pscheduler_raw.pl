#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCountCmd;

my $cmd = new perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCountCmd(
    event_type => 'pscheduler-raw',
    nagios_name => 'PS_PSCHEDULER_RAW',
    metric_name => 'number of results',
    units => '',
    unit_prefix => ' ',
    default_digits => 0
);
$cmd->run();
