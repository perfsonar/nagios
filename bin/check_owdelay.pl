#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use perfSONAR_PS::ServiceChecks::Commands::NagiosOwdelayCmd;

my $cmd = new perfSONAR_PS::ServiceChecks::Commands::NagiosOwdelayCmd(
    nagios_name => 'PS_CHECK_OWDELAY',
);
$cmd->run();
