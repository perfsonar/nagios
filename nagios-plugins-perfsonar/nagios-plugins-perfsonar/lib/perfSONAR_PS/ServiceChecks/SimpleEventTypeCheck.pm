package perfSONAR_PS::ServiceChecks::SimpleEventTypeCheck;

use Mouse;

use perfSONAR_PS::Client::Esmond::ApiConnect;
use perfSONAR_PS::Client::Esmond::ApiFilters;

our $VERSION = 3.4;

=head1 NAME

perfSONAR_PS::ServiceChecks::SimpleEventTypeCheck

=head1 DESCRIPTION

A check that calls the REST API and retrieves data from a given event type. This type of
check is very useful for the general case where a single numeric event type needs to be
retrieved and an average of the value compared against given thresholds.

=cut

extends 'perfSONAR_PS::ServiceChecks::Check';

has 'event_type' => (is => 'rw', isa => 'Str');

override 'do_check' => sub {
    my ($self, $params) = @_;
    my $stats = Statistics::Descriptive::Sparse->new();
    my $res = $self->call_ma($params->source, $params->destination, $params, $params->timeout, $params->ip_type, $stats);
    return ($res, $stats) if($res);
    if($params->bidirectional){
        $res = $self->call_ma($params->destination, $params->source, $params, $params->timeout, $params->ip_type, $stats);
        return ($res, $stats) if($res);
    }
    return ('', $stats);
};

sub call_ma {
    #send request
    my ($self, $src, $dst, $params, $timeout, $ip_type, $stats) = @_;
    
    my $filters = new perfSONAR_PS::Client::Esmond::ApiFilters(timeout => $timeout);
    $filters->source($src) if($src);
    $filters->destination($dst) if($dst);
    $filters->time_range($params->time_range) if($params->time_range);
    $filters->measurement_agent($params->measurement_agent) if($params->measurement_agent);
    $filters->tool_name($params->tool_name) if($params->tool_name);
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
    $filters->event_type($self->event_type);
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
        my $et = $m->get_event_type($filters->event_type());
        my $data = $et->get_data();
        return $et->error if($et->error);
        foreach my $d(@{$data}){
            if(!ref($d->val) || ref($d->val) eq 'SCALAR'){
                $stats->add_data($d->val);
            }else{
                #not a scalar so just count instances
                $stats->add_data(1);
            }
        }
    }
    
    return '';  
}

__PACKAGE__->meta->make_immutable;

1;