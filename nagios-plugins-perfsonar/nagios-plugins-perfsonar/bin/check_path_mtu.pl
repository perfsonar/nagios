#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCmd;

my $cmd = new perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCmd(
    event_type => 'path-mtu',
    nagios_name => 'PS_CHECK_PATH_MTU',
    metric_name => 'path MTU',
    units => 'bytes',
    unit_prefix => ' ',
    default_digits => 0
);
$cmd->run();
