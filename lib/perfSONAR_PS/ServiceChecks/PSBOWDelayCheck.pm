package perfSONAR_PS::ServiceChecks::PSBOWDelayCheck;

use Moose;
use Data::Validate::IP qw(is_ipv4 is_ipv6);
use Socket;
use Statistics::Descriptive;
use perfSONAR_PS::Common qw( find findvalue );
use perfSONAR_PS::Client::MA;
use perfSONAR_PS::ServiceChecks::OWDelayCheck;
use perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters;
use perfSONAR_PS::Utils::DNS qw( reverse_dns resolve_address);
use XML::LibXML;

our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Check';

use constant HAS_METADATA => 1;
use constant HAS_DATA => 2;

override 'do_check' => sub {
    my ($self, $params) = @_;
    my $ma_url = $params->ma_url;
    my $src = $params->source;
    my $dst = $params->destination;
    my $time_int = $params->time_range;
    my $metric = $params->metric;
    my $bidir = $params->bidirectional;
    my $timeout = $params->timeout;
    my $is_percentage = $params->as_percentage;
    my $stats = Statistics::Descriptive::Sparse->new();
     
    my %endpoint_addrs = ();
    $endpoint_addrs{"src"} = $self->get_ip_and_host($src) if($src);
    $endpoint_addrs{"dst"} = $self->get_ip_and_host($dst) if($dst);
    my $memd_key = 'check_owdelay:' . $ma_url . ':' . $time_int;
    
    my $result = q{};
    if($self->memd){
        $result = $self->memd->get($memd_key);
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
            local $SIG{ALRM} = sub { die("Timeout occurred while trying to contact MA"); };
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
        if($@){
            return ($@, undef);
        }
        if($err_msg){
            return ($err_msg, undef);
        }
        if($self->memd){
            $self->memd->set($memd_key, $result, $self->memd_expire_time );
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
            my $msg = "Error parsing metadata in MA response" . $@;
            return ($msg, undef);
        }
        
        #record test
        $self->record_endpoints($mdDoc, \%mdIdMap, \%mdEndpointMap) if($bidir);
        
        if(!$src && !$dst){
            #we recorded the endpoint for bidirectional test, 
            # but don't need to exclude anything so go to next iteration
            next;
        }
        
        #This code sets which tests should be ignored because they don't contain the correct endpoints
        if($src && $dst){
            $self->check_exclude_two_endpoints($mdDoc, \%endpoint_addrs, $bidir, \%excludedTests);
        }else{
            $self->check_exclude_one_endpoint( $mdDoc, \%endpoint_addrs, $endpointToCheck, $bidir, \%excludedTests);
        }
    }
    
    #parse data
    foreach my $data ( @{$result->{data}} ){
        my $doc;
        eval { $doc = $parser->parse_string( $data ); };  
        if($@){
            my $msg = "Error parsing data in MA response" . $@;
            return ($msg, undef);
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
            my $msg = "Could not find definition for test " . $mdIdMap{$mdIdRef} . ", but found reverse test.";
            return ($msg, undef);
        }
        
        #my $owamp_data = find($doc->getDocumentElement, "./*[local-name()='datum']/$metric", 0);
        my $owamp_data = find($doc->getDocumentElement, "./*[local-name()='datum']", 0);
        if( !defined $owamp_data){
            return ("Error extracting metric from MA response", undef);
        }
        
        foreach my $owamp_datum (@{$owamp_data}) {
            my $tmpAttr = find($owamp_datum, "\@${metric}");
            next unless($tmpAttr && @{$tmpAttr} > 0);
            my $tmpValue = $tmpAttr->[0]->getValue();
            next unless(defined $tmpValue);
            if($is_percentage && $metric eq 'loss'){
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
                return ("Found data for $has_data_key, but could not find reverse test.", undef);
            }
        }
    }
    
    return ('', $stats);
};

sub get_endpoint_type {
    my ( $self, $endpoint ) = @_;
    my $type = "hostname";
    
    if( is_ipv4($endpoint) ){
        $type = "ipv4";
    }elsif( is_ipv6($endpoint) ){
        $type = "ipv6";
    }
    
    return $type;
}

sub get_ip_and_host {
    my ( $self, $endpoint ) = @_;
    
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
        $result{'ip'} = $self->normalize_ipv6($endpoint);
        my $hostname = reverse_dns($result{'ip'});
        $result{'hostname'} = $hostname if($hostname);
    }else{
        #if not ipv4 or ipv6 then assume a hostname
        $result{'hostname'} = $endpoint;
        my @addresses = resolve_address($endpoint);
        for(my $i =0; $i < @addresses; $i++){
            $result{"ip.$i"} = $self->normalize_ipv6($addresses[$i]) unless($addresses[$i] eq $result{'hostname'});
        }
    }
    
    return \%result;
}

sub normalize_ipv6 {
    my ($self, $ipv6) = @_;
    
    $ipv6 =~ s/(:0+)+:/::/g;
    
    return $ipv6;
}

sub check_exclude_one_endpoint {
    my ($self, $doc, $endpoint_addrs, $type, $bidir, $excludedTests) = @_;
    
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
    
    if( $self->endpoint_matches($firstCheck, $endpoint_addrs->{$type}) ){
        $excludedTests->{"$mdId"} = 0;
    }elsif($bidir && 
            $self->endpoint_matches($secondCheck, $endpoint_addrs->{$type}) ) {
        $excludedTests->{"$mdId"} = 0;
    }else{
        $excludedTests->{"$mdId"} = 1;
    }
    
    #print "$mdSrc -> $mdDst\n" if ($excludedTests->{"$mdId"} == 0);
}

sub check_exclude_two_endpoints {
    my ($self, $doc, $endpoint_addrs, $bidir, $excludedTests) = @_;
    
    my $mdSrc = find($doc->getDocumentElement, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='src']/\@value");        
    my $mdDst = find($doc->getDocumentElement, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='dst']/\@value");
    my $mdId = find($doc->getDocumentElement, "./\@id");
    
    if( $self->endpoint_matches($mdSrc, $endpoint_addrs->{"src"})  && 
        $self->endpoint_matches($mdDst, $endpoint_addrs->{"dst"}) ){
        $excludedTests->{"$mdId"} = 0;
    }elsif($bidir && 
            $self->endpoint_matches($mdSrc, $endpoint_addrs->{"dst"})  && 
            $self->endpoint_matches($mdDst, $endpoint_addrs->{"src"}) ) {
        $excludedTests->{"$mdId"} = 0;
    }else{
        $excludedTests->{"$mdId"} = 1;
    }
    #print "$mdSrc -> $mdDst\n" if ($excludedTests->{"$mdId"} == 0);
}

sub endpoint_matches {
    my( $self, $ep1, $ep2 ) = @_;
    
    $ep1 = $self->normalize_ipv6($ep1);
    foreach my $ep2_type(keys %{ $ep2 }){
        if( lc($ep1."") eq lc($ep2->{$ep2_type}) ){
            return 1;
        }
    }
    
    return 0;
}

sub check_exclude_test() {
    my ( $self, $types, $doc, $target, $excludedTests) = @_;
    
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
    my ($self, $doc, $mdIdMap, $mdEndpointMap) = @_;
    my $src = find($doc->getDocumentElement, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='src']/\@value");
    my $dst = find($doc->getDocumentElement, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='dst']/\@value");
    my $mdId = find($doc->getDocumentElement, "./\@id");
    $mdIdMap->{$mdId} = $dst.'->'.$src;
    $mdEndpointMap->{$src.'->'.$dst} = HAS_METADATA;
}
