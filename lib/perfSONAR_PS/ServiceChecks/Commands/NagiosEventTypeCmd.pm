package perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCmd;

use Mouse;
use Nagios::Plugin;
use Statistics::Descriptive;
use perfSONAR_PS::ServiceChecks::SimpleEventTypeCheck;
use perfSONAR_PS::ServiceChecks::Parameters::CheckParameters;

our $VERSION = 4.1;

=head1 NAME

perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCmd

=head1 DESCRIPTION

A generic nagios command for grabbing numeric data of a given event type from an MA 
implementing the REST API. A script should instantiate this if they simply want to
grab and get the average of a single event type containing numeric data with simple
source, destination and time-range filters.

=cut

extends 'perfSONAR_PS::ServiceChecks::Commands::NagiosCmd';

has 'event_type' => (is => 'rw', isa => 'Str');

override 'build_plugin' => sub {
    my $self = shift;
    
    my $np = Nagios::Plugin->new( shortname => $self->nagios_name,
                                  timeout => $self->timeout,
                                  version => $VERSION,
                                  usage => "Usage: %s  <options>" );

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
                 help => "Time range (in seconds) in the past to look at data. e.g. 60 means look at last 60 seconds of data.",
                 required => 1 );
    $np->add_arg(spec => "digits=i",
                 help => "Sets the number of significant digits reported after the decimal in results. Must be greater than 0. Defaults to 3.",
                 required => 0 );
    $np->add_arg(spec => "w|warning=s",
                 help => "threshold of " . $self->metric_name . " (" . $self->units . ") that leads to WARNING status.",
                 required => 1 );
    $np->add_arg(spec => "c|critical=s",
                 help => "threshold of " . $self->metric_name . " (" . $self->units . ") that leads to CRITICAL status.",
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
    return new perfSONAR_PS::ServiceChecks::SimpleEventTypeCheck(event_type => $self->event_type);
};

override 'build_check_parameters' => sub {
    my ($self, $np) = @_;
    
    #set ipv4 and ipv6 parameters
    my $ip_type = 'v4v6';
    if($np->opts->{'4'}){
        $ip_type = 'v4';
    }elsif($np->opts->{'6'}){
        $ip_type = 'v6';
    }
    
    return new perfSONAR_PS::ServiceChecks::Parameters::CheckParameters(
        'ma_url' => $np->opts->{'u'},
        'source' => $np->opts->{'s'},
        'destination' => $np->opts->{'d'},
        'measurement_agent' => $np->opts->{'a'},
        'time_range' => $np->opts->{'r'},
        'bidirectional' => $np->opts->{'b'},
        'timeout' => $np->opts->{'timeout'},
        'ip_type' => $ip_type,
        'tool_name' => $np->opts->{'tool'},
        'custom_filters' => $np->opts->{'filter'},
    );
};

__PACKAGE__->meta->make_immutable;

1;
