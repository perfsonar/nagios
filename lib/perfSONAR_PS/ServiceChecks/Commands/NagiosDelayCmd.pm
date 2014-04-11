package perfSONAR_PS::ServiceChecks::Commands::NagiosDelayCmd;

use Moose;
use Nagios::Plugin;
use Statistics::Descriptive;
use perfSONAR_PS::ServiceChecks::DelayCheck;
use perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters;

our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Commands::NagiosCmd';

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

sub build_plugin {
    my $self = shift;
    
    my $np = Nagios::Plugin->new( shortname => $self->nagios_name,
                              timeout => $self->timeout,
                              usage => "Usage: %s -u|--url <service-url> -s|--source <source-addr> -d|--destination <dest-addr> -b|--bidirectional --digits <significant-digits> -r <number-seconds-in-past> -w|--warning <threshold> -c|--critical <threshold> -t|timeout <timeout> -q|quantile <quantile>" );

    #get arguments
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
    $np->add_arg(spec => "r|range=i",
                 help => "Time range (in seconds) in the past to look at data. i.e. 60 means look at last 60 seconds of data.",
                 required => 1 );
    $np->add_arg(spec => "q|quantile=s",
                 help => "The delay metric to analyze. Valid values are min, max, median, p25, p75 and p95. Default is min.",
                 required => 0 );
    $np->add_arg(spec => "digits=i",
                 help => "Sets the number of significant digits reported after the decimal in results. Must be greater than 0. Defaults to 3.",
                 required => 0 );
    $np->add_arg(spec => "w|warning=s",
                 help => "threshold of delay (" . $self->units . ") that leads to WARNING status.",
                 required => 1 );
    $np->add_arg(spec => "c|critical=s",
                 help => "threshold of delay (" . $self->units . ") that leads to CRITICAL status.",
                 required => 1 );

    return $np;
}

sub build_check {
    my ($self, $np) = @_;
    return new perfSONAR_PS::ServiceChecks::DelayCheck();
}

sub build_check_parameters {
    my ($self, $np) = @_;
    #set metric
    my $metric = DELAY_FIELD;
    if($np->opts->{'q'}){
        $metric = $np->opts->{'q'} . '_delay';
    }
    my $metric_string = DELAY_STRING->{$metric};
    unless($metric_string){
         $np->nagios_die("Unknown metric " . $metric);
    }
    $self->metric_name($metric_string);
    
    return new perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters(
        'ma_url' => $np->opts->{'u'},
        'source' => $np->opts->{'s'},
        'destination' => $np->opts->{'d'},
        'time_range' => $np->opts->{'r'},
        'bidirectional' => $np->opts->{'b'},
        'timeout' => $np->opts->{'timeout'},
        'metric' => $metric,
    );
}

1;
