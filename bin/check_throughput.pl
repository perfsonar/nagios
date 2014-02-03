#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use Cache::Memcached;
use Nagios::Plugin;
use Statistics::Descriptive;
use perfSONAR_PS::Client::MA;
use perfSONAR_PS::ServiceChecks::ThroughputCheck;

use constant BW_SCALE => 10e8;
use constant BW_LABEL => 'Gbps';
use constant DEFAULT_DIGITS => 3;
use constant DEFAULT_MEMD_ADDR => '127.0.0.1:11211';
use constant DEFAULT_MEMD_EXP => 300;
use constant DEFAULT_MEMD_COMPRESS_THRESH => 1000000;

my $np = Nagios::Plugin->new( shortname => 'PS_CHECK_THROUGHPUT',
                              timeout => 60,
                              usage => "Usage: %s -u|--url <service-url> -s|--source <source-addr> -d|--destination <dest-addr> -b|--bidirectional -r <number-seconds-in-past> -w|--warning <threshold> -c|--critical <threshold> -v|--verbose -p|--protocol <protocol> --t|timeout <timeout> --digits <significant-digits> -m|memcached <server> -e|memcachedexp <expiretime>" );

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
$np->add_arg(spec => "digits=i",
             help => "Sets the number of significant digits reported after the decimal in results. Must be greater than 0. Defaults to 3.",
             required => 0 );
$np->add_arg(spec => "w|warning=s",
             help => "threshold of bandwidth (in " . BW_LABEL . ") that leads to WARNING status",
             required => 1 );
$np->add_arg(spec => "c|critical=s",
             help => "threshold of bandwidth (in " . BW_LABEL . ") that leads to CRITICAL status",
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
my $stats = Statistics::Descriptive::Sparse->new();
my $checker = new perfSONAR_PS::ServiceChecks::ThroughputCheck;
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

#call client
my $result = $checker->doCheck($ma_url, $np->opts->{'s'}, $np->opts->{'d'}, $np->opts->{'r'}, $np->opts->{'b'}, $np->opts->{'p'}, $stats, $np->opts->{'timeout'}, $memd, $memd_expire_time );
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
my $digits = DEFAULT_DIGITS;
if(defined $np->opts->{'digits'} && $np->opts->{'digits'} ne '' && $np->opts->{'digits'} >= 0){
    $digits = $np->opts->{'digits'};
}

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
    $msg = "Average throughput is " . sprintf("%.${digits}f", $stats->mean()/BW_SCALE) . BW_LABEL;
}else{
    $msg = "Error analyzing results";
}
$np->nagios_exit($code, $msg);
