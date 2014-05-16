package perfSONAR_PS::ServiceChecks::DelayCheck;

use Moose;
use perfSONAR_PS::Client::Esmond::ApiConnect;
use perfSONAR_PS::Client::Esmond::ApiFilters;

our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Check';

use constant STAT_MAP => {
    'min' => 'minimum',
    'median' => 'median',
    'max' => 'maximum',
    'mean' => 'mean',
    'p25' => 'percentile-25',
    'p75' => 'percentile-75',
    'p95' => 'percentile-95'
};

override 'do_check' => sub {
    my ($self, $params) = @_;
    my $stats = Statistics::Descriptive::Sparse->new();
    my $res = $self->call_ma($params->ma_url, $params->source, $params->destination, $params->time_range, $params->metric, $params->timeout, $params->ip_type, $stats);
    return ($res, $stats) if($res);
    if($params->bidirectional){
        $res = $self->call_ma($params->ma_url, $params->destination, $params->source, $params->time_range, $params->metric, $params->timeout, $params->ip_type, $stats);
        return ($res, $stats) if($res);
    }
    return ('', $stats);
};

sub call_ma {
    #send request
    my ($self, $ma_url, $src, $dst, $time_int, $metric, $timeout, $ip_type, $stats) = @_;
    
    my $filters = new perfSONAR_PS::Client::Esmond::ApiFilters(timeout => $timeout);
    my $stat = '';
    $filters->source($src) if($src);
    $filters->destination($dst) if($dst);
    $filters->time_range($time_int) if($time_int);
    if($ip_type eq 'v4'){
        $filters->dns_match_only_v4();
    }elsif($ip_type eq 'v6'){
        $filters->dns_match_only_v6();
    }
    $filters->event_type('histogram-rtt');
    if($metric =~  /(.+)_delay/){
        $stat = STAT_MAP->{$1};
        return "Unrecognized delay stat $1" unless $stat;
    }else{
        return "Unrecognized metric $metric";
    }
    
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
        my $et = $m->get_event_type($filters->event_type());
        my $summ = $et->get_summary('statistics', 0);
        next unless($summ);
        my $data = $summ->get_data();
        return $summ->error if($summ->error);
        foreach my $d(@{$data}){
            if($d->val && ref($d->val) eq 'HASH' && exists $d->val->{$stat}){
                $stats->add_data($d->val->{$stat});
            }
        }
    }
    
    return '';  
}

1;