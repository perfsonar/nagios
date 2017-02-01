#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCmd;

my $cmd = new perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCmd(
    event_type => 'packet-count-lost-bidir',
    nagios_name => 'PS_CHECK_PING_LOSS',
    metric_name => 'loss',
    units => 'packets',
    unit_prefix => ' ',
    default_digits => 0
);
$cmd->run();
