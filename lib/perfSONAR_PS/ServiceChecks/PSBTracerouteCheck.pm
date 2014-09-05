package perfSONAR_PS::ServiceChecks::PSBTracerouteCheck;

use Mouse;
use Data::Validate::IP qw(is_ipv4 is_ipv6);
use Statistics::Descriptive;
use perfSONAR_PS::Common qw( find findvalue );
use perfSONAR_PS::Utils::DNS qw( reverse_dns resolve_address);
use perfSONAR_PS::Client::MA;
use XML::LibXML;
use Socket;

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
    my $timeout = $params->timeout;
    my $ip_type = $params->ip_type;
    my $ma = new perfSONAR_PS::Client::MA( { instance => $ma_url, alarm_disabled => 1 } );
    my $stats = Statistics::Descriptive::Sparse->new();
    
    my %endpoint_addrs = ();
    $endpoint_addrs{"src"} = $self->get_ip_and_host($src, $ip_type) if($src);
    $endpoint_addrs{"dst"} = $self->get_ip_and_host($dst, $ip_type) if($dst);
    
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
        local $SIG{ALRM} = sub {  die "Timeout occurred while trying to contact MA"; };
        alarm $timeout;
        $result = $ma->setupDataRequest(
                {
                    start      => $startTime,
                    end        => $endTime,
                    subject    => $subject,
                    eventTypes => \@eventTypes
                }
            ) or die "Unable to contact MA. Please check that the MA is running and the URL is correct.";
        alarm 0;
    }; 
    if($@){
        return ($@, undef);
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
    my %pathTracker = ();
    foreach my $md (@{$result->{"metadata"}}) {
        my $mdDoc;
        eval { $mdDoc = $parser->parse_string($md); };  
        if($@){
            my $msg = "Error parsing metadata in MA response: " . $@;
            return ($msg, undef);
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
            $self->check_exclude_two_endpoints($mdDoc, \%endpoint_addrs, \%excludedTests);
        }elsif($src || $dst){
            $self->check_exclude_one_endpoint( $mdDoc, \%endpoint_addrs, $endpointToCheck, \%excludedTests);
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
            #make sure we don't track excluded tests
            if(exists $pathTracker{$mdIdRef}){
                delete $pathTracker{$mdIdRef};
            }
            next;
        }
        
        my $hops = find($doc->getDocumentElement, "./*[local-name()='datum']", 0);
        if( !defined $hops){
            return ("Error extracting hops from MA response", undef );
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
    }
    
    #look at paths
    foreach my $mdId (keys %pathTracker){
        my @paths = keys %{$pathTracker{$mdId}};
        my $path_count = @paths;
        $stats->add_data( $path_count > 0 ? $path_count - 1 : 0); #subtract 1 to get rid of testCount
    }
    
    return '', $stats;
};


sub get_endpoint_type() {
    my ($self, $endpoint) =  @_;
    my $type = "hostname";
    
    if( is_ipv4($endpoint) ){
        $type = "ipv4";
    }elsif( is_ipv6($endpoint) ){
        $type = "ipv6";
    }
    
    return $type;
}

sub get_ip_and_host {
    my ( $self, $endpoint, $ip_type ) = @_;
    
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
        my @addresses = resolve_address($endpoint);
        my $count = 0;
        for(my $i =0; $i < @addresses; $i++){
            if( is_ipv4($addresses[$i]) && $ip_type !~ 'v4'){
                next;
            }elsif( is_ipv6($addresses[$i]) && $ip_type !~ 'v6'){
                next;
            }
            $result{"ip.$count"} = $self->normalize_ipv6($addresses[$i]) unless($addresses[$i] eq $endpoint);
            $count++;
        }
        $result{'hostname'} = $endpoint unless($count == 0);
    }
    
    return \%result;
}

sub normalize_ipv6 {
    my ($self, $ipv6) = @_;
    
    $ipv6 =~ s/(:0+)+:/::/g;
    
    return $ipv6;
}

sub check_exclude_one_endpoint {
    my ($self, $doc, $endpoint_addrs, $type, $excludedTests) = @_;
    
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
    }else{
        $excludedTests->{"$mdId"} = 1;
    }
    
    #print "$mdSrc -> $mdDst\n" if ($excludedTests->{"$mdId"} == 0);
}

sub check_exclude_two_endpoints {
    my ($self, $doc, $endpoint_addrs, $excludedTests) = @_;
    
    my $mdSrc = find($doc->getDocumentElement, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='src']/\@value");        
    my $mdDst = find($doc->getDocumentElement, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='dst']/\@value");
    my $mdId = find($doc->getDocumentElement, "./\@id");
    
    if( $self->endpoint_matches($mdSrc, $endpoint_addrs->{"src"})  && 
        $self->endpoint_matches($mdDst, $endpoint_addrs->{"dst"}) ){
        $excludedTests->{"$mdId"} = 0;
    }else{
        $excludedTests->{"$mdId"} = 1;
    }
    #print "$mdSrc -> $mdDst\n" if ($excludedTests->{"$mdId"} == 0);
}

sub endpoint_matches {
    my( $self, $ep1, $ep2 ) = @_;
    
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

__PACKAGE__->meta->make_immutable;

1;