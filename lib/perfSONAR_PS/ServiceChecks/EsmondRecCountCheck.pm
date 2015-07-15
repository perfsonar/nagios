package perfSONAR_PS::ServiceChecks::EsmondRecCountCheck;

use Mouse;

use perfSONAR_PS::Client::Esmond::ApiConnect;
use perfSONAR_PS::Client::Esmond::ApiFilters;
use perfSONAR_PS::ServiceChecks::Parameters::RecCountParameters;
our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Check';

override 'do_check' => sub {
    my ($self, $params) = @_;
    my $recordcnt = Statistics::Descriptive::Sparse->new();
    my $msg = $self->call_ma($params->source, $params->destination, $params, $recordcnt);
    return ($msg, $recordcnt) if(($msg) || (!$params->bidirectional));
    $msg = $self->call_ma($params->destination, $params->source, $params, $recordcnt);
    return ($msg, $recordcnt);
};


sub call_ma {
    #send request
    my ($self, $src, $dst, $params, $recordcnt) = @_;
    my $ip_type = $params->ip_type;
	my $event_type = $params->event_type;
	
    my $filters = new perfSONAR_PS::Client::Esmond::ApiFilters(timeout => $params->timeout);
    $filters->source($src) if($src);
    $filters->destination($dst) if($dst);
    $filters->measurement_agent($params->measurement_agent) if($params->measurement_agent);
    $filters->tool_name($params->tool_name) if($params->tool_name);
    $filters->metadata_filters->{'ip-transport-protocol'} = $params->protocol if($params->protocol);
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
    $filters->event_type($event_type);
    my $client = new perfSONAR_PS::Client::Esmond::ApiConnect(
        url => $params->ma_url,
        filters => $filters
    );
    
# get the metadata reply in order to be able to get around here!

    #parse results
    my $md = $client->get_metadata();
	my $tmp;
    return $client->error if($client->error);
    $recordcnt->add_data( scalar(@{$md}) );
	unless( $recordcnt > 0){
        my $msg = "Unable to find tests with data in the given time range of the event_type of $event_type";
        $msg .= " where " if($src || $dst);
        $msg .= "source is $src" if($src);
        $msg .= " and " if($src && $dst);
        $msg .= "destination is $dst" if($dst);
		$recordcnt = 0;
        return $msg;
    }
	
    return '';  
}

__PACKAGE__->meta->make_immutable;

1;