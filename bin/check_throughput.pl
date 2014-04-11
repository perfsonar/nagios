#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use perfSONAR_PS::ServiceChecks::Commands::NagiosThroughputCmd;

my $cmd = new perfSONAR_PS::ServiceChecks::Commands::NagiosThroughputCmd(
    nagios_name => 'PS_CHECK_THROUGHPUT',
    units => 'Gbps',
    metric_scale => 1.0/10e8
);
$cmd->run();
