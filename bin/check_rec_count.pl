#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use perfSONAR_PS::ServiceChecks::Commands::NagiosRecCountCmd;

my $cmd = new perfSONAR_PS::ServiceChecks::Commands::NagiosRecCountCmd(
    nagios_name => 'PS_CHECK_ESMOND_REC_COUNT',
    metric_name => 'number of records',
    units => ' record(s)',
    metric_scale => 1
);
$cmd->run();
