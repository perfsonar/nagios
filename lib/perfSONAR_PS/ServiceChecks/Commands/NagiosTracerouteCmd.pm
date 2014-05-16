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

override 'build_plugin' => sub {
    my $self = shift;
    my $np = Nagios::Plugin->new( shortname => $self->nagios_name,
                              usage => "Usage: %s -u|--url <service-url> -s|--source <source-addr> -d|--destination <dest-addr> -r <number-seconds-in-past> -w|--warning <threshold> -c|--critical <threshold> -t|--timeout <timeout> -4 -6",
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
    $np->add_arg(spec => "4",
                 help => "Only analyze IPv4 tests",
                 required => 0 );
    $np->add_arg(spec => "6",
                 help => "Only analyze IPv6 tests",
                 required => 0 );
                 
    return $np;
};

override 'build_check' => sub {
    my ($self, $np) = @_;
    return new perfSONAR_PS::ServiceChecks::TracerouteCheck();
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
        'time_range' => $np->opts->{'r'},
        'timeout' => $np->opts->{'timeout'},
        'ip_type' => $ip_type,
    );
};

1;
