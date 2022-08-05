#!/usr/bin/perl

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use Nagios::Plugin;
use JSON;

use perfSONAR_PS::Utils::HTTPS qw(https_get);

my $np = Nagios::Plugin->new(
	shortname => 'check_toolkit',
	timeout   => 60,
	usage     =>
"Usage: %s -u|--url <main URL of the Toolkit> -d|--domain <dns domain of the record> -f|file <file containing list of LS urls> -g|--groupcommunities<groups or communities> --key <key> -s|--service <service-type> -t|--type <type of record> -u|--url <serviceglsURL>  --value <value> -v|--verbose  -w|--warning <warning-threshold>"
);

$np->add_arg(
	spec     => "u|url=s",
	help     => "URL for the Toolkit",
	required => 1
);

$np->add_arg(
	spec     => "N|check_ntp_synchronization",
	help     => "Make sure NTP is synchronized on the host",
	required => 0
);

$np->add_arg(
	spec     => "s|check_services_running",
	help     => "Make sure the services that aren't disabled are all running",
	required => 0
);

$np->add_arg(
	spec     => "r|check_registered",
	help     => "Make sure the host is registered",
	required => 0
);

$np->add_arg(
	spec     => "w|warning",
	help     => "Warn if one of the specified checks fails, instead of going critical",
	required => 0
);

$np->add_arg(
	spec     => "v|verbose",
	help     => "allow verbose mode for debugging",
	required => 0
);

$np->getopts;

my $url              = $np->opts->{'u'};
my $check_ntp        = $np->opts->{'N'};
my $check_services   = $np->opts->{'s'};
my $check_registered = $np->opts->{'r'};
my $warn_on_failure  = $np->opts->{'w'};
my $verbose          = $np->opts->{'v'};


$url .= "?format=json";

my ($status, $res) = https_get(url => $url, max_redirects => 5);
if ($status != 0) {
    $np->nagios_exit( CRITICAL, "Problem retrieving $url: $res" );
}

my $json_str = $res;

my $json;
eval {
    $json = JSON->new->decode($json_str);
};
if ($@) {
    $np->nagios_exit( CRITICAL, "Problem parsing json for $url: ".$@);
}

my $code = OK;
my $msg  = "";

if ($check_ntp) {
    if ($json->{ntp} and $json->{ntp}->{synchronized}) {
        $msg .= " NTP: Synchronized";
    }
    elsif ($json->{ntp}) {
        $msg .= " NTP: Unsynchronized";
        my $new_code = ($warn_on_failure?WARNING:CRITICAL);

        $code = $new_code if $code eq OK or $code eq WARNING;
    }
    else {
        $msg .= " NTP: Unknown";
        $code = WARNING if $code eq OK;
    }
}

if ($check_registered) {
    if ($json->{globally_registered}) {
        $msg .= " LS: Registered";
    }
    elsif (defined $json->{globally_registered}) {
        $msg .= " LS: Unregistered";
        my $new_code = ($warn_on_failure?WARNING:CRITICAL);

        $code = $new_code if $code eq OK or $code eq WARNING;
    }
    else {
        $msg .= " LS: Unknown";
        $code = WARNING if $code eq OK;
    }
}

if ($check_services) {
    if ($json->{services}) {
        foreach my $service (@{ $json->{services} }) {
            next if ($service->{is_running} eq "disabled" or $service->{is_running} eq "yes");

            $msg .= " Service ".$service->{name}." down.";

            my $new_code = ($warn_on_failure?WARNING:CRITICAL);

            $code = $new_code if $code eq OK or $code eq WARNING;
        }
    }
    else {
        $msg .= " Services: Unknown";
        $code = WARNING if $code eq OK;
    }
}

#exit the module with appropriate return values
$np->nagios_exit( $code, $msg );
