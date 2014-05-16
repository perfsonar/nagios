package perfSONAR_PS::ServiceChecks::EsmondThroughputCheck;

use Moose;

use perfSONAR_PS::Client::Esmond::ApiConnect;
use perfSONAR_PS::Client::Esmond::ApiFilters;
use perfSONAR_PS::ServiceChecks::Parameters::ThroughputParameters;
our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Check';

override 'do_check' => sub {
    my ($self, $params) = @_;
    my $stats = Statistics::Descriptive::Sparse->new();
    my $res = $self->call_ma($params->ma_url, $params->source, $params->destination, $params->time_range, $params->protocol, $params->timeout,  $params->ip_type, $stats);
    return ($res, $stats) if($res);
    if($params->bidirectional){
        $res = $self->call_ma($params->ma_url, $params->destination, $params->source, $params->time_range, $params->protocol, $params->timeout, $params->ip_type, $stats);
        return ($res, $stats) if($res);
    }
    return ('', $stats);
};

sub call_ma {
    #send request
    my ($self, $ma_url, $src, $dst, $time_int, $protocol, $timeout, $ip_type, $stats) = @_;
    
    my $filters = new perfSONAR_PS::Client::Esmond::ApiFilters(timeout => $timeout);
    $filters->source($src) if($src);
    $filters->destination($dst) if($dst);
    $filters->metadata_filters->{'ip-transport-protocol'} = $protocol if($protocol);
    if($ip_type eq 'v4'){
        $filters->dns_match_only_v4();
    }elsif($ip_type eq 'v6'){
        $filters->dns_match_only_v6();
    }
    $filters->time_range($time_int) if($time_int);
    $filters->event_type('throughput');
    my $client = new perfSONAR_PS::Client::Esmond::ApiConnect(
        url => $ma_url,
        filters => $filters
    );
    
    #parse results
    my $md = $client->get_metadata();
    return $client->error if($client->error);
    unless(scalar(@{$md}) > 0){
        my $msg = 'Unable to find any tests with data in the given time range';
        $msg .= " where " if($src || $dst);
        $msg .= "source is $src" if($src);
        $msg .= " and " if($src && $dst);
        $msg .= "destination is $dst" if($dst);
        return $msg;
    }
    foreach my $m(@{$md}){
        my $et = $m->get_event_type("throughput");
        my $data = $et->get_data();
        return $et->error if($et->error);
        foreach my $d(@{$data}){
            $stats->add_data($d->val);
        }
    }
    
    return '';  
}

1;