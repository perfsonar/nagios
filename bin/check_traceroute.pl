#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use Socket;
use Nagios::Plugin;
use Data::Validate::IP qw(is_ipv4 is_ipv6);
use Statistics::Descriptive;
use perfSONAR_PS::Common qw( find findvalue );
use perfSONAR_PS::Client::MA;
use XML::LibXML;

use constant HAS_METADATA => 1;
use constant HAS_DATA => 2;

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
my $ma = new perfSONAR_PS::Client::MA( { instance => $ma_url, alarm_disabled => 1 } );
my $pathStats = Statistics::Descriptive::Sparse->new();
my $testStats = Statistics::Descriptive::Sparse->new();

#call client
&send_data_request($ma, $np->opts->{'s'}, $np->opts->{'d'}, $np->opts->{'r'}, $pathStats, $testStats,  $np->opts->{'timeout'});
if($pathStats->count() == 0 ){
    my $errMsg = "No traceroute data returned";
    $np->nagios_die($errMsg);
}

# format nagios output
$np->add_perfdata(
        label => 'PathCountMin',
        value => $pathStats->min(),
    );
$np->add_perfdata(
        label => 'PathCountMax',
        value => $pathStats->max(),
    );
$np->add_perfdata(
        label => 'PathCountAverage',
        value => $pathStats->mean(),
    );
$np->add_perfdata(
        label => 'PathCountStdDev',
        value => ($pathStats->standard_deviation() ? $pathStats->standard_deviation() : 0),
    );
$np->add_perfdata(
        label => 'TestCount',
        value => $testStats->count(),
    );
$np->add_perfdata(
        label => 'TestNumTimesRunMin',
        value => $testStats->min(),
    );
$np->add_perfdata(
        label => 'TestNumTimesRunMax',
        value => $testStats->max(),
    );
$np->add_perfdata(
        label => 'TestNumTimesRunAverage',
        value => $testStats->mean(),
    );
$np->add_perfdata(
        label => 'TestNumTimesRunStdDev',
        value => ($testStats->standard_deviation() ? $testStats->standard_deviation() : 0),
    );
    
my $code = $np->check_threshold(
     check => $pathStats->max(),
     warning => $np->opts->{'w'},
     critical => $np->opts->{'c'},
   );

my $msg = "";   
if($code eq OK || $code eq WARNING || $code eq CRITICAL){
    $msg = "Maximum number of paths is " . $pathStats->max();
}else{
    $msg = "Error analyzing results";
}
$np->nagios_exit($code, $msg);


#### SUBROUTINES
sub send_data_request() {
    my ($ma, $src, $dst, $time_int, $pathStats, $testStats, $timeout) = @_;
    my %endpoint_addrs = ();
    $endpoint_addrs{"src"} = &get_ip_and_host($src) if($src);
    $endpoint_addrs{"dst"} = &get_ip_and_host($dst) if($dst);
    
    # Define subject
    my $subject = "<trace:subject xmlns:trace=\"http://ggf.org/ns/nmwg/tools/traceroute/2.0\" id=\"subject\">\n";
    $subject .= "      <nmwgt:endPointPair xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\"/>\n";
    $subject .=   "</trace:subject>\n";
    
    # Set eventType
    my @eventTypes = ("http://ggf.org/ns/nmwg/tools/traceroute/2.0");
    
    my $endTime = time;
    my $startTime = $endTime - $time_int;
    my $result = q{};
    eval{
        local $SIG{ALRM} = sub {  $np->nagios_exit( UNKNOWN, "Timeout occurred while trying to contact MA"); };
        alarm $timeout;
        $result = $ma->setupDataRequest(
                {
                    start      => $startTime,
                    end        => $endTime,
                    subject    => $subject,
                    eventTypes => \@eventTypes
                }
            ) or $np->nagios_exit(UNKNOWN, "Unable to contact MA. Please check that the MA is running and the URL is correct." );
        alarm 0;
    };    
    # Create parser
    my $parser = XML::LibXML->new();

    #determine which endpoints we care about
    my $endpointToCheck = "";
    if($src){
        $endpointToCheck = "src";
    }elsif($dst){
        $endpointToCheck = "dst";
    }
    # parse metadata and determine which tests have matching endpoints
    my %excludedTests = ();    
    my %mdIdMap = ();
    my %mdEndpointMap = ();
    my %pathTracker = ();
    foreach my $md (@{$result->{"metadata"}}) {
        my $mdDoc;
        eval { $mdDoc = $parser->parse_string($md); };  
        if($@){
            $np->nagios_exit( UNKNOWN, "Error parsing metadata in MA response" . $@ );
        }
         #initialize data structure for tracking paths
        my $mdId = find($mdDoc->getDocumentElement, "./\@id");
        if(!$mdId){ 
            next;
        }
        $pathTracker{$mdId} = ();
        $pathTracker{$mdId}{testCount} = 0;
        
        #remove results with wrong endpoints
        if($src && $dst){
            &check_exclude_two_endpoints($mdDoc, \%endpoint_addrs, \%excludedTests);
        }elsif($src || $dst){
            &check_exclude_one_endpoint( $mdDoc, \%endpoint_addrs, $endpointToCheck, \%excludedTests);
        }
    }

    #parse data
    foreach my $data ( @{$result->{data}} ){
        my $doc;
        eval { $doc = $parser->parse_string( $data ); };  
        if($@){
            $np->nagios_die( "Error parsing data in MA response" . $@ );
        }
        
        my $mdIdRef = find($doc->getDocumentElement, "./\@metadataIdRef");
        if(!$mdIdRef){ 
            next;
        }
        
        #skip tests without matching endpoints
        if($excludedTests{"$mdIdRef"}){
            #make sure we don't track excluded tests
            if(exists $pathTracker{$mdIdRef}){
                delete $pathTracker{$mdIdRef};
            }
            next;
        }
        
        my $hops = find($doc->getDocumentElement, "./*[local-name()='datum']", 0);
        if( !defined $hops){
            $np->nagios_die( "Error extracting hops from MA response" );
        }
       
        #determine if we have an error as indicated by text in the datum element
        unless( @{$hops} > 0 && $hops->[0] && defined $hops->[0]->getAttribute("ttl")) {
            next;
        }
 
        my $hopKey = "";
        my %hopSortMap = ();
        foreach my $hopElem (sort {$a->getAttribute("ttl") <=> $b->getAttribute("ttl")} @{$hops}){
            $hopKey .= $hopElem->getAttribute("hop");
        }
        $pathTracker{$mdIdRef}{$hopKey} = 1;
        $pathTracker{$mdIdRef}{testCount}++;
        
        #my $hop_count = @{ $hops };
        #$stats->add_data( $hop_count );
    }
    
    #look at paths
    foreach my $mdId (keys %pathTracker){
        my @paths = keys %{$pathTracker{$mdId}};
        my $path_count = @paths;
        $pathStats->add_data( $path_count > 0 ? $path_count - 1 : 0); #subtract 1 to get rid of testCount
        $testStats->add_data( $pathTracker{$mdId}{testCount} );
    }
}

sub get_endpoint_type() {
    my $endpoint = shift @_;
    my $type = "hostname";
    
    if( is_ipv4($endpoint) ){
        $type = "ipv4";
    }elsif( is_ipv6($endpoint) ){
        $type = "ipv6";
    }
    
    return $type;
}

sub get_ip_and_host {
    my ( $endpoint ) = @_;
    
    my $ip = "";
    my $hostname = "";
    
    if( is_ipv4($endpoint) ){
        $ip = $endpoint;
        my $tmp_addr = Socket::inet_aton( $endpoint );
        if ( defined $tmp_addr and $tmp_addr ) {
            $hostname = gethostbyaddr( $tmp_addr, Socket::AF_INET );
        }
        $hostname = $endpoint unless $hostname;
    }elsif( is_ipv6($endpoint) ){
        $ip = $endpoint;
        #try to lookup v6 record?
        $hostname = $endpoint;
    }else{
        #if not ipv4 or ipv6 then assume a hostname
        $hostname = $endpoint;
        my $packed_ip = gethostbyname( $endpoint );
        if ( defined $packed_ip and $packed_ip ) {
            $ip = inet_ntoa( $packed_ip );
        }
        $ip = $endpoint unless $ip;
    }
    
    return { 'ip' => $ip, 'hostname' => $hostname };
}

sub check_exclude_one_endpoint {
    my ($doc, $endpoint_addrs, $type, $excludedTests) = @_;
    
    my $mdSrc = find($doc->getDocumentElement, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='src']/\@value");        
    my $mdDst = find($doc->getDocumentElement, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='dst']/\@value");
    my $mdId = find($doc->getDocumentElement, "./\@id");
    
    #determine whether we should compare the source or dest first
    my $firstCheck = $mdSrc;
    my $secondCheck = $mdDst;
    if($type eq 'dst'){
        $firstCheck = $mdDst;
        $secondCheck = $mdSrc;
    }
    
    if( &endpoint_matches($firstCheck, $endpoint_addrs->{$type}) ){
        $excludedTests->{"$mdId"} = 0;
    }else{
        $excludedTests->{"$mdId"} = 1;
    }
    
    #print "$mdSrc -> $mdDst\n" if ($excludedTests->{"$mdId"} == 0);
}

sub check_exclude_two_endpoints {
    my ($doc, $endpoint_addrs, $excludedTests) = @_;
    
    my $mdSrc = find($doc->getDocumentElement, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='src']/\@value");        
    my $mdDst = find($doc->getDocumentElement, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='dst']/\@value");
    my $mdId = find($doc->getDocumentElement, "./\@id");
    
    if( &endpoint_matches($mdSrc, $endpoint_addrs->{"src"})  && 
        &endpoint_matches($mdDst, $endpoint_addrs->{"dst"}) ){
        $excludedTests->{"$mdId"} = 0;
    }else{
        $excludedTests->{"$mdId"} = 1;
    }
    #print "$mdSrc -> $mdDst\n" if ($excludedTests->{"$mdId"} == 0);
}

sub endpoint_matches {
    my( $ep1, $ep2 ) = @_;
    
    foreach my $ep2_type(keys %{ $ep2 }){
        if( lc($ep1."") eq lc($ep2->{$ep2_type}) ){
            return 1;
        }
    }
    
    return 0;
}

sub check_exclude_test() {
    my ( $types, $doc, $target, $excludedTests) = @_;
    
    if(!$target){
        return;
    }
    
    my %targetMap = ();
    foreach my $type(@{$types}){
        my $ep = find($doc->getDocumentElement, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='$type']/\@value");        
        $targetMap{$ep.""} = $type;
    }
    if(!$targetMap{$target}){
        my $mdId = find($doc->getDocumentElement, "./\@id");
        $excludedTests->{"$mdId"} = 1;
    }
}
