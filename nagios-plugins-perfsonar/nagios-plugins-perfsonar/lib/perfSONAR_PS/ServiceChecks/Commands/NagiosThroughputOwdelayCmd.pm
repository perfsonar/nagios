package perfSONAR_PS::ServiceChecks::Commands::NagiosThroughputOwdelayCmd;

use Mouse;
use Nagios::Plugin;
use Statistics::Descriptive;
use perfSONAR_PS::ServiceChecks::ThroughputCheck;
use perfSONAR_PS::ServiceChecks::Parameters::ThroughputParameters;
use perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters;
use perfSONAR_PS::ServiceChecks::OWDelayCheck;

our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Commands::NagiosThroughputCmd';

use constant DEFAULT_EVAL_FUNCTION => 'linear';
use constant DELAY_FIELD => 'min_delay';
use constant DELAY_STRING => {
    'min_delay' => 'minimum delay',
    'max_delay' => 'maximum delay',
    'median_delay' => 'median delay',
    'mean_delay' => 'mean delay',
    'p25_delay' => '25th percentile of delay',
    'p75_delay' => '75th percentile of delay',
    'p95_delay' => '95th percentile of delay',
};
use constant EVAL_FUNCTIONS => {
    'linear' => 1,
    'step' => 1,
};

=head1 NAME

perfSONAR_PS::ServiceChecks::Commands::NagiosThroughputOwdelayCmd

=head1 DESCRIPTION

A nagios command for analyzing throughput data using thresholds dynamically generated based on one-way delay.
It currently supports two functions for generating the thresholds:
    1. A linear function that takes an upper bound for throughput, a lower bound for throughput and a minimum delay for which lower values will always use the upper bound.
    2. A step function where you can specify tuples of delay and throughput thesholds

=cut

override 'build_plugin' => sub {
    my $self = shift;
    my $np = super();
    
    #add specific parameters
    $np->add_arg(spec => "o|min_owdelay=s",
                 help => "The minumum one-way delay value we care about. If value observed below this will just use maximum thresholds for throughput. Default is 5.",
                 required => 0,
                 default => 5 );
    $np->add_arg(spec => "owdelay_url=s",
                 help => "URL of the MA service to contact for one-way delay information. Default is the value given to -u.",
                 required => 0 );
    $np->add_arg(spec => "owdelay_source=s",
                 help => "The source address to use when querying one-way delay information. Default is the value of -s.",
                 required => 0 );
    $np->add_arg(spec => "owdelay_destination=s",
                 help => "The destination address to use when querying one-way delay information. Default is the value of -d.",
                 required => 0 );
    $np->add_arg(spec => "owdelay_range=s",
                 help => "The time range for which to query one-way delay data. Default to the value of -r.",
                 required => 0 );
    $np->add_arg(spec => "f|function=s",
                 help => "The type of function to use when evaluating thresholds. Valid values are 'step' and 'linear'. Default is 'linear'.",
                 required => 0 );   
    $np->add_arg(spec => "q|quantile=s",
                 help => "The delay metric to analyze. Valid values are min, max, median, p25, p75 and p95. Default is min.",
                 required => 0 );
    return $np;
};

sub linear_eval_function {
    my ($self, $observed_owd, $min_owd, $lower_throughput,$upper_throughput) = @_;
     
    #if not above the minimum we care about, just return
    if($observed_owd <= $min_owd){
        return $upper_throughput;
    }
    #calculate threshold
    my $threshold = $min_owd/$observed_owd*$upper_throughput + $lower_throughput;
    #if bigger than base throughput, then return base throughput
    if($threshold > $upper_throughput){
        return $upper_throughput;
    }
    
    return $threshold;
}

sub step_eval_function {
    my ($self, $observed_owd, $step_list) = @_;
    
    #find threshold
    my $err = "";
    my $threshold = "";
    my $active_step = -1;
    foreach my $step(@{$step_list}){
        my @step_parts = split ':', $step;
        if(@step_parts != 2){
            $err = "$step is not in form DELAY:THROUGHPUT_THRESHOLD";
            last;
        }
        if($step_parts[0] < $observed_owd && $step_parts[0] > $active_step){
            $active_step = $step_parts[0];
            $threshold  = $step_parts[1];
        }
    }
    
    #if none match, return error
    if(!$err && $active_step == -1){
        $err = "Step function does not have threshold that matches observed latency $observed_owd.";
    }
    
    return ($err, $threshold);
}

override 'build_check' => sub {
    my ($self, $np) = @_;
    # lookup latency and recalculate warning and critical
    my $ma_url = ($np->opts->{'owdelay_url'} ? $np->opts->{'owdelay_url'} : $np->opts->{'u'});
    my $owd_src = ($np->opts->{'owdelay_source'} ? $np->opts->{'owdelay_source'} : $np->opts->{'s'});
    my $owd_dst = ($np->opts->{'owdelay_destination'} ? $np->opts->{'owdelay_destination'} : $np->opts->{'d'});
    my $owd_range = ($np->opts->{'owdelay_range'} ? $np->opts->{'owdelay_range'} : $np->opts->{'r'});
    #set evaluation function
    my $eval_function = DEFAULT_EVAL_FUNCTION;
    if($np->opts->{'f'}){
        $eval_function = $np->opts->{'f'};
        $np->nagios_die() unless(EVAL_FUNCTIONS->{$eval_function}); 
    }
    #set ipv4 and ipv6 parameters
    my $ip_type = 'v4v6';
    if($np->opts->{'4'}){
        $ip_type = 'v4';
    }elsif($np->opts->{'6'}){
        $ip_type = 'v6';
    }
    # Set delay metric to use
    my $metric = DELAY_FIELD;
    if($np->opts->{'q'}){
        $metric = $np->opts->{'q'} . '_delay';
        $np->nagios_die("Unknown metric " . $metric) unless(DELAY_STRING->{$metric});
    }
    #build latency parameters
    my $latency_params = new perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters(
        'ma_url' => $ma_url ,
        'source' => $owd_src,
        'destination' => $owd_dst,
        'time_range' => $owd_range,
        'bidirectional' => $np->opts->{'b'},
        'timeout' => $np->opts->{'timeout'},
        'metric' => $metric,
        'as_percentage' => 0,
        'ip_type' => $ip_type,
    );
    #perform one-way delay check
    my $owd_check = new perfSONAR_PS::ServiceChecks::OWDelayCheck();
    my ($result, $stats, $extra_stats, $extra_code, $extra_msg);
    eval{
        ($result, $stats, $extra_stats, $extra_code, $extra_msg) = $owd_check->do_check($latency_params);
    };
    if($@){
        $np->nagios_die("Error with underlying one-way delay check: " . $@);
    }elsif($result){
        $np->nagios_die($result);
    }elsif($stats->count() == 0 ){
        my $errMsg = "No one-way delay data returned";
        $errMsg .= " for direction where" if($owd_src || $owd_dst);
        $errMsg .= " src=" . $owd_src if($owd_src);
        $errMsg .= " dst=" . $owd_dst if($owd_dst);
        $np->nagios_die($errMsg);
    }    
        
    #evaluate results
    my $observed_owd = sprintf("%.2f", $stats->mean() * 1000); #convert to ms
    if($eval_function eq 'step'){
        my @warn_vals = split ',', $np->opts->{'w'};
        my @crit_vals = split ',', $np->opts->{'c'};
        my $errMsg = "";
        ($errMsg, $np->opts->{'w'}) = $self->step_eval_function($observed_owd, \@warn_vals);
        $np->nagios_die("Invalid warning threshold: $errMsg") if($errMsg);
        ($errMsg, $np->opts->{'c'}) = $self->step_eval_function($observed_owd, \@crit_vals);
        $np->nagios_die("Invalid critical threshold: $errMsg") if($errMsg);
        if($np->opts->{'w'} <= $np->opts->{'c'}){
            $np->nagios_die("Invalid step function. Warning threshold must be greater than critical threshold.");
        }else{
            $np->opts->{'w'} .= ':';
            $np->opts->{'c'} .= ':';
        }
    }else{
        #linear evaluation
        my @warn_vals = split ':', $np->opts->{'w'};
        $np->nagios_die("Warning threshold must be triplet in the form of LOWER_THROUGHPUT:UPPER_THROUGHPUT") if(@warn_vals != 2);
        my @crit_vals = split ':', $np->opts->{'c'};
        $np->nagios_die("Critical threshold must be triplet in the form of LOWER_THROUGHPUT:UPPER_THROUGHPUT") if(@crit_vals != 2);
        $np->nagios_die("Warning lower bound threshold must be larger than critical lower bound threshold" ) if($warn_vals[0] <= $crit_vals[0]);
        $np->nagios_die("Warning upper bound threshold must be larger than critical upper bound threshold" ) if($warn_vals[1] <= $crit_vals[1]);
        $np->opts->{'w'} = sprintf("%.2f", $self->linear_eval_function($observed_owd, $np->opts->{'o'}, $warn_vals[0], $warn_vals[1])) . ':';
        $np->opts->{'c'} = sprintf("%.2f", $self->linear_eval_function($observed_owd, $np->opts->{'o'}, $crit_vals[0], $crit_vals[1])) . ':';
    }
    
    #add stats
    $np->add_perfdata(
            label => 'OneWayDelay',
            value => $observed_owd,
        );
    $np->add_perfdata(
            label => 'WarnThreshold',
            value => $np->opts->{'w'},
        );
    $np->add_perfdata(
            label => 'CritThreshold',
            value => $np->opts->{'c'},
        );
        
    return super();
};

__PACKAGE__->meta->make_immutable;

1;
