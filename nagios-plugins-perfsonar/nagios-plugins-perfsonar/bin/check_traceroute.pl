#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use perfSONAR_PS::ServiceChecks::Commands::NagiosTracerouteCmd;

my $cmd = new perfSONAR_PS::ServiceChecks::Commands::NagiosTracerouteCmd(
    nagios_name => 'PS_CHECK_TRACEROUTE',
    metric_name => 'number of paths',
);
$cmd->run();
