#!/usr/bin/perl -w

use strict;
use warnings;

our $VERSION = 3.3;

=head1 NAME

check_ls_probe.pl

=head1 DESCRIPTION

NAGIOS/RSV plugin to check perfSONAR LS services.  

=head1 SYNOPSIS

NAGIOS/RSV plugin to check running LS instances for both:

 1) Liveness (e.g. EchoRequest message)
 2) Database access (e.g. LSQueryRequest message)
 
NAGIOS Output:

  OK:       If the service passes both checks
  WARNING:  If the service is alive, but the database check fails
  CRITICAL: If both checks fail
  UNKNOWN:  Unexpected result

RSV (Brief) Display:

  RSV BRIEF RESULTS
  OK
  Service functioning normally
  Service http://HOST:9995/perfSONAR_PS/services/hLS is functioning normally and has responded to an Echo Request and a Data Request.

RSV (WLCG) Display:

  metricType: status
  serviceType: perfsonar-hLS
  metricName: net.perfsonar.service.hls
  metricStatus: OK|WARNING|CRITICAL|UNKNOWN
  summaryData: SUMMARY MESSAGE
  voName: VONAME
  serviceURI: LS URI, e.q. http://HOST:9995/perfSONAR_PS/services/hLS
  gatheredAt: OPERATING HOST
  timestamp: 2011-03-03T04:48:33Z
  serviceVersion: >= 3.1
  probeVersion: 3.2.1-1
  detailsData: MULTI-LINE DETAILS
  EOT
       
=cut

use FindBin qw($Bin);
use lib "$Bin/../lib/";

use perfSONAR_PS::Common qw( find findvalue );
use perfSONAR_PS::Client::LS;
use perfSONAR_PS::Transport;
use perfSONAR_PS::Utils::ParameterValidation;

use Sys::Hostname;
use English qw( -no_match_vars );
use Getopt::Long;
use XML::LibXML;
use LWP::Simple;
use Data::Validate::IP qw(is_ipv4 is_ipv6);
use Socket;

my %NAGIOS_API_ECODES = ( 'OK' => 0, 'WARNING' => 1, 'CRITICAL' => 2, 'UNKNOWN' => 3 );

my %RSV_API_VALUE = ( 'metricType' => "status", 'serviceType' => "perfsonar-hLS", 'metricName' => "net.perfsonar.service.hls", 'serviceVersion' => ">= 3.1", 'probeVersion' => $VERSION );

# Grab a timestamp as the script starts
my ( $sec, $min, $hour, $day, $month, $year ) = ( gmtime( time ) )[ 0, 1, 2, 3, 4, 5, 6 ];
$year  += 1900;
$month += 1;
my $timestamp = sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ", $year, $month, $day, $hour, $min, $sec;

our %opts = ();
my $ok = GetOptions(
    'h|help'     => \$opts{HELP},
    'l|list'     => \$opts{LIST},
    'm|metric=s' => \$opts{METRIC},
    'u|uri=s'    => \$opts{URL},
    'wlcg'       => \$opts{RSV_WLCG}
);

# default handling case is NAGIOS, we need to use the -m flag to force RSV
my $NAGIOS = 1;

# default RSV output is "Brief", we need to use the --wlcg flag to force old format
my $RSV_BRIEF = 1;

if ( defined $opts{HELP} or not defined $opts{URL} or not $ok ) {
    print printHelp() and exit $NAGIOS_API_ECODES{UNKNOWN};
}

if ( defined $opts{LIST} ) {
    print printList() and exit $NAGIOS_API_ECODES{UNKNOWN};
}

if ( defined $opts{METRIC} ) {
    if ( $opts{METRIC} eq "all" or $opts{METRIC} eq $RSV_API_VALUE{metricName} ) {

        # use RSV output
        $NAGIOS = 0;
    }
    else {
        print printList() and exit $NAGIOS_API_ECODES{UNKNOWN};
    }
}

if ( defined $opts{RSV_WLCG} ) {
    if ( $NAGIOS ) {
        print printHelp() and exit $NAGIOS_API_ECODES{UNKNOWN};
    }
    else {

        # use RSV WLCG format
        $RSV_BRIEF = 0;
    }
}

my $msg  = q{};
my $code = $NAGIOS_API_ECODES{OK};

my $ls = new perfSONAR_PS::Client::LS( { instance => $opts{URL} } );
my ( $host, $port, $endpoint ) = &perfSONAR_PS::Transport::splitURI( $opts{URL} );
my $contact = get_ip_and_host( $host );

my $query = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
$query = "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n";
$query = "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n";
$query .= "/nmwg:store[\@type=\"LSStore-summary\"]//psservice:accessPoint[text()=\"http://" . $contact->{"hostname"} . ":" . $port . $endpoint . "\"]\n";

my $result = $ls->queryRequestLS( { query => $query, format => 1, eventType => "http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/discovery/xquery/2.0" } );
if ( not defined $result ) {
    if ( $NAGIOS ) {

        # NAGIOS Output
        $code = $NAGIOS_API_ECODES{CRITICAL};
        $msg  = "Service is not responding.\n";
    }
    else {

        # RSV Output
        $code = 1;
        if ( $RSV_BRIEF ) {
            $msg = printRSVBrief( { metricStatus => "CRITICAL", summaryData => "Service is not responding", detailsData => "Service $opts{URL} is not responding to perfSONAR requests." } );
        }
        else {
            $msg = printRSVWLCG( { metricStatus => "CRITICAL", summaryData => "Service is not responding", voName => "USATLAS", serviceURI => $opts{URL}, timestamp => $timestamp, detailsData => "Service $opts{URL} is not responding to perfSONAR requests." } );
        }
    }
}
elsif ( $result->{eventType} =~ m/^error/mx ) {

    # try the other possibility - the hLS registered w/ IP or HostName.
    $query = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
    $query = "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n";
    $query = "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n";
    $query .= "/nmwg:store[\@type=\"LSStore-summary\"]//psservice:accessPoint[text()=\"http://" . $contact->{"ip"} . ":" . $port . $endpoint . "\"]\n";

    my $result2 = $ls->queryRequestLS( { query => $query, format => 1, eventType => "http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/discovery/xquery/2.0" } );
    if ( not defined $result2 ) {
        if ( $NAGIOS ) {

            # NAGIOS Output
            $code = $NAGIOS_API_ECODES{CRITICAL};
            $msg  = "Service is not responding.\n";
        }
        else {

            # RSV Output
            $code = 1;
            if ( $RSV_BRIEF ) {
                $msg = printRSVBrief( { metricStatus => "CRITICAL", summaryData => "Service is not responding", detailsData => "Service $opts{URL} is not responding to perfSONAR requests." } );
            }
            else {
                $msg = printRSVWLCG( { metricStatus => "CRITICAL", summaryData => "Service is not responding", voName => "USATLAS", serviceURI => $opts{URL}, timestamp => $timestamp, detailsData => "Service $opts{URL} is not responding to perfSONAR requests." } );
            }
        }
    }
    elsif ( $result2->{eventType} =~ m/^error/mx ) {
        if ( $NAGIOS ) {

            # NAGIOS Output
            # warning, got an answer, not what we wanted
            $code = $NAGIOS_API_ECODES{WARNING};
            $msg  = "Service returned unexpected response.\n";
        }
        else {

            # RSV Output
            $code = 1;
            if ( $RSV_BRIEF ) {
                $msg = printRSVBrief( { metricStatus => "WARNING", summaryData => "Service returned unexpected response", detailsData => "Service $opts{URL} is active, but did not send the expected response." } );
            }
            else {
                $msg = printRSVWLCG( { metricStatus => "WARNING", summaryData => "Service returned unexpected response", voName => "USATLAS", serviceURI => $opts{URL}, timestamp => $timestamp, detailsData => "Service $opts{URL} is active, but did not send the expected response." } );
            }
        }
    }
    else {
        if ( $NAGIOS ) {

            # NAGIOS Output
            $code = $NAGIOS_API_ECODES{OK};
            $msg  = "Service functioning normally.\n";
        }
        else {

            # RSV Output
            $code = 1;
            if ( $RSV_BRIEF ) {
                $msg = printRSVBrief( { metricStatus => "OK", summaryData => "Service functioning normally", detailsData => "Service $opts{URL} is functioning normally and has responded to an Echo Request and a Data Request." } );
            }
            else {
                $msg
                    = printRSVWLCG( { metricStatus => "OK", summaryData => "Service functioning normally", voName => "USATLAS", serviceURI => $opts{URL}, timestamp => $timestamp, detailsData => "Service $opts{URL} is functioning normally and has responded to an Echo Request and a Data Request." } );
            }
        }
    }
}
else {
    if ( $NAGIOS ) {

        # NAGIOS Output
        $code = $NAGIOS_API_ECODES{OK};
        $msg  = "Service functioning normally.\n";
    }
    else {

        # RSV Output
        $code = 1;
        if ( $RSV_BRIEF ) {
            $msg = printRSVBrief( { metricStatus => "OK", summaryData => "Service functioning normally", detailsData => "Service $opts{URL} is functioning normally and has responded to an Echo Request and a Data Request." } );
        }
        else {
            $msg = printRSVWLCG( { metricStatus => "OK", summaryData => "Service functioning normally", voName => "USATLAS", serviceURI => $opts{URL}, timestamp => $timestamp, detailsData => "Service $opts{URL} is functioning normally and has responded to an Echo Request and a Data Request." } );
        }
    }
}

print $msg;
exit $code;

=head2 printHelp()

Print Help Dialog  

=cut

sub printHelp {
    my ( @args ) = @_;
    my $parameters = validateParams( @args, {} );

    my $msg = "\ncheck_ls_probe\n";
    $msg .= "probeVersion: " . $RSV_API_VALUE{probeVersion} . "\n";
    $msg .= "serviceType: " . $RSV_API_VALUE{serviceType} . "\n";
    $msg .= "serviceVersion: " . $RSV_API_VALUE{serviceVersion} . "\n\n";
    $msg .= "Probe for functional checking operational status of the";
    $msg .= " perfSONAR-PS Lookup Service.  Works with NAGIOS and RSV\n\n";
    $msg .= "Usage: $PROGRAM_NAME\n";
    $msg .= "    -u, --uri SERVICEURI\n";
    $msg .= "        Service URI. Accepted URIs are:\n";
    $msg .= "            host:port/service\n";
    $msg .= "    -m, --metric STRING\n";
    $msg .= "        Which metric to perform.\n";
    $msg .= "    -l\n";
    $msg .= "        Print WLCG-style metric list\n";
    $msg .= "    -h, --help\n";
    $msg .= "        Print help message\n";
    $msg .= "    --wlcg\n";
    $msg .= "        Output in the historic \"WLCG\" RSV format\n";
    return $msg;
}

=head2 printList()

Print list of metrics

=cut

sub printList {
    my ( @args ) = @_;
    my $parameters = validateParams( @args, {} );

    my $msg = "serviceType: " . $RSV_API_VALUE{serviceType} . "\n";
    $msg .= "metricName: " . $RSV_API_VALUE{metricName} . "\n";
    $msg .= "metricType: " . $RSV_API_VALUE{metricType} . "\n";
    $msg .= "EOT\n";
    return $msg;
}

=head2 printRSVBrief()

Print RSV (Brief) formated data.  

=cut

sub printRSVBrief {
    my ( @args ) = @_;
    my $parameters = validateParams( @args, { metricStatus => 1, summaryData => 1, detailsData => 1 } );

    my $msg = "RSV BRIEF RESULTS:\n";
    $msg .= $parameters->{metricStatus} . "\n";
    $msg .= $parameters->{summaryData} . "\n";
    $msg .= $parameters->{detailsData} . "\n";
    return $msg;
}

=head2 printRSVWLCG()

Print RSV (WLCG) formated data.  

=cut

sub printRSVWLCG {
    my ( @args ) = @_;
    my $parameters = validateParams( @args, { metricStatus => 1, summaryData => 1, voName => 0, serviceURI => 1, timestamp => 1, detailsData => 1 } );

    my $msg = "metricType: " . $RSV_API_VALUE{metricType} . "\n";
    $msg .= "serviceType: " . $RSV_API_VALUE{serviceType} . "\n";
    $msg .= "metricName: " . $RSV_API_VALUE{metricName} . "\n";
    $msg .= "metricStatus: " . $parameters->{metricStatus} . "\n";
    $msg .= "summaryData: " . $parameters->{summaryData} . "\n";
    $msg .= "voName: " . $parameters->{voName} . "\n" if $parameters->{voName};
    $msg .= "serviceURI: " . $parameters->{serviceURI} . "\n";
    $msg .= "gatheredAt: " . hostname . "\n";
    $msg .= "timestamp: " . $parameters->{timestamp} . "\n";
    $msg .= "serviceVersion: " . $RSV_API_VALUE{serviceVersion} . "\n";
    $msg .= "probeVersion: " . $RSV_API_VALUE{probeVersion} . "\n";
    $msg .= "detailsData: " . $parameters->{detailsData} . "\n" if $parameters->{detailsData};
    $msg .= "EOT\n";
    return $msg;
}

=head2 get_ip_and_host()

Converts value into either IP or Hostname.  

=cut

sub get_ip_and_host {
    my ( $endpoint ) = @_;

    my $ip       = q{};
    my $hostname = q{};

    if ( is_ipv4( $endpoint ) ) {
        $ip = $endpoint;
        my $tmp_addr = Socket::inet_aton( $endpoint );
        if ( defined $tmp_addr and $tmp_addr ) {
            $hostname = gethostbyaddr( $tmp_addr, Socket::AF_INET );
        }
        $hostname = $endpoint unless $hostname;
    }
    elsif ( is_ipv6( $endpoint ) ) {
        $ip = $endpoint;

        #try to lookup v6 record?
        $hostname = $endpoint;
    }
    else {

        #if not ipv4 or ipv6 then assume a hostname
        $hostname = $endpoint;
        my $packed_ip = gethostbyname( $endpoint );
        if ( defined $packed_ip and $packed_ip ) {
            $ip = inet_ntoa( $packed_ip );
        }
        $ip = $endpoint unless $ip;
    }
    return { 'ip' => $ip, 'hostname' => $hostname };
}

__END__

=head1 SEE ALSO

L<Sys::Hostname>, L<English>, L<Getopt::Long>, L<XML::LibXML>, L<LWP::Simple>,
L<Data::Validate::IP>, L<Socket>, L<perfSONAR_PS::Common>,
L<perfSONAR_PS::Client::LS>, L<perfSONAR_PS::Transport>,
L<perfSONAR_PS::Utils::ParameterValidation>

To join the 'perfSONAR Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id$

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu
Sowmya Balasubramanian, sowmya@es.net
Andrew Lake, andy@es.net

=head1 LICENSE

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 COPYRIGHT

Copyright (c) 2004-2011, Internet2 and the University of Delaware

All rights reserved.

=cut
