#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/../lib/";
use Nagios::Plugin;
use Data::Validate::IP qw(is_ipv4 is_ipv6);
use Socket;
use Statistics::Descriptive;
use perfSONAR_PS::Common qw( find findvalue );
use perfSONAR_PS::Client::MA;
use XML::LibXML;


use constant DELAY_LABEL => 'ms';
use constant DELAY_FIELD => '@min_delay';
use constant DELAY_SCALE => 1000;
use constant DELAY_STRING => 'Minimum delay';
use constant LOSS_LABEL => '';
use constant LOSS_FIELD => '@loss';
use constant LOSS_SCALE => 1;
use constant LOSS_STRING => 'Loss';
use constant HAS_METADATA => 1;
use constant HAS_DATA => 2;

my $np = Nagios::Plugin->new( shortname => 'PS_CHECK_OWDELAY',
                              timeout => 60,
                              usage => "Usage: %s -u|--url <service-url> -s|--source <source-addr> -d|--destination <dest-addr> -b|--bidirectional -l|--loss -r <number-seconds-in-past> -w|--warning <threshold> -c|--critical <threshold> --t|timeout <timeout>" );

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
$np->add_arg(spec => "errwarn",
             help => "Communication and parsing errors throw WARNING",
             required => 0 );
$np->add_arg(spec => "r|range=i",
             help => "Time range (in seconds) in the past to look at data. i.e. 60 means look at last 60 seconds of data.",
             required => 1 );
$np->add_arg(spec => "w|warning=s",
             help => "threshold of delay (" . DELAY_LABEL . ") that leads to WARNING status. In loss mode this is average packets lost as an integer.",
             required => 1 );
$np->add_arg(spec => "c|critical=s",
             help => "threshold of delay (" . DELAY_LABEL . ") that leads to CRITICAL status. In loss mode this is average packets lost as an integer.",
             required => 1 );
$np->getopts;                              

#create client
my $ma_url = $np->opts->{'u'};
my $ma = new perfSONAR_PS::Client::MA( { instance => $ma_url, alarm_disabled => 1 } );
my $stats = Statistics::Descriptive::Sparse->new();
my $EXCEPTION_CODE = UNKNOWN;
if($np->opts->{'errwarn'}){
    $EXCEPTION_CODE = WARNING;
}


#set metric
my $metric = DELAY_FIELD;
my $metric_label = DELAY_LABEL;
my $metric_scale = DELAY_SCALE;
my $metric_string = DELAY_STRING;
if($np->opts->{'l'}){
    $metric = LOSS_FIELD;
    $metric_label = LOSS_LABEL;
    $metric_scale = LOSS_SCALE;
    $metric_string = LOSS_STRING;
}

#call client
&send_data_request($ma, $np->opts->{'s'}, $np->opts->{'d'}, $np->opts->{'r'}, $metric, $np->opts->{'b'}, $stats, $np->opts->{'timeout'});
if($stats->count() == 0 ){
    my $errMsg = "No one-way delay data returned";
    $errMsg .= " for direction where" if($np->opts->{'s'} || $np->opts->{'d'});
    $errMsg .= " src=" . $np->opts->{'s'} if($np->opts->{'s'});
    $errMsg .= " dst=" . $np->opts->{'d'} if($np->opts->{'d'});
    $np->nagios_exit($EXCEPTION_CODE, $errMsg);
}

# format nagios output
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
    $msg = "$metric_string is " . ($stats->mean() * $metric_scale) . $metric_label;
}else{
    $msg = "Error analyzing results";
}
$np->nagios_exit($code, $msg);

#### SUBROUTINES
sub send_data_request() {
    my ($ma, $src, $dst, $time_int, $metric, $bidir, $stats, $timeout) = @_;
    my %endpoint_addrs = ();
    $endpoint_addrs{"src"} = &get_ip_and_host($src) if($src);
    $endpoint_addrs{"dst"} = &get_ip_and_host($dst) if($dst);
    
    # Define subject
    my $subject = "<owamp:subject xmlns:owamp=\"http://ggf.org/ns/nmwg/tools/owamp/2.0/\" id=\"subject\">\n";
    $subject .= "      <nmwgt:endPointPair xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\"/>\n";
    $subject .=   "</owamp:subject>\n";
    
    # Set eventType
    my @eventTypes = ("http://ggf.org/ns/nmwg/characteristic/delay/summary/20070921");
    
    my $endTime = time;
    my $startTime = $endTime - $time_int;
    
    my $result = q{};
    my $err_msg = q{};
    eval {
        local $SIG{ALRM} = sub {  $np->nagios_exit( $EXCEPTION_CODE, "Timeout occurred while trying to contact MA"); };
        alarm $timeout;
        $result = $ma->setupDataRequest(
            {
                start      => $startTime,
                end        => $endTime,
                subject    => $subject,
                eventTypes => \@eventTypes
            }
        ) or ($err_msg = "Unable to contact MA. Please check that the MA is running and the URL is correct.");
        alarm 0;
    };
    if($err_msg){
        $np->nagios_exit( $EXCEPTION_CODE, $err_msg);
    }
    
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
    foreach my $md (@{$result->{"metadata"}}) {
        if(!$src && !$dst && !$bidir){
            last;
        }
        
        my $mdDoc;
        eval { $mdDoc = $parser->parse_string($md); };  
        if($@){
            $np->nagios_exit( $EXCEPTION_CODE, "Error parsing metadata in MA response" . $@ );
        }
        
        #record test
        &record_endpoints($mdDoc, \%mdIdMap, \%mdEndpointMap) if($bidir);
        
        if(!$src && !$dst){
            #we recorded the endpoint for bidirectional test, 
            # but don't need to exclude anything so go to next iteration
            next;
        }
        
        #This code sets which tests should be ignored because they don't contain the correct endpoints
        if($src && $dst){
            &check_exclude_two_endpoints($mdDoc, \%endpoint_addrs, $bidir, \%excludedTests);
        }else{
            &check_exclude_one_endpoint( $mdDoc, \%endpoint_addrs, $endpointToCheck, $bidir, \%excludedTests);
        }
    }
    
    #parse data
    foreach my $data ( @{$result->{data}} ){
        my $doc;
        eval { $doc = $parser->parse_string( $data ); };  
        if($@){
            $np->nagios_exit( $EXCEPTION_CODE, "Error parsing data in MA response" . $@ );
        }
        
        my $mdIdRef = find($doc->getDocumentElement, "./\@metadataIdRef");
        if(!$mdIdRef){ 
            next;
        }
        
        #skip tests without matching endpoints
        if($excludedTests{"$mdIdRef"}){
            #make sure that irrelevant tests aren't a factor when checking bidirectionality
            if($bidir && (!$src || !$dst) && $mdIdMap{$mdIdRef}){
                $mdEndpointMap{$mdIdMap{$mdIdRef}} = HAS_DATA;
            }
            next;
        }
        
        #verify that reverse direction metadata exists. if both src and dst given then checked elsewhere
        if($bidir && (!$src || !$dst) && (!$mdIdMap{$mdIdRef} || !$mdEndpointMap{$mdIdMap{$mdIdRef}})){
            $np->nagios_exit( $EXCEPTION_CODE, "Could not find definition for test " . $mdIdMap{$mdIdRef} . ", but found reverse test." );
        }
        
        my $owamp_data = find($doc->getDocumentElement, "./*[local-name()='datum']/$metric", 0);
        if( !defined $owamp_data){
            $np->nagios_exit( $EXCEPTION_CODE, "Error extracting metric from MA response" );
        }
        
        foreach my $owamp_datum (@{$owamp_data}) {
            $stats->add_data( $owamp_datum->getValue() );
            $mdEndpointMap{$mdIdMap{$mdIdRef}} = HAS_DATA if($bidir && (!$src || !$dst));
        }
    }
    
    #if a bidirectional test, verify all the tests have data
    if($bidir && (!$src || !$dst)){
        foreach my $has_data_key (keys %mdEndpointMap){
            my $rev_key = $has_data_key;
            $rev_key =~ s/(.+)\-\>(.+)/$2->$1/;
            
            #NOTE: No error thrown if neither side has data. Presumably a host
            #   may be down, etc and we don't want all tests to die
            if($mdEndpointMap{$has_data_key} != HAS_DATA && $mdEndpointMap{$rev_key} == HAS_DATA){
                $np->nagios_exit( $EXCEPTION_CODE, "Found data for $has_data_key, but could not find reverse test.");
            }
        }
    }
}

sub get_endpoint_type {
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
    my ($doc, $endpoint_addrs, $type, $bidir, $excludedTests) = @_;
    
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
    }elsif($bidir && 
            &endpoint_matches($secondCheck, $endpoint_addrs->{$type}) ) {
        $excludedTests->{"$mdId"} = 0;
    }else{
        $excludedTests->{"$mdId"} = 1;
    }
    
    #print "$mdSrc -> $mdDst\n" if ($excludedTests->{"$mdId"} == 0);
}

sub check_exclude_two_endpoints {
    my ($doc, $endpoint_addrs, $bidir, $excludedTests) = @_;
    
    my $mdSrc = find($doc->getDocumentElement, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='src']/\@value");        
    my $mdDst = find($doc->getDocumentElement, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='dst']/\@value");
    my $mdId = find($doc->getDocumentElement, "./\@id");
    
    if( &endpoint_matches($mdSrc, $endpoint_addrs->{"src"})  && 
        &endpoint_matches($mdDst, $endpoint_addrs->{"dst"}) ){
        $excludedTests->{"$mdId"} = 0;
    }elsif($bidir && 
            &endpoint_matches($mdSrc, $endpoint_addrs->{"dst"})  && 
            &endpoint_matches($mdDst, $endpoint_addrs->{"src"}) ) {
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

sub record_endpoints {
    my ($doc, $mdIdMap, $mdEndpointMap) = @_;
    my $src = find($doc->getDocumentElement, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='src']/\@value");
    my $dst = find($doc->getDocumentElement, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='dst']/\@value");
    my $mdId = find($doc->getDocumentElement, "./\@id");
    $mdIdMap->{$mdId} = $dst.'->'.$src;
    $mdEndpointMap->{$src.'->'.$dst} = HAS_METADATA;
}
