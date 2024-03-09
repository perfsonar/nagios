package perfSONAR_PS::ServiceChecks::Commands::NagiosOwdelayCmd;

use Mouse;
use Nagios::Plugin;
use Statistics::Descriptive;
use perfSONAR_PS::ServiceChecks::OWDelayCheck;
use perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters;

our $VERSION = 3.4;

=head1 NAME

perfSONAR_PS::ServiceChecks::Commands::NagiosOwdelayCmd

=head1 DESCRIPTION

A nagios command for analyzing one-way delay and loss data. It works with both MAs 
implementing the REST API and older MAs implementing the SOAP interface. It supports loss
only for historical purposes. Also, for older SOAP MAs only the min and max quantiles
will match data as the SOAP interface never implemented any of the other stats.

=cut

extends 'perfSONAR_PS::ServiceChecks::Commands::NagiosCmd';


use constant DELAY_LABEL => 'ms';
use constant DELAY_FIELD => 'min_delay';
use constant DELAY_SCALE => 1000;
use constant DELAY_STRING => {
    'min_delay' => 'minimum delay',
    'max_delay' => 'maximum delay',
    'median_delay' => 'median delay',
    'mean_delay' => 'mean delay',
    'p25_delay' => '25th percentile of delay',
    'p75_delay' => '75th percentile of delay',
    'p95_delay' => '95th percentile of delay',
};
use constant LOSS_LABEL => 'pps';
use constant LOSS_LABEL_LONG => ' packets per session';
use constant LOSS_PERCENT_LABEL => '%';
use constant LOSS_TOTAL_LABEL => ' packets';
use constant LOSS_FIELD => 'loss';
use constant LOSS_SCALE => 1;
use constant LOSS_STRING => 'Loss';
use constant DEFAULT_MEMD_ADDR => 'localhost:11211';
use constant DEFAULT_MEMD_EXP => 300;
use constant DEFAULT_MEMD_COMPRESS_THRESH => 1000000;
use constant STAT_TYPE_AVERAGE => 'average';
use constant STAT_TYPE_TOTAL => 'total';

has 'stat_type' => (is => 'rw', isa => 'Str', default => sub{ return STAT_TYPE_AVERAGE; }); 

override 'build_plugin' => sub {
    my $self = shift;
    
    my $np = Nagios::Plugin->new( shortname => $self->nagios_name,
                              timeout => $self->timeout,
                              version => $VERSION,
                              usage => "Usage: %s <options>" );

    $np->add_arg(spec => "u|url=s",
                 help => "URL of the MA service to contact",
                 required => 1 );
    $np->add_arg(spec => "s|source=s",
                 help => "Source of the test to check",
                 required => 0 );
    $np->add_arg(spec => "d|destination=s",
                 help => "Destination of the test to check",
                 required => 0 );
    $np->add_arg(spec => "a|agent=s",
                 help => "The IP or hostname of the measurement agent that initiated the test.",
                 required => 0 );
    $np->add_arg(spec => "b|bidirectional",
                 help => "Indicates that test should be checked in each direction.",
                 required => 0 );
    $np->add_arg(spec => "q|quantile=s",
                 help => "The delay metric to analyze. Valid values are min, max, median, p25, p75 and p95. Default is min.",
                 required => 0 );
    $np->add_arg(spec => "l|loss",
                 help => "Look at packet loss instead of delay as primary statistic.",
                 required => 0 );
    $np->add_arg(spec => "p|percentage",
                 help => "Express loss as percentage in output and input parameters are interpreted as percentage.",
                 required => 0 );
    $np->add_arg(spec => "r|range=i",
                 help => "Time range (in seconds) in the past to look at data. i.e. 60 means look at last 60 seconds of data.",
                 required => 1 );
    $np->add_arg(spec => "digits=i",
                 help => "Sets the number of significant digits reported after the decimal in results. Must be greater than 0. Defaults to 3.",
                 required => 0 );
    $np->add_arg(spec => "w|warning=s",
                 help => "threshold of delay (" . $self->units . ") that leads to WARNING status. In loss mode this is average packets lost as an number. If -p is specified in addition to -l, then number must be 0-100 (inclusive) and will be interpreted as a percentage.",
                 required => 1 );
    $np->add_arg(spec => "c|critical=s",
                 help => "threshold of delay (" . $self->units . ") that leads to CRITICAL status. In loss mode this is average packets lost as an integer. If -p is specified in addition to -l, then number must be 0-100 (inclusive) and will be interpreted as a percentage.",
                 required => 1 );
    $np->add_arg(spec => "m|memcached=s",
                 help => "Address of server in form <address>:<port> where memcached runs. Set to 'none' if want to disable memcached. Defaults to localhost:11211",
                 required => 0 );
    $np->add_arg(spec => "e|memcachedexp=s",
                 help => "Time when you want memcached data to expire in seconds. Defaults to lesser of 5 minutes and -r option if not set.",
                 required => 0 );
    $np->add_arg(spec => "compare",
                 help => "Compare the one-way delay of each direction and alarm on that. This alarm is a state in addition to the primary stat of one-way delay or loss.",
                 required => 0 );
    $np->add_arg(spec => "compare_quantile",
                 help => "If --compare is set, the delay metric to analyze. Valid values are min, max, median, p25, p75 and p95. Default is min.",
                 required => 0 );
    $np->add_arg(spec => "compare_mindelay=s",
                 help => "If --compare is set, only alarm on delays where both directions are above this threshold (in ms). Default 0.",
                 required => 0 );
    $np->add_arg(spec => "compare_mindelaydelta=s",
                 help => "If --compare is set, only alarm on delays when the difference between each direction is above this value (in ms). Default 0. ",
                 required => 0 );
    $np->add_arg(spec => "compare_maxdelaydeltafactor=s",
                 help => "If --compare is set, alarm if the difference in delays is this percentage bigger in one direction. (e.g. 1 means one direction is 100% bigger than the other (i.e. double). Default 10.",
                 required => 0 );     
    $np->add_arg(spec => "4",
                 help => "Only analyze IPv4 tests",
                 required => 0 );
    $np->add_arg(spec => "6",
                 help => "Only analyze IPv6 tests",
                 required => 0 );
    $np->add_arg(spec => "tool=s",
                 help => "the name of the tool used to perform measurements.",
                 required => 0 );
    $np->add_arg(spec => "filter=s@",
                 help => "Custom filters in the form of key:value that can be matched against test parameters. Can be specified multiple times.",
                 required => 0 );
    $np->add_arg(spec => "total",
                 help => "Do not average results, look at them as a total count",
                 required => 0 );

    return $np;
};

override 'build_check' => sub {
    my ($self, $np) = @_;
    my $memd_addr = $np->opts->{'m'};
    if(!$memd_addr){
        $memd_addr = DEFAULT_MEMD_ADDR;
    }
    my $memd  = q{};
    if(lc($memd_addr) ne 'none' ){
        $memd  = new Cache::Memcached {
            'servers' => [ $memd_addr ],
            'debug' => 0,
            'compress_threshold' => DEFAULT_MEMD_COMPRESS_THRESH,
        };
    }
    my $memd_expire_time = $np->opts->{'e'};
    if(!$memd_expire_time){
        $memd_expire_time = DEFAULT_MEMD_EXP;
        if($np->opts->{'r'} < $memd_expire_time){
            $memd_expire_time = $np->opts->{'r'};
        }
    }
    
    return new perfSONAR_PS::ServiceChecks::OWDelayCheck(memd => $memd, memd_expire_time => $memd_expire_time);
};

override 'build_check_parameters' => sub {
    my ($self, $np) = @_;
    my $metric = DELAY_FIELD;
    my $metric_label = DELAY_LABEL;
    my $metric_label_long = DELAY_LABEL;
    my $metric_scale = DELAY_SCALE;
    my $metric_string = DELAY_STRING->{$metric};
    if($np->opts->{'l'}){
        $metric = LOSS_FIELD;
        if($np->opts->{'total'} && $np->opts->{'p'}){
            $np->nagios_die("You cannot specify both --total and -p");
        }elsif($np->opts->{'total'}){
            $self->stat_type(STAT_TYPE_TOTAL);
            $self->default_digits(0);
            $metric_label = LOSS_TOTAL_LABEL;
            $metric_label_long = LOSS_TOTAL_LABEL;
        }elsif($np->opts->{'p'}){
            $metric_label = LOSS_PERCENT_LABEL;
            $metric_label_long = LOSS_PERCENT_LABEL;
        }else{
            $metric_label = LOSS_LABEL;
            $metric_label_long = LOSS_LABEL_LONG;
        }
        $metric_scale = LOSS_SCALE;
        $metric_string = LOSS_STRING;
    }elsif($np->opts->{'q'}){
        $metric = $np->opts->{'q'} . '_delay';
        $metric_string = DELAY_STRING->{$metric};
        $np->nagios_die("Unknown metric " . $metric) unless($metric_string);
    }
    if($np->opts->{'compare_quantile'}){
        $np->nagios_die("Unknown compare quantile " . $np->opts->{'compare_quantile'}) unless(DELAY_STRING->{ $np->opts->{'compare_quantile'} . '_delay'});
    }
    
    $self->units($metric_label);
    $self->units_long_name($metric_label_long);
    $self->metric_name($metric_string);
    $self->metric_scale($metric_scale);
    my $ip_type = 'v4v6';
    if($np->opts->{'4'}){
        $ip_type = 'v4';
    }elsif($np->opts->{'6'}){
        $ip_type = 'v6';
    }
    
    my $latency_params = new perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters(
        'ma_url' => $np->opts->{'u'},
        'source' => $np->opts->{'s'},
        'destination' => $np->opts->{'d'},
        'measurement_agent' => $np->opts->{'a'},
        'time_range' => $np->opts->{'r'},
        'bidirectional' => $np->opts->{'b'},
        'timeout' => $np->opts->{'timeout'},
        'metric' => $metric,
        'as_percentage' => $np->opts->{'p'},
        'ip_type' => $ip_type,
        'tool_name' => $np->opts->{'tool'},
        'custom_filters' => $np->opts->{'filter'},
    );
    $latency_params->compare($np->opts->{'compare'}) if($np->opts->{'compare'});
    $latency_params->compare_quantile($np->opts->{'compare_quantile'}) if($np->opts->{'compare_quantile'});
    $latency_params->compare_mindelay($np->opts->{'compare_mindelay'}) if($np->opts->{'compare_mindelay'});
    $latency_params->compare_mindelaydelta($np->opts->{'compare_mindelaydelta'}) if($np->opts->{'compare_mindelaydelta'});
    $latency_params->compare_maxdelaydeltafactor($np->opts->{'compare_maxdelaydeltafactor'}) if($np->opts->{'compare_maxdelaydeltafactor'});
    
    return $latency_params;
};

override 'get_stat' => sub {
    my ($self, $stats) = @_;
    
    if($self->stat_type() eq STAT_TYPE_TOTAL){
        $self->units(LOSS_TOTAL_LABEL);
        return ('Total', ($stats->sum() * $self->metric_scale) );
    }
    
    return super();
};


__PACKAGE__->meta->make_immutable;

1;
