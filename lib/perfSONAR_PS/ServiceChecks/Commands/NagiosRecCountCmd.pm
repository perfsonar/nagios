package perfSONAR_PS::ServiceChecks::Commands::NagiosRecCountCmd;

use Mouse;
use Nagios::Plugin;
use Statistics::Descriptive;
use perfSONAR_PS::ServiceChecks::RecordsCountCheck;
use perfSONAR_PS::ServiceChecks::Parameters::RecCountParameters;

our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Commands::NagiosCmd';

=head1 NAME

perfSONAR_PS::ServiceChecks::Commands::NagiosRecCountCmd;

=head1 DESCRIPTION

A nagios command for checking number of throughput records.
It does not work with both MAs implementing the 
REST API and older MAs implementing the SOAP interface.
ONLY with REST API

=cut

use constant DEFAULT_MEMD_ADDR => '127.0.0.1:11211';
use constant DEFAULT_MEMD_EXP => 300;
use constant DEFAULT_MEMD_COMPRESS_THRESH => 1000000;

override 'build_plugin' => sub {
    my $self = shift;
    my $np = Nagios::Plugin->new( shortname => $self->nagios_name,
                              timeout => $self->timeout,
                              usage => "Usage: %s -u|--url <service-url> -s|--source <source-addr> -d|--destination <dest-addr> -r <number-seconds-in-past> --type (bw|owd|rttd|loss|trcrt) -w|--warning <threshold> -c|--critical <threshold> <options>" );

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
    $np->add_arg(spec => "p|protocol=s",
                 help => "The protocol used by the test to check (e.g. TCP or UDP)",
                 required => 0 );
    $np->add_arg(spec => "b|bidirectional",
                 help => "Indicates that test should be checked in each direction. With bidirectional set on, the check expects that data is found for both directions otherwise fails!",
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
    $np->add_arg(spec => "tool=s",
                 help => "the name of the tool used to perform measurements (e.g. bwctl/iperf3, gridftp)",
                 required => 0 );
    $np->add_arg(spec => "filter=s@",
                 help => "Custom filters in the form of key:value that can be matched against test parameters. Can be specified multiple times.",
                 required => 0 );
	$np->add_arg(spec => "type=s",
                 help => "Type of test to check for: bw = throughput, owd = latency, rttd = roundrobin-trip-time, trcrt = traceroute, loss = packet-count-lost",
                 required => 1 );
                 
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
     
    return new perfSONAR_PS::ServiceChecks::RecordsCountCheck(memd => $memd, memd_expire_time => $memd_expire_time);
	
};

override 'get_stat' => sub {
    my $self = shift;
    my $stats = shift;
    
    return ( 'Total', ($stats->mean() * $self->metric_scale) );
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

    my $event_type;
	eventypesw:{
		if ($np->opts->{'type'} eq "bw" )	{ $event_type = "throughput"; last eventypesw; }
		if ($np->opts->{'type'} eq "owd" ) { $event_type = "histogram-owdelay"; last eventypesw; }
		if ($np->opts->{'type'} eq "rttd" ) { $event_type = "histogram-rtt"; last eventypesw; }
		if ($np->opts->{'type'} eq "trcrt" ) { $event_type = "packet-trace"; last eventypesw; }
		if ($np->opts->{'type'} eq "loss" ) { $event_type = "packet-count-lost"; last eventypesw; }
		{ $event_type = "unimplemented event type"; }
	}
	
	
    return new perfSONAR_PS::ServiceChecks::Parameters::RecCountParameters(
        'ma_url' => $np->opts->{'u'},
        'source' => $np->opts->{'s'},
        'destination' => $np->opts->{'d'},
        'measurement_agent' => $np->opts->{'a'},
        'time_range' => $np->opts->{'r'},
        'bidirectional' => $np->opts->{'b'},
        'timeout' => $np->opts->{'timeout'},
        'protocol' => $np->opts->{'p'},
        'ip_type' => $ip_type,
        'tool_name' => $np->opts->{'tool'},
        'event_type' => $event_type,
        'custom_filters' => $np->opts->{'filter'},
    );
};

__PACKAGE__->meta->make_immutable;

1;
