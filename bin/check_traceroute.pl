#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use Nagios::Plugin;
use perfSONAR_PS::ServiceChecks::TracerouteCheck;
use perfSONAR_PS::ServiceChecks::Parameters::CheckParameters;

my $np = Nagios::Plugin->new( shortname => 'PS_CHECK_TRACEROUTE',
                              usage => "Usage: %s -u|--url <service-url> -s|--source <source-addr> -d|--destination <dest-addr> -r <number-seconds-in-past> -w|--warning <threshold> -c|--critical <threshold> -t|--timeout <timeout>",
                              timeout => 60);

#get arguments
$np->add_arg(spec => "u|url=s",
             help => "URL of the MA service to contact",
             required => 1 );
$np->add_arg(spec => "s|source=s",
             help => "Source of the test to check",
             required => 0 );
$np->add_arg(spec => "d|destination=s",
             help => "Destination of the test to check",
             required => 0 );
$np->add_arg(spec => "r|range=i",
             help => "Time range (in seconds) in the past to look at data. i.e. 60 means look at last 60 seconds of data.",
             required => 1 );
$np->add_arg(spec => "w|warning=s",
             help => "threshold of path count that leads to WARNING status",
             required => 1 );
$np->add_arg(spec => "c|critical=s",
             help => "threshold of path count that leads to CRITICAL status",
             required => 1 );
$np->getopts;                              

#create client
my $ma_url = $np->opts->{'u'};

#call client
my $checker = new perfSONAR_PS::ServiceChecks::TracerouteCheck();
my $parameters = new perfSONAR_PS::ServiceChecks::Parameters::CheckParameters(
    'ma_url' => $ma_url,
    'source' => $np->opts->{'s'},
    'destination' => $np->opts->{'d'},
    'time_range' => $np->opts->{'r'},
    'timeout' => $np->opts->{'timeout'},
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
    my $errMsg = "No traceroute data returned";
    $np->nagios_die($errMsg);
}

# format nagios output
$np->add_perfdata(
        label => 'PathCountMin',
        value => $stats->min(),
    );
$np->add_perfdata(
        label => 'PathCountMax',
        value => $stats->max(),
    );
$np->add_perfdata(
        label => 'PathCountAverage',
        value => $stats->mean(),
    );
$np->add_perfdata(
        label => 'PathCountStdDev',
        value => ($stats->standard_deviation() ? $stats->standard_deviation() : 0),
    );
    
my $code = $np->check_threshold(
     check => $stats->max(),
     warning => $np->opts->{'w'},
     critical => $np->opts->{'c'},
   );

my $msg = "";   
if($code eq OK || $code eq WARNING || $code eq CRITICAL){
    $msg = "Maximum number of paths is " . $stats->max();
}else{
    $msg = "Error analyzing results";
}
$np->nagios_exit($code, $msg);
