package perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCmd;

use Moose;
use Nagios::Plugin;
use Statistics::Descriptive;
use perfSONAR_PS::ServiceChecks::SimpleEventTypeCheck;
use perfSONAR_PS::ServiceChecks::Parameters::CheckParameters;

our $VERSION = 3.4;

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
                                  usage => "Usage: %s -u|--url <service-url> -s|--source <source-addr> -d|--destination <dest-addr> -b|--bidirectional --digits <significant-digits> -r <number-seconds-in-past> -w|--warning <threshold> -c|--critical <threshold> -t|timeout <timeout>" );

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
    return $np;
};

override 'build_check' => sub {
    my ($self, $np) = @_;
    return new perfSONAR_PS::ServiceChecks::SimpleEventTypeCheck(event_type => $self->event_type);
};

override 'build_check_parameters' => sub {
    my ($self, $np) = @_;
    return new perfSONAR_PS::ServiceChecks::Parameters::CheckParameters(
        'ma_url' => $np->opts->{'u'},
        'source' => $np->opts->{'s'},
        'destination' => $np->opts->{'d'},
        'time_range' => $np->opts->{'r'},
        'bidirectional' => $np->opts->{'b'},
        'timeout' => $np->opts->{'timeout'}
    );
};

1;
