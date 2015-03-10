package perfSONAR_PS::ServiceChecks::EsmondThroughputCheck;

use Mouse;

use perfSONAR_PS::Client::Esmond::ApiConnect;
use perfSONAR_PS::Client::Esmond::ApiFilters;
use perfSONAR_PS::ServiceChecks::Parameters::ThroughputParameters;
our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Check';

override 'do_check' => sub {
    my ($self, $params) = @_;
    my $stats = Statistics::Descriptive::Sparse->new();
    my $res = $self->call_ma($params->source, $params->destination, $params, $stats);
    return ($res, $stats) if($res);
    if($params->bidirectional){
        $res = $self->call_ma($params->destination, $params->source, $params, $stats);
        return ($res, $stats) if($res);
    }
    return ('', $stats);
};

sub call_ma {
    #send request
    my ($self, $src, $dst $params, $stats) = @_;
    my $ip_type= $params->ip_type;
    
    my $filters = new perfSONAR_PS::Client::Esmond::ApiFilters(timeout => $params->timeout);
    $filters->source($src) if($src);
    $filters->destination($dst) if($dst);
    $filters->measurement_agent($params->measurement_agent) if($params->measurement_agent);
    $filters->tool_name($params->tool_name) if($params->tool_name);
    $filters->metadata_filters->{'ip-transport-protocol'} = $params->protocol if($params->protocol);
    $filters->metadata_filters->{'bw-target-bandwidth'} = $params->udp_bandwidth if($params->udp_bandwidth);
    if($params->custom_filters){
        foreach my $custom_filter(@{$params->custom_filters}){
            my @filter_parts = split ':', $custom_filter;
            next if(@filter_parts != 2);
            $filters->metadata_filters->{$filter_parts[0]} = $filter_parts[1];
        }
    }
    
    if($ip_type eq 'v4'){
        $filters->dns_match_only_v4();
    }elsif($ip_type eq 'v6'){
        $filters->dns_match_only_v6();
    }
    $filters->time_range($params->time_range) if($params->time_range);
    $filters->event_type('throughput');
    my $client = new perfSONAR_PS::Client::Esmond::ApiConnect(
        url => $params->ma_url,
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

__PACKAGE__->meta->make_immutable;

1;