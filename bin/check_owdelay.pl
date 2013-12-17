#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use Cache::Memcached;
use Nagios::Plugin;
use Data::Validate::IP qw(is_ipv4 is_ipv6);
use Socket;
use Statistics::Descriptive;
use perfSONAR_PS::Common qw( find findvalue );
use perfSONAR_PS::Client::MA;
use perfSONAR_PS::Utils::DNS qw( reverse_dns resolve_address);
use XML::LibXML;


use constant DELAY_LABEL => 'ms';
use constant DELAY_FIELD => '@min_delay';
use constant DELAY_SCALE => 1000;
use constant DELAY_STRING => 'Minimum delay';
use constant LOSS_LABEL => 'pps';
use constant LOSS_LABEL_LONG => ' packets per session';
use constant LOSS_PERCENT_LABEL => '%';
use constant LOSS_FIELD => '@loss';
use constant LOSS_SCALE => 1;
use constant LOSS_STRING => 'Loss';
use constant HAS_METADATA => 1;
use constant HAS_DATA => 2;
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
$np->add_arg(spec => "errwarn",
             help => "Communication and parsing errors throw WARNING",
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
my $stats = Statistics::Descriptive::Sparse->new();
my $EXCEPTION_CODE = UNKNOWN;
if($np->opts->{'errwarn'}){
    $EXCEPTION_CODE = WARNING;
}
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
&send_data_request($ma_url, $np->opts->{'s'}, $np->opts->{'d'}, $np->opts->{'r'}, $metric, $np->opts->{'b'}, $stats, $np->opts->{'timeout'}, $np->opts->{'p'});
if($stats->count() == 0 ){
    my $errMsg = "No one-way delay data returned";
    $errMsg .= " for direction where" if($np->opts->{'s'} || $np->opts->{'d'});
    $errMsg .= " src=" . $np->opts->{'s'} if($np->opts->{'s'});
    $errMsg .= " dst=" . $np->opts->{'d'} if($np->opts->{'d'});
    $np->nagios_exit($EXCEPTION_CODE, $errMsg);
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

#### SUBROUTINES
sub send_data_request() {
    my ($ma_url, $src, $dst, $time_int, $metric, $bidir, $stats, $timeout, $is_percentage) = @_;
    
    my %endpoint_addrs = ();
    $endpoint_addrs{"src"} = &get_ip_and_host($src) if($src);
    $endpoint_addrs{"dst"} = &get_ip_and_host($dst) if($dst);
    my $memd_key = 'check_owdelay:' . $ma_url . ':' . $time_int;
    
    my $result = q{};
    if($memd){
        $result = $memd->get($memd_key);
    }
    if(!$result){
        # Define subject
        my $subject = "<owamp:subject xmlns:owamp=\"http://ggf.org/ns/nmwg/tools/owamp/2.0/\" id=\"subject\">\n";
        $subject .= "      <nmwgt:endPointPair xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\"/>\n";
        $subject .=   "</owamp:subject>\n";
    
        # Set eventType
        my @eventTypes = ("http://ggf.org/ns/nmwg/characteristic/delay/summary/20070921");
    
        my $endTime = time;
        my $startTime = $endTime - $time_int;
    
        my $err_msg = q{};
        my $ma = new perfSONAR_PS::Client::MA( { instance => $ma_url, alarm_disabled => 1 } );
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
        if($memd){
            $memd->set($memd_key, $result, $memd_expire_time );
        }
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
        
        #my $owamp_data = find($doc->getDocumentElement, "./*[local-name()='datum']/$metric", 0);
        my $owamp_data = find($doc->getDocumentElement, "./*[local-name()='datum']", 0);
        if( !defined $owamp_data){
            $np->nagios_exit( $EXCEPTION_CODE, "Error extracting metric from MA response" );
        }
        
        foreach my $owamp_datum (@{$owamp_data}) {
            my $tmpAttr = find($owamp_datum, "$metric");
            next unless($tmpAttr && @{$tmpAttr} > 0);
            my $tmpValue = $tmpAttr->[0]->getValue();
            next unless(defined $tmpValue);
            if($is_percentage && $metric eq LOSS_FIELD){
                my $tmpSentAttr = find($owamp_datum, '@sent');
                next unless($tmpSentAttr && @{$tmpSentAttr} > 0);
                my $tmpSent = $tmpSentAttr->[0]->getValue();
                next unless($tmpSent);
                $tmpValue /= $tmpSent;
                $tmpValue *= 100;
            }
            $stats->add_data( $tmpValue );
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
    
    my %result = ();
    
    if( is_ipv4($endpoint) ){
        my $hostname = '';
        $result{'ip'} = $endpoint;
        my $tmp_addr = Socket::inet_aton( $endpoint );
        if ( defined $tmp_addr and $tmp_addr ) {
            $hostname = gethostbyaddr( $tmp_addr, Socket::AF_INET );
        }
        $result{'hostname'} = $hostname if($hostname);
    }elsif( is_ipv6($endpoint) ){
        $result{'ip'} = normalize_ipv6($endpoint);
        my $hostname = reverse_dns($result{'ip'});
        $result{'hostname'} = $hostname if($hostname);
    }else{
        #if not ipv4 or ipv6 then assume a hostname
        $result{'hostname'} = $endpoint;
        my @addresses = resolve_address($endpoint);
        for(my $i =0; $i < @addresses; $i++){
            $result{"ip.$i"} = normalize_ipv6($addresses[$i]) unless($addresses[$i] eq $result{'hostname'});
        }
    }
    
    return \%result;
}

sub normalize_ipv6 {
    my $ipv6 = shift @_;
    
    $ipv6 =~ s/(:0+)+:/::/g;
    
    return $ipv6;
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
    
    $ep1 = normalize_ipv6($ep1);
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
