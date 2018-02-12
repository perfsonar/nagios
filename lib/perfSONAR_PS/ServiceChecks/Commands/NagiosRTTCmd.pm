package perfSONAR_PS::ServiceChecks::Commands::NagiosRTTCmd;

use Mouse;
use Nagios::Plugin;
use Statistics::Descriptive;
use perfSONAR_PS::ServiceChecks::RTTCheck;
use perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters;

our $VERSION = 4.1;

=head1 NAME

perfSONAR_PS::ServiceChecks::Commands::NagiosRTTCmd

=head1 DESCRIPTION

A nagios command for analyzing rtt (aka round-trip time) returned by tools such as ping.
Currently only works with MAs implementing the MA REST API. It does NOT work with older 
MAs such a PinGER running the SOAP interface

=cut

extends 'perfSONAR_PS::ServiceChecks::Commands::NagiosCmd';

use constant RTT_FIELD => 'min_rtt';
use constant RTT_STRING => {
    'min_rtt' => 'minimum rtt',
    'max_rtt' => 'maximum rtt',
    'median_rtt' => 'median rtt',
    'mean_rtt' => 'mean rtt',
    'p25_rtt' => '25th percentile of rtt',
    'p75_rtt' => '75th percentile of rtt',
    'p95_rtt' => '95th percentile of rtt',
};

override 'build_plugin' => sub {
    my $self = shift;
    
    my $np = Nagios::Plugin->new( shortname => $self->nagios_name,
                              timeout => $self->timeout,
                              version => $VERSION,
                              usage => "Usage: %s <options>" );

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
    $np->add_arg(spec => "a|agent=s",
                 help => "The IP or hostname of the measurement agent that initiated the test.",
                 required => 0 );
    $np->add_arg(spec => "b|bidirectional",
                 help => "Indicates that test should be checked in each direction.",
                 required => 0 );
    $np->add_arg(spec => "r|range=i",
                 help => "Time range (in seconds) in the past to look at data. i.e. 60 means look at last 60 seconds of data.",
                 required => 1 );
    $np->add_arg(spec => "q|quantile=s",
                 help => "The rtt metric to analyze. Valid values are min, max, median, p25, p75 and p95. Default is min.",
                 required => 0 );
    $np->add_arg(spec => "digits=i",
                 help => "Sets the number of significant digits reported after the decimal in results. Must be greater than 0. Defaults to 3.",
                 required => 0 );
    $np->add_arg(spec => "w|warning=s",
                 help => "threshold of rtt (" . $self->units . ") that leads to WARNING status.",
                 required => 1 );
    $np->add_arg(spec => "c|critical=s",
                 help => "threshold of rtt (" . $self->units . ") that leads to CRITICAL status.",
                 required => 1 );
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

    return $np;
};

override 'build_check' => sub {
    my ($self, $np) = @_;
    return new perfSONAR_PS::ServiceChecks::RTTCheck();
};

override 'build_check_parameters' => sub {
    my ($self, $np) = @_;
    #set metric
    my $metric = RTT_FIELD;
    if($np->opts->{'q'}){
        $metric = $np->opts->{'q'} . '_rtt';
    }
    my $metric_string = RTT_STRING->{$metric};
    unless($metric_string){
         $np->nagios_die("Unknown metric " . $metric);
    }
    $self->metric_name($metric_string);
    #set ipv4 and ipv6 parameters
    my $ip_type = 'v4v6';
    if($np->opts->{'4'}){
        $ip_type = 'v4';
    }elsif($np->opts->{'6'}){
        $ip_type = 'v6';
    }
    
    return new perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters(
        'ma_url' => $np->opts->{'u'},
        'source' => $np->opts->{'s'},
        'destination' => $np->opts->{'d'},
        'measurement_agent' => $np->opts->{'a'},
        'time_range' => $np->opts->{'r'},
        'bidirectional' => $np->opts->{'b'},
        'timeout' => $np->opts->{'timeout'},
        'metric' => $metric,
        'ip_type' => $ip_type,
        'tool_name' => $np->opts->{'tool'},
        'custom_filters' => $np->opts->{'filter'},
    );
};

__PACKAGE__->meta->make_immutable;

1;
