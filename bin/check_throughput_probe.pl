#!/usr/bin/perl -w

use strict;
use warnings;

our $VERSION = 3.3;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use English qw( -no_match_vars );
use Getopt::Long;
use Sys::Hostname;
use perfSONAR_PS::ServiceChecks::ThroughputCheck;
use perfSONAR_PS::Utils::ParameterValidation;

use constant BW_SCALE => 10e8;
use constant BW_LABEL => 'Gbps';
my $DEFAULT_METRIC = "net.perfsonar.service.ma.throughput";
my %RSV_API_VALUE = ( 'metricType' => "status", 'serviceType' => "perfsonar-MA", 'metricName' => $DEFAULT_METRIC, 'serviceVersion' => ">= 3.1", 'probeVersion' => $VERSION );

#HARDCODED THRESHOLDS
#TODO: MAKE THESE CONFIGURABLE?
my $DEFAULT_VO = 'USATLAS';
my $DEFAULT_TIME_RANGE = 86400; #1 day
my $DEFAULT_WARNING_BW = .1; #100Mbps
my $DEFAULT_CRTICAL_BW = .01; #10Mbps
my $DEFAULT_CHECK_BIDIRECTIONAL = 0;

#get cli options
my %opts = ();
my $ok = GetOptions(
    'h|help'     => \$opts{HELP},
    'l|list'     => \$opts{LIST},
    'm|metric=s' => \$opts{METRIC},
    'u|uri=s'    => \$opts{URL},
    'wlcg'       => \$opts{RSV_WLCG}
);
my $RSV_BRIEF = 1;

if ( defined $opts{HELP} or not defined $opts{URL} or not $ok ) {
    print printHelp();
    exit 1;
}

#get timestanp
my $timestamp = &getTimestamp();

#parse metric for source and destination
my $src = q{};
my $dst = q{};
if ($opts{METRIC} =~ /^$DEFAULT_METRIC\.([A-Za-z0-9_\-]+)\.([A-Za-z0-9_\-]+)$/) {
    $src = $1;
    $dst = $2;
    $src =~ s/_/\./g;
    $dst =~ s/_/\./g;
    $RSV_API_VALUE{'metricName'} = $opts{METRIC};
}elsif (defined $opts{METRIC} && $opts{METRIC} ne 'all' && $opts{METRIC} ne $DEFAULT_METRIC ) {
    print printList();
    exit 1;
}

if ( defined $opts{RSV_WLCG} ) {
    $RSV_BRIEF = 0;
}

#create client

my $ma_url = $opts{URL};
my $ma = new perfSONAR_PS::Client::MA( { instance => $ma_url } );
my $stats = Statistics::Descriptive::Sparse->new();
my $checker = new perfSONAR_PS::ServiceChecks::ThroughputCheck;

#call client
my $result = $checker->doCheck($ma, $src, $dst, $DEFAULT_TIME_RANGE, $DEFAULT_CHECK_BIDIRECTIONAL, '', $stats);

if($result){
    print printRSVBrief( metricStatus => "UNKNOWN" , summaryData => "Error retrieving data", detailsData => $result );
    exit 0;
}

#Check thresholds
my $status = q{};
my $summary = q{};
my $details = q{};

my $avg_throughput = $stats->mean()/BW_SCALE;
if ($avg_throughput < $DEFAULT_CRTICAL_BW) {
    $status = 'CRITICAL';
    $summary = "Average throughput below the critical threshold at " . $avg_throughput . BW_LABEL;
} elsif ($avg_throughput < $DEFAULT_WARNING_BW) {
    $status = 'WARNING';
    $summary = "Average throughput below the warning threshold at " . $avg_throughput . BW_LABEL;
} else {
    $status = 'OK';
    $summary = "Average throughput above thresholds at " . $avg_throughput . BW_LABEL;
}
$details = "Probe found " . $stats->count() . " test(s) with";
$details .= " min=" . $stats->min()/BW_SCALE . BW_LABEL if($stats->min());
$details .= " mean=" . $stats->mean()/BW_SCALE . BW_LABEL if($stats->mean());
$details .= " max=" . $stats->max()/BW_SCALE . BW_LABEL if($stats->max());
$details .= " stddev=" . $stats->standard_deviation()/BW_SCALE . BW_LABEL if($stats->standard_deviation());

#output
if($RSV_BRIEF){
    print printRSVBrief( metricStatus => $status , summaryData => $summary, detailsData => $details );
}else{
    print printRSVWLCG( metricStatus => $status , summaryData => $summary, voName => $DEFAULT_VO, serviceURI => $ma_url, timestamp => $timestamp, detailsData => $details );
}

=head2 printHelp()

Print Help Dialog  

=cut
sub printHelp {
    my $msg = "\ncheck_throughput_probe\n";
    $msg .= "probeVersion: " . $RSV_API_VALUE{probeVersion} . "\n";
    $msg .= "serviceType: " . $RSV_API_VALUE{serviceType} . "\n";
    $msg .= "serviceVersion: " . $RSV_API_VALUE{serviceVersion} . "\n\n";
    $msg .= "Probe for functional checking operational status of the";
    $msg .= " perfSONAR-PS Lookup Service.  Works with NAGIOS and RSV\n\n";
    $msg .= "Usage: $PROGRAM_NAME\n";
    $msg .= "    -u, --uri SERVICEURI\n";
    $msg .= "        Service URI. Accepted URIs are:\n";
    $msg .= "            host:port/service\n";
    $msg .= "    -m, --metric STRING\n";
    $msg .= "        Which metric to perform.\n";
    $msg .= "    -l\n";
    $msg .= "        Print WLCG-style metric list\n";
    $msg .= "    -h, --help\n";
    $msg .= "        Print help message\n";
    $msg .= "    --wlcg\n";
    $msg .= "        Output in the historic \"WLCG\" RSV format\n";
    return $msg;
}

=head2 printList()

Print list of metrics

=cut

sub printList {
    my $msg = "serviceType: " . $RSV_API_VALUE{serviceType} . "\n";
    $msg .= "metricName: " . $RSV_API_VALUE{metricName} . "\n";
    $msg .= "metricType: " . $RSV_API_VALUE{metricType} . "\n";
    $msg .= "EOT\n";
    return $msg;
}

=head2 printRSVBrief()

Print RSV (Brief) formated data.  

=cut

sub printRSVBrief {
    my ( @args ) = @_;
    my $parameters = validateParams( @args, { metricStatus => 1, summaryData => 1, detailsData => 1 } );

    my $msg = "RSV BRIEF RESULTS:\n";
    $msg .= $parameters->{metricStatus} . "\n";
    $msg .= $parameters->{summaryData} . "\n";
    $msg .= $parameters->{detailsData} . "\n";
    return $msg;
}

=head2 printRSVWLCG()

Print RSV (WLCG) formated data.  

=cut

sub printRSVWLCG {
    my ( @args ) = @_;
    my $parameters = validateParams( @args, { metricStatus => 1, summaryData => 1, voName => 0, serviceURI => 1, timestamp => 1, detailsData => 1 } );

    my $msg = "metricType: " . $RSV_API_VALUE{metricType} . "\n";
    $msg .= "serviceType: " . $RSV_API_VALUE{serviceType} . "\n";
    $msg .= "metricName: " . $RSV_API_VALUE{metricName} . "\n";
    $msg .= "metricStatus: " . $parameters->{metricStatus} . "\n";
    $msg .= "summaryData: " . $parameters->{summaryData} . "\n";
    $msg .= "voName: " . $parameters->{voName} . "\n" if $parameters->{voName};
    $msg .= "serviceURI: " . $parameters->{serviceURI} . "\n";
    $msg .= "gatheredAt: " . hostname . "\n";
    $msg .= "timestamp: " . $parameters->{timestamp} . "\n";
    $msg .= "serviceVersion: " . $RSV_API_VALUE{serviceVersion} . "\n";
    $msg .= "probeVersion: " . $RSV_API_VALUE{probeVersion} . "\n";
    $msg .= "detailsData: " . $parameters->{detailsData} . "\n" if $parameters->{detailsData};
    $msg .= "EOT\n";
    return $msg;
}

=head2 printRSVWLCG()

Return RSV (WLCG) formated timestamp.  

=cut
sub getTimestamp {
    # Grab a timestamp as the script starts
    my ( $sec, $min, $hour, $day, $month, $year ) = ( gmtime( time ) )[ 0, 1, 2, 3, 4, 5, 6 ];
    $year  += 1900;
    $month += 1;
    return sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ", $year, $month, $day, $hour, $min, $sec;
}
