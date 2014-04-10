#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use Cache::Memcached;
use Nagios::Plugin;
use Statistics::Descriptive;
use perfSONAR_PS::ServiceChecks::DelayCheck;
use perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters;

use constant DELAY_LABEL => 'ms';
use constant DELAY_FIELD => 'min_delay';
use constant DELAY_SCALE => 1;
use constant DELAY_STRING => {
    'min_delay' => 'minimum delay',
    'max_delay' => 'maximum delay',
    'median_delay' => 'median delay',
    'mean_delay' => 'mean delay',
    'p25_delay' => '25th percentile of delay',
    'p75_delay' => '75th percentile of delay',
    'p95_delay' => '95th percentile of delay',
};
use constant DEFAULT_DIGITS => 3;

my $np = Nagios::Plugin->new( shortname => 'PS_CHECK_OWDELAY',
                              timeout => 60,
                              usage => "Usage: %s -u|--url <service-url> -s|--source <source-addr> -d|--destination <dest-addr> -b|--bidirectional --digits <significant-digits> -r <number-seconds-in-past> -w|--warning <threshold> -c|--critical <threshold> -t|timeout <timeout> -q|quantile <quantile>" );

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
$np->add_arg(spec => "r|range=i",
             help => "Time range (in seconds) in the past to look at data. i.e. 60 means look at last 60 seconds of data.",
             required => 1 );
$np->add_arg(spec => "q|quantile=s",
             help => "The delay metric to analyze. Valid values are min, max, median, p25, p75 and p95. Default is min.",
             required => 0 );
$np->add_arg(spec => "digits=i",
             help => "Sets the number of significant digits reported after the decimal in results. Must be greater than 0. Defaults to 3.",
             required => 0 );
$np->add_arg(spec => "w|warning=s",
             help => "threshold of delay (" . DELAY_LABEL . ") that leads to WARNING status. In loss mode this is average packets lost as an number. If -p is specified in addition to -l, then number must be 0-100 (inclusive) and will be interpreted as a percentage.",
             required => 1 );
$np->add_arg(spec => "c|critical=s",
             help => "threshold of delay (" . DELAY_LABEL . ") that leads to CRITICAL status. In loss mode this is average packets lost as an integer. If -p is specified in addition to -l, then number must be 0-100 (inclusive) and will be interpreted as a percentage.",
             required => 1 );
$np->getopts;                              

#create client
my $ma_url = $np->opts->{'u'};

#set metric
my $metric = DELAY_FIELD;
if($np->opts->{'q'}){
    $metric = $np->opts->{'q'} . '_delay';
}
my $metric_string = DELAY_STRING->{$metric};
unless($metric_string){
     $np->nagios_die("Unknown metric " . $metric);
}
my $metric_label = DELAY_LABEL;
my $metric_label_long = DELAY_LABEL;
my $metric_scale = DELAY_SCALE;


#call client
my $checker = new perfSONAR_PS::ServiceChecks::DelayCheck();
my $parameters = new perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters(
    'ma_url' => $ma_url,
    'source' => $np->opts->{'s'},
    'destination' => $np->opts->{'d'},
    'time_range' => $np->opts->{'r'},
    'bidirectional' => $np->opts->{'b'},
    'timeout' => $np->opts->{'timeout'},
    'metric' => $metric
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
    my $errMsg = "No delay data returned";
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
    $msg = "Average $metric_string is " . sprintf("%.${digits}f", ($stats->mean() * $metric_scale)) . $metric_label_long;
}else{
    $msg = "Error analyzing results";
}
$np->nagios_exit($code, $msg);
