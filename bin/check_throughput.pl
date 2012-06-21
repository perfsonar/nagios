#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use Nagios::Plugin;
use Statistics::Descriptive;
use perfSONAR_PS::Client::MA;
use perfSONAR_PS::ServiceChecks::ThroughputCheck;

use constant BW_SCALE => 10e8;
use constant BW_LABEL => 'Gbps';

my $np = Nagios::Plugin->new( shortname => 'PS_CHECK_THROUGHPUT',
                              timeout => 60,
                              usage => "Usage: %s -u|--url <service-url> -s|--source <source-addr> -d|--destination <dest-addr> -b|--bidirectional -r <number-seconds-in-past> -w|--warning <threshold> -c|--critical <threshold> -v|--verbose -p|--protocol <protocol> --t|timeout <timeout>" );

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
$np->add_arg(spec => "p|protocol=s",
             help => "The protocol used by the test to check (e.g. TCP or UDP)",
             required => 0 );
$np->add_arg(spec => "b|bidirectional",
             help => "Indicates that test should be checked in each direction.",
             required => 0 );
$np->add_arg(spec => "r|range=i",
             help => "Time range (in seconds) in the past to look at data. i.e. 60 means look at last 60 seconds of data.",
             required => 1 );
$np->add_arg(spec => "w|warning=s",
             help => "threshold of bandwidth (in " . BW_LABEL . ") that leads to WARNING status",
             required => 1 );
$np->add_arg(spec => "c|critical=s",
             help => "threshold of bandwidth (in " . BW_LABEL . ") that leads to CRITICAL status",
             required => 1 );
$np->getopts;                              

#create client
my $ma_url = $np->opts->{'u'};
my $ma = new perfSONAR_PS::Client::MA( { instance => $ma_url, alarm_disabled => 1 } );
my $stats = Statistics::Descriptive::Sparse->new();
my $checker = new perfSONAR_PS::ServiceChecks::ThroughputCheck;

#call client
my $result = $checker->doCheck($ma, $np->opts->{'s'}, $np->opts->{'d'}, $np->opts->{'r'}, $np->opts->{'b'}, $np->opts->{'p'}, $stats, $np->opts->{'timeout'});
if($result){
    $np->nagios_die($result);
}

my $srcToDstResults = $stats->count();
if($stats->count() == 0 ){
    my $errMsg = "No throughput data returned";
    $errMsg .= " for direction where" if($np->opts->{'s'} || $np->opts->{'d'});
    $errMsg .= " src=" . $np->opts->{'s'} if($np->opts->{'s'});
    $errMsg .= " dst=" . $np->opts->{'d'} if($np->opts->{'d'});
    $np->nagios_die($errMsg);
}

# format nagios output
$np->add_perfdata(
        label => 'Count',
        value => $stats->count(),
    );
    
#Note: adding variable for each stat to avoid unitialized value errors
my $min = $stats->min();
if(!(defined $min && $min)){
    $min = 0;
}
$np->add_perfdata(
        label => 'Min',
        value => $min/BW_SCALE . BW_LABEL,
    );
    
my $max = $stats->max();
if(!(defined $max && $max)){
    $max = 0;
}
$np->add_perfdata(
        label => 'Max',
        value => $max/BW_SCALE . BW_LABEL,
    );
    
my $mean = $stats->mean();
if(!(defined $mean && $mean)){
    $mean = 0;
}
$np->add_perfdata(
        label => 'Average',
        value => $mean/BW_SCALE . BW_LABEL,
    );
    
my $stddev = $stats->standard_deviation();
if(!(defined $stddev && $stddev)){
    $stddev = 0;
}
$np->add_perfdata(
        label => 'Standard_Deviation',
        value => $stddev/BW_SCALE . BW_LABEL,
    );

my $code = $np->check_threshold(
     check => $stats->mean()/BW_SCALE,
     warning => $np->opts->{'w'},
     critical => $np->opts->{'c'},
   );

my $msg = "";   
if($code eq OK || $code eq WARNING || $code eq CRITICAL){
    $msg = "Average throughput is " . $stats->mean()/BW_SCALE . BW_LABEL;
}else{
    $msg = "Error analyzing results";
}
$np->nagios_exit($code, $msg);
