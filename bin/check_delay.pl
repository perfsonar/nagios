#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use perfSONAR_PS::ServiceChecks::Commands::NagiosDelayCmd;

my $cmd = new perfSONAR_PS::ServiceChecks::Commands::NagiosDelayCmd(
    nagios_name => 'PS_CHECK_DELAY',
    units => 'ms'
);
$cmd->run();
