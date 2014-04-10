#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use Cache::Memcached;
use Nagios::Plugin;
use Statistics::Descriptive;
use perfSONAR_PS::ServiceChecks::OWDelayCheck;
use perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters;

use constant DELAY_LABEL => 'ms';
use constant DELAY_FIELD => 'min_delay';
use constant DELAY_SCALE => 1000;
use constant DELAY_STRING => 'Minimum delay';
use constant LOSS_LABEL => 'pps';
use constant LOSS_LABEL_LONG => ' packets per session';
use constant LOSS_PERCENT_LABEL => '%';
use constant LOSS_FIELD => 'loss';
use constant LOSS_SCALE => 1;
use constant LOSS_STRING => 'Loss';
use constant DEFAULT_DIGITS => 3;
use constant DEFAULT_MEMD_ADDR => '127.0.0.1:11211';
use constant DEFAULT_MEMD_EXP => 300;
use constant DEFAULT_MEMD_COMPRESS_THRESH => 1000000;

my $np = Nagios::Plugin->new( shortname => 'PS_CHECK_OWDELAY',
                              timeout => 60,
                              usage => "Usage: %s -u|--url <service-url> -s|--source <source-addr> -d|--destination <dest-addr> -b|--bidirectional -l|--loss -p|--percentage --digits <significant-digits> -r <number-seconds-in-past> -w|--warning <threshold> -c|--critical <threshold> -t|timeout <timeout> -m|memcached <server> -e|memcachedexp <expiretime>" );

#get arguments
$np->add_arg(spec => "u|url=s",
             help => "URL of the lookup service to contact",
             required => 1 );
$np->add_arg(spec => "s|source=s",
             help => "Source of the test to check",
             required => 0 );
$np->add_arg(spec => "d|destination=s",
             help => "Destination of the test to check",
             required => 0 );
$np->add_arg(spec => "b|bidirectional",
             help => "Indicates that test should be checked in each direction.",
             required => 0 );
$np->add_arg(spec => "l|loss",
             help => "Look at packet loss instead of delay.",
             required => 0 );
$np->add_arg(spec => "p|percentage",
             help => "Express loss as percentage in output and input parameters are interpreted as percentage.",
             required => 0 );
$np->add_arg(spec => "r|range=i",
             help => "Time range (in seconds) in the past to look at data. i.e. 60 means look at last 60 seconds of data.",
             required => 1 );
$np->add_arg(spec => "digits=i",
             help => "Sets the number of significant digits reported after the decimal in results. Must be greater than 0. Defaults to 3.",
             required => 0 );
$np->add_arg(spec => "w|warning=s",
             help => "threshold of delay (" . DELAY_LABEL . ") that leads to WARNING status. In loss mode this is average packets lost as an number. If -p is specified in addition to -l, then number must be 0-100 (inclusive) and will be interpreted as a percentage.",
             required => 1 );
$np->add_arg(spec => "c|critical=s",
             help => "threshold of delay (" . DELAY_LABEL . ") that leads to CRITICAL status. In loss mode this is average packets lost as an integer. If -p is specified in addition to -l, then number must be 0-100 (inclusive) and will be interpreted as a percentage.",
             required => 1 );
$np->add_arg(spec => "m|memcached=s",
             help => "Address of server in form <address>:<port> where memcached runs. Set to 'none' if want to disable memcached. Defaults to 127.0.0.1:11211",
             required => 0 );
$np->add_arg(spec => "e|memcachedexp=s",
             help => "Time when you want memcached data to expire in seconds. Defaults to lesser of 5 minutes and -r option if not set.",
             required => 0 );
$np->getopts;                              

#create client
my $ma_url = $np->opts->{'u'};
my $memd_addr = $np->opts->{'m'};
if(!$memd_addr){
    $memd_addr = DEFAULT_MEMD_ADDR;
}
my $memd  = q{};
if(lc($memd_addr) ne 'none' ){
    $memd  = new Cache::Memcached {
        'servers' => [ $memd_addr ],
        'debug' => 0,
        'compress_threshold' => DEFAULT_MEMD_COMPRESS_THRESH,
    };
}
my $memd_expire_time = $np->opts->{'e'};
if(!$memd_expire_time){
    $memd_expire_time = DEFAULT_MEMD_EXP;
    if($np->opts->{'r'} < $memd_expire_time){
        $memd_expire_time = $np->opts->{'r'};
    }
}

#set metric
my $metric = DELAY_FIELD;
my $metric_label = DELAY_LABEL;
my $metric_label_long = DELAY_LABEL;
my $metric_scale = DELAY_SCALE;
my $metric_string = DELAY_STRING;
if($np->opts->{'l'}){
    $metric = LOSS_FIELD;
    $metric_label = ($np->opts->{'p'} ? LOSS_PERCENT_LABEL : LOSS_LABEL);
    $metric_label_long = ($np->opts->{'p'} ? LOSS_PERCENT_LABEL : LOSS_LABEL_LONG);
    $metric_scale = LOSS_SCALE;
    $metric_string = LOSS_STRING;
}

#call client
my $checker = new perfSONAR_PS::ServiceChecks::OWDelayCheck(memd => $memd, memd_expire_time => $memd_expire_time);
my $parameters = new perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters(
    'ma_url' => $ma_url,
    'source' => $np->opts->{'s'},
    'destination' => $np->opts->{'d'},
    'time_range' => $np->opts->{'r'},
    'bidirectional' => $np->opts->{'b'},
    'timeout' => $np->opts->{'timeout'},
    'metric' => $metric,
    'as_percentage' => $np->opts->{'p'},
);
my ($result, $stats);
eval{
    ($result, $stats) = $checker->do_check($parameters);
};
if($@){
    $np->nagios_die("Error with underlying check: " . $@);
}elsif($result){
    $np->nagios_die($result);
}elsif($stats->count() == 0 ){
    my $errMsg = "No one-way delay data returned";
    $errMsg .= " for direction where" if($np->opts->{'s'} || $np->opts->{'d'});
    $errMsg .= " src=" . $np->opts->{'s'} if($np->opts->{'s'});
    $errMsg .= " dst=" . $np->opts->{'d'} if($np->opts->{'d'});
    $np->nagios_die($errMsg);
}

# format nagios output
my $digits = DEFAULT_DIGITS;
if(defined $np->opts->{'digits'} && $np->opts->{'digits'} ne '' && $np->opts->{'digits'} >= 0){
    $digits = $np->opts->{'digits'};
}

$np->add_perfdata(
        label => 'Count',
        value => $stats->count(),
    );
$np->add_perfdata(
        label => 'Min',
        value => $stats->min() * $metric_scale . $metric_label,
    );
$np->add_perfdata(
        label => 'Max',
        value => $stats->max() * $metric_scale . $metric_label,
    );
$np->add_perfdata(
        label => 'Average',
        value => $stats->mean() * $metric_scale . $metric_label,
    );
$np->add_perfdata(
        label => 'Standard_Deviation',
        value => $stats->standard_deviation() * $metric_scale . $metric_label,
    );

my $code = $np->check_threshold(
     check => $stats->mean() * $metric_scale,
     warning => $np->opts->{'w'},
     critical => $np->opts->{'c'},
   );

my $msg = "";   
if($code eq OK || $code eq WARNING || $code eq CRITICAL){
    $msg = "$metric_string is " . sprintf("%.${digits}f", ($stats->mean() * $metric_scale)) . $metric_label_long;
}else{
    $msg = "Error analyzing results";
}
$np->nagios_exit($code, $msg);
