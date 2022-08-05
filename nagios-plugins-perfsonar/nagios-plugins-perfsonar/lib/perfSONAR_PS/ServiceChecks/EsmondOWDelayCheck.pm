package perfSONAR_PS::ServiceChecks::EsmondOWDelayCheck;

use Mouse;
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
    my @fwd_metadata = ();
    my @rev_metadata = ();
    my $res = $self->call_ma($params->source, $params->destination, $params->metric, $params, 1000, $stats, \@fwd_metadata);
    my $extra_stats = {};
    return ($res, $stats) if($res);
    if($params->bidirectional){
        $res = $self->call_ma($params->destination, $params->source, $params->metric, $params, 1000, $stats, \@rev_metadata);
        return ($res, $stats) if($res);
    }
    
    if($params->compare){
        #setup extra_stats
        $extra_stats->{'PathCompare_MinRelevantDelay'} = $params->compare_mindelay;
        $extra_stats->{'PathCompare_MinRelevantDelayDelta'} = $params->compare_mindelaydelta;
        $extra_stats->{'PathCompare_MaxDelayDeltaFactor'} = sprintf("%.2f", $params->compare_maxdelaydeltafactor * 100) . "%";
        
        #collect forward and reverse data
        my $fwd_stats = Statistics::Descriptive::Sparse->new();
        my $rev_stats = Statistics::Descriptive::Sparse->new();
        $res = $self->get_compare_data(\@fwd_metadata, STAT_MAP->{$params->compare_quantile}, $fwd_stats);
        return ('', $stats, $extra_stats) if($res); #quietly exit if this fails since not primary stat
        if(@rev_metadata > 0){
            $res = $self->get_compare_data(\@rev_metadata, STAT_MAP->{$params->compare_quantile}, $rev_stats);
            return ('', $stats, $extra_stats) if($res); #quietly exit if this fails since not primary stat
        }else{
            my $metric = $params->compare_quantile . '_delay';
            $res = $self->call_ma($params->destination, $params->source, $metric, $params, 1, $rev_stats, \@rev_metadata);
            return ('', $stats, $extra_stats) if($res); #quietly exit if this fails since not primary stat
        }
        
        #now compare
        my $fwd_delay = $fwd_stats->mean();
        my $rev_delay = $rev_stats->mean();
        $extra_stats->{'PathCompare_ForwardDelay'} = sprintf("%.2f", $fwd_delay);
        $extra_stats->{'PathCompare_ReverseDelay'} = sprintf("%.2f", $rev_delay);
        #make sure its above the min delay that we care about
        if($fwd_delay <= $params->compare_mindelay && $rev_delay <= $params->compare_mindelay){
            return ('', $stats, $extra_stats);
        }
        unless($fwd_delay && $rev_delay){
            #avoid divide by 0
            return ('', $stats, $extra_stats);
        }
        
        #calculate the diff and the factor 
        my $delay_delta = 0;
        my $delay_delta_factor = 0;
        if($fwd_delay > $rev_delay){
            $delay_delta = $fwd_delay - $rev_delay;
            $delay_delta_factor = $fwd_delay/$rev_delay;
        }else{
            $delay_delta = $rev_delay - $fwd_delay;
            $delay_delta_factor = $rev_delay/$fwd_delay;
        }
        $delay_delta_factor -= 1;
        $extra_stats->{'PathCompare_DelayDelta'} = sprintf("%.2f", $delay_delta);
        $extra_stats->{'PathCompare_DelayFactor'} = sprintf("%.2f", $delay_delta_factor * 100) . "%";
        
        #make sure diff is high enough that we care about it
        if($delay_delta <= $params->compare_mindelaydelta){
            return ('', $stats, $extra_stats);
        }
        
        #finally compare the factor
        if($delay_delta_factor > $params->compare_maxdelaydeltafactor){
            return ('', $stats, $extra_stats, 6, "There is a " . sprintf("%.2f", $delay_delta_factor * 100) . "% difference between forward and reverse one-way delay.");
        }
    }
    return ('', $stats, $extra_stats);
};

sub call_ma {
    #send request
    my ($self, $src, $dst, $metric, $params, $units, $stats, $md) = @_;
    my $ip_type= $params->ip_type;
    my $as_percentage= $params->as_percentage;
    
    my $filters = new perfSONAR_PS::Client::Esmond::ApiFilters(timeout => $params->timeout);
    my $stat = '';
    $filters->source($src) if($src);
    $filters->destination($dst) if($dst);
    $filters->measurement_agent($params->measurement_agent) if($params->measurement_agent);
    $filters->tool_name($params->tool_name) if($params->tool_name);
    $filters->time_range($params->time_range) if($params->time_range);
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
    if($metric eq 'loss' && $as_percentage){
        $filters->event_type('packet-loss-rate');
    }elsif($metric eq 'loss'){
        $filters->event_type('packet-count-lost');
    }elsif($metric =~  /(.+)_delay$/){
        $stat = STAT_MAP->{$1};
        return "Unrecognized delay stat $1" unless $stat;
        $filters->event_type('histogram-owdelay');
    }else{
        return "Unrecognized metric $metric";
    }
    
    my $client = new perfSONAR_PS::Client::Esmond::ApiConnect(
        url => $params->ma_url,
        filters => $filters
    );
    
    #parse results
    my $tmpmd = $client->get_metadata();
    return $client->error if($client->error);
    unless(scalar(@{$tmpmd}) > 0){
        my $msg = 'Unable to find any tests with data in the given time range';
        $msg .= " where " if($src || $dst);
        $msg .= "source is $src" if($src);
        $msg .= " and " if($src && $dst);
        $msg .= "destination is $dst" if($dst);
        return $msg;
    }
    push @{$md}, @{$tmpmd};
    foreach my $m(@{$md}){
        my $et = $m->get_event_type($filters->event_type());
        if($stat){
            my $summ = $et->get_summary('statistics', 0);
            next unless($summ);
            my $data = $summ->get_data();
            return $summ->error if($summ->error);
            foreach my $d(@{$data}){
                if($d->val && ref($d->val) eq 'HASH' && exists $d->val->{$stat}){
                    #convert to seconds for higher level check
                    $stats->add_data($d->val->{$stat}/$units);
                }
            }
        }else{
            my $data = $et->get_data();
            return $et->error if($et->error);
            foreach my $d(@{$data}){
                if($as_percentage){
                    $stats->add_data($d->val * 100);
                }else{
                    $stats->add_data($d->val);
                }
            }
        }
    }
    
    return '';  
}

sub get_compare_data {
    my ($self, $md, $stat, $stats) = @_;
    foreach my $m(@{$md}){
        my $et = $m->get_event_type('histogram-owdelay');
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
}

__PACKAGE__->meta->make_immutable;

1;