#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use perfSONAR_PS::ServiceChecks::Commands::NagiosRTTCmd;

my $cmd = new perfSONAR_PS::ServiceChecks::Commands::NagiosRTTCmd(
    nagios_name => 'PS_CHECK_RTT',
    units => 'ms'
);
$cmd->run();
