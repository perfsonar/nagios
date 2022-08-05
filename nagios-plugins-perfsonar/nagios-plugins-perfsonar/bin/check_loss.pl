#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCmd;

my $cmd = new perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCmd(
    event_type => 'packet-loss-rate',
    nagios_name => 'PS_CHECK_LOSS',
    metric_name => 'packet loss',
    units => '%',
    metric_scale => '100',
);
$cmd->run();
