package perfSONAR_PS::ServiceChecks::Commands::NagiosThroughputCmd;

use Moose;
use Nagios::Plugin;
use Statistics::Descriptive;
use perfSONAR_PS::ServiceChecks::ThroughputCheck;
use perfSONAR_PS::ServiceChecks::Parameters::ThroughputParameters;

our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Commands::NagiosCmd';

=head1 NAME

perfSONAR_PS::ServiceChecks::Commands::NagiosThroughputCmd

=head1 DESCRIPTION

A nagios command for analyzing throughput data. It works with both MAs implementing the 
REST API and older MAs implementing the SOAP interface.

=cut

use constant DEFAULT_MEMD_ADDR => '127.0.0.1:11211';
use constant DEFAULT_MEMD_EXP => 300;
use constant DEFAULT_MEMD_COMPRESS_THRESH => 1000000;

override 'build_plugin' => sub {
    my $self = shift;
    my $np = Nagios::Plugin->new( shortname => $self->nagios_name,
                              timeout => $self->timeout,
                              usage => "Usage: %s -u|--url <service-url> -s|--source <source-addr> -d|--destination <dest-addr> -b|--bidirectional -r <number-seconds-in-past> -w|--warning <threshold> -c|--critical <threshold> -v|--verbose -p|--protocol <protocol> --t|timeout <timeout> --digits <significant-digits> -m|memcached <server> -e|memcachedexp <expiretime> -4 -6" );

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
    $np->add_arg(spec => "p|protocol=s",
                 help => "The protocol used by the test to check (e.g. TCP or UDP)",
                 required => 0 );
    $np->add_arg(spec => "b|bidirectional",
                 help => "Indicates that test should be checked in each direction.",
                 required => 0 );
    $np->add_arg(spec => "r|range=i",
                 help => "Time range (in seconds) in the past to look at data. i.e. 60 means look at last 60 seconds of data.",
                 required => 1 );
    $np->add_arg(spec => "digits=i",
                 help => "Sets the number of significant digits reported after the decimal in results. Must be greater than 0. Defaults to 3.",
                 required => 0 );
    $np->add_arg(spec => "w|warning=s",
                 help => "threshold of bandwidth (in " . $self->units . ") that leads to WARNING status",
                 required => 1 );
    $np->add_arg(spec => "c|critical=s",
                 help => "threshold of bandwidth (in " . $self->units . ") that leads to CRITICAL status",
                 required => 1 );
    $np->add_arg(spec => "m|memcached=s",
                 help => "Address of server in form <address>:<port> where memcached runs. Set to 'none' if want to disable memcached. Defaults to 127.0.0.1:11211",
                 required => 0 );
    $np->add_arg(spec => "e|memcachedexp=s",
                 help => "Time when you want memcached data to expire in seconds. Defaults to lesser of 5 minutes and -r option if not set.",
                 required => 0 );
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
    my $memd_addr = $np->opts->{'m'};
    if(!$memd_addr){
        $memd_addr = DEFAULT_MEMD_ADDR;
    }
    my $memd = undef;
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
     
    return new perfSONAR_PS::ServiceChecks::ThroughputCheck(memd => $memd, memd_expire_time => $memd_expire_time);
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
    
    return new perfSONAR_PS::ServiceChecks::Parameters::ThroughputParameters(
        'ma_url' => $np->opts->{'u'},
        'source' => $np->opts->{'s'},
        'destination' => $np->opts->{'d'},
        'time_range' => $np->opts->{'r'},
        'bidirectional' => $np->opts->{'b'},
        'timeout' => $np->opts->{'timeout'},
        'protocol' => $np->opts->{'p'},
        'ip_type' => $ip_type,
    );
};

1;
