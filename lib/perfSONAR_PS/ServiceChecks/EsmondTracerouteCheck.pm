package perfSONAR_PS::ServiceChecks::EsmondTracerouteCheck;

use Moose;
use perfSONAR_PS::Client::Esmond::ApiConnect;
use perfSONAR_PS::Client::Esmond::ApiFilters;

our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Check';

override 'do_check' => sub {
    my ($self, $params) = @_;
    my $stats = Statistics::Descriptive::Sparse->new();
    my $filters = new perfSONAR_PS::Client::Esmond::ApiFilters(timeout => $params->timeout);
    $filters->source($params->source) if($params->source);
    $filters->destination($params->destination) if($params->destination);
    $filters->time_range($params->time_range) if($params->time_range);
    $filters->event_type('packet-trace');
    my $client = new perfSONAR_PS::Client::Esmond::ApiConnect(
        url => $params->ma_url,
        filters => $filters
    );
    
    #parse results
    my $md = $client->get_metadata();
    return $client->error if($client->error);
    unless(scalar(@{$md}) > 0){
        return  'Unable to find any tests with data in the given time range';
    }
    foreach my $m(@{$md}){
        my $et = $m->get_event_type($filters->event_type());
        my $data = $et->get_data();
        return $et->error if($et->error);
        my %path_tracker = ();
        foreach my $d(@{$data}){
            my @addrs = ();
            next unless($d->val && ref($d->val) eq 'ARRAY');
            foreach my $v(@{$d->val}){
                next unless($v && ref($v) eq 'HASH' && $v->{ip} );
                push @addrs, $v->{ip};
            }
            $path_tracker{join(',', @addrs)}++ if(@addrs > 0);
        }
        $stats->add_data(scalar(keys %path_tracker));
    }
    
    return ('', $stats);
};

1;