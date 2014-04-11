#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCmd;

my $cmd = new perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCmd(
    event_type => 'packet-retransmits',
    nagios_name => 'PS_CHECK_RETRANSMITS',
    metric_name => 'retransmits',
    units => 'packets',
    unit_prefix => ' '
);
$cmd->run();
