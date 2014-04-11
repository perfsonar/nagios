package perfSONAR_PS::ServiceChecks::Commands::NagiosTracerouteCmd;

use Moose;
use Nagios::Plugin;
use Statistics::Descriptive;
use perfSONAR_PS::ServiceChecks::TracerouteCheck;
use perfSONAR_PS::ServiceChecks::Parameters::CheckParameters;

our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Commands::NagiosCmd';

=head1 NAME

perfSONAR_PS::ServiceChecks::Commands::NagiosTracerouteCmd

=head1 DESCRIPTION

A nagios command for analyzing the unique number of packet traces returned by traceroute
or tracepath. It works with both MAs implementing the REST API and older MAs implementing 
the SOAP interface.

=cut

sub build_plugin {
    my $self = shift;
    my $np = Nagios::Plugin->new( shortname => $self->nagios_name,
                              usage => "Usage: %s -u|--url <service-url> -s|--source <source-addr> -d|--destination <dest-addr> -r <number-seconds-in-past> -w|--warning <threshold> -c|--critical <threshold> -t|--timeout <timeout>",
                              timeout => $self->timeout);

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
    $np->add_arg(spec => "r|range=i",
                 help => "Time range (in seconds) in the past to look at data. i.e. 60 means look at last 60 seconds of data.",
                 required => 1 );
    $np->add_arg(spec => "w|warning=s",
                 help => "threshold of path count that leads to WARNING status",
                 required => 1 );
    $np->add_arg(spec => "c|critical=s",
                 help => "threshold of path count that leads to CRITICAL status",
                 required => 1 );

    return $np;
}

sub build_check {
    my ($self, $np) = @_;
    return new perfSONAR_PS::ServiceChecks::TracerouteCheck();
}

sub build_check_parameters {
    my ($self, $np) = @_;
    return new perfSONAR_PS::ServiceChecks::Parameters::CheckParameters(
        'ma_url' => $np->opts->{'u'},
        'source' => $np->opts->{'s'},
        'destination' => $np->opts->{'d'},
        'time_range' => $np->opts->{'r'},
        'timeout' => $np->opts->{'timeout'},
    );
}

1;
