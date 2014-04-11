package perfSONAR_PS::ServiceChecks::Commands::NagiosOwdelayCmd;

use Moose;
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
use constant LOSS_FIELD => 'loss';
use constant LOSS_SCALE => 1;
use constant LOSS_STRING => 'Loss';
use constant DEFAULT_MEMD_ADDR => '127.0.0.1:11211';
use constant DEFAULT_MEMD_EXP => 300;
use constant DEFAULT_MEMD_COMPRESS_THRESH => 1000000;

sub build_plugin {
    my $self = shift;
    
    my $np = Nagios::Plugin->new( shortname => $self->nagios_name,
                              timeout => $self->timeout,
                              usage => "Usage: %s -u|--url <service-url> -s|--source <source-addr> -d|--destination <dest-addr> -b|--bidirectional --digits <significant-digits> -r <number-seconds-in-past> -w|--warning <threshold> -c|--critical <threshold> -t|timeout <timeout> -q|quantile <quantile>" );

    $np->add_arg(spec => "u|url=s",
                 help => "URL of the MA service to contact",
                 required => 1 );
    $np->add_arg(spec => "s|source=s",
                 help => "Source of the test to check",
                 required => 0 );
    $np->add_arg(spec => "d|destination=s",
                 help => "Destination of the test to check",
                 required => 0 );
    $np->add_arg(spec => "b|bidirectional",
                 help => "Indicates that test should be checked in each direction.",
                 required => 0 );
    $np->add_arg(spec => "q|quantile=s",
                 help => "The delay metric to analyze. Valid values are min, max, median, p25, p75 and p95. Default is min.",
                 required => 0 );
    $np->add_arg(spec => "l|loss",
                 help => "Look at packet loss instead of delay.",
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
                 help => "Address of server in form <address>:<port> where memcached runs. Set to 'none' if want to disable memcached. Defaults to 127.0.0.1:11211",
                 required => 0 );
    $np->add_arg(spec => "e|memcachedexp=s",
                 help => "Time when you want memcached data to expire in seconds. Defaults to lesser of 5 minutes and -r option if not set.",
                 required => 0 );

    return $np;
}

sub build_check {
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
}

sub build_check_parameters {
    my ($self, $np) = @_;
    my $metric = DELAY_FIELD;
    my $metric_label = DELAY_LABEL;
    my $metric_label_long = DELAY_LABEL;
    my $metric_scale = DELAY_SCALE;
    my $metric_string = DELAY_STRING->{$metric};
    if($np->opts->{'l'}){
        $metric = LOSS_FIELD;
        $metric_label = ($np->opts->{'p'} ? LOSS_PERCENT_LABEL : LOSS_LABEL);
        $metric_label_long = ($np->opts->{'p'} ? LOSS_PERCENT_LABEL : LOSS_LABEL_LONG);
        $metric_scale = LOSS_SCALE;
        $metric_string = LOSS_STRING;
    }elsif($np->opts->{'q'}){
        $metric = $np->opts->{'q'} . '_delay';
        $metric_string = DELAY_STRING->{$metric};
        $np->nagios_die("Unknown metric " . $metric) unless($metric_string);
    }
    $self->units($metric_label);
    $self->units_long_name($metric_label_long);
    $self->metric_name($metric_string);
    $self->metric_scale($metric_scale);
     
    return new perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters(
        'ma_url' => $np->opts->{'u'},
        'source' => $np->opts->{'s'},
        'destination' => $np->opts->{'d'},
        'time_range' => $np->opts->{'r'},
        'bidirectional' => $np->opts->{'b'},
        'timeout' => $np->opts->{'timeout'},
        'metric' => $metric,
        'as_percentage' => $np->opts->{'p'},
    );
}

1;
