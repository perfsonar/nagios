#!/usr/bin/perl

use strict;
use warnings;

our $VERSION = 3.3;

=head1 NAME

check_ps_version.pl

=head1 DESCRIPTION

NAGIOS check of the version of a perfSONAR toolkit host. 

=head1 SYNOPSIS

NAGIOS plugin to check the version of a toolkit host. Looks in the hLS for the 
pS-NPToolkit-${version} keyword. Checks the ping service for now since all hosts have that.
Display:

  OK:       If the tooklit version registered matches the input version
  WARNING:  If the toolkit version differs from that input
  CRITICAL: If the toolkit version differs from that input and -c is specified
           
=cut

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use Nagios::Plugin;
use perfSONAR_PS::Common qw( find findvalue );
use perfSONAR_PS::Client::LS;
use XML::LibXML;
use LWP::Simple;


my $np = Nagios::Plugin->new( shortname => 'PS_VERSION',
                              usage => "Usage: %s -u|--url <HLS-service-url> -v|--version <required-version> -c|--critical --timeout <timeout> --debug",
                              timeout => 60);

#get arguments
$np->add_arg(spec => "u|url=s",
             help => "URL of the lookup service (hLS) to contact.",
             required => 0 );
$np->add_arg(spec => "v|version=s",
             help => "Version required for check to pass",
             required => 1 );
$np->add_arg(spec => "c|criticial",
             help => "Return CRITICAL if version does not match. Default is WARNING.",
             required => 0 );
$np->add_arg(spec=> "t|timeout=s",
             help => "time to wait for hLS to respond",
             required => 0); 
$np->add_arg(spec=> "debug",
             help => "allow verbose mode for debugging",
             required => 0); 
             
$np->getopts;

my $url = $np->opts->{'u'};
my $timeout = $np->opts->{'timeout'};
my $req_version = $np->opts->{'v'};
my $verbose = $np->opts->{'debug'} ? $np->opts->{'debug'} : '';

my $client = new perfSONAR_PS::Client::LS(
        {
               instance => $url,
               alarm_disabled => 1
        }
    );

my $NONOK_CODE = WARNING;
if($np->opts->{'c'}){
    $NONOK_CODE = CRITICAL;
}

# Create XQuery
my $serviceType = 'http://ggf.org/ns/nmwg/tools/ping/1.0'; #lowest common denominator
my $xquery='';
$xquery = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
$xquery .= "declare namespace summary=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/summarization/2.0/\";\n";
$xquery .= "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n";
$xquery .= "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n";
$xquery .= "for \$metadata in /nmwg:store[\@type=\"LSStore\"]/nmwg:metadata \n";
$xquery .= "let \$id := \$metadata/\@id \n";
$xquery .= "let \$data := /nmwg:store[\@type=\"LSStore\"]/nmwg:data[\@metadataIdRef =\$id]\n";
$xquery .= "where some \$eventType in \$data/nmwg:metadata/nmwg:eventType satisfies (\$eventType=\"$serviceType\")\n";
$xquery .= " return \$data";

if($verbose ne ''){
    print $xquery,"\n";
}

# Send query to Lookup Service
my $result = q{};
eval{
    local $SIG{ALRM} = sub {  $np->nagios_exit( UNKNOWN, "Timeout occurred while trying to contact $url"); };
    alarm $timeout;
    $result = $client->queryRequestLS(
           {
               query => $xquery,
               format => 1 #want response to be formated as XML
           }
         ) ;
    alarm 0;
};

if ($verbose ne ''){
    print $result->{response};
}

if(!$result || !$result->{response} || $result->{response} !~ /\</){
     $np->nagios_exit( UNKNOWN, "Unable to contact hLS. Please verify the URL is correct and the hLS is running.");
}

my $parser = XML::LibXML->new();
my $doc = "";
eval{
    $doc = $parser->parse_string($result->{response});
};
if($@){
    $np->nagios_exit( UNKNOWN, "Error parsing response");
}

my $root = $doc->getDocumentElement;
   
my @keywords = $root->findnodes(".//*[local-name()='parameter' and \@name='keyword']");
my $version = q{};
foreach my $keyword(@keywords){
    if(!$keyword->textContent){
        next;
    }
    
    if($keyword->textContent =~ /project:pS-NPToolkit-(.+)/){
        $version = $1;
        last if($version ne q{});
    }
}

if($version eq q{}){
    $np->nagios_exit( UNKNOWN, "No version registered for service")
}elsif(lc($version) ne lc($req_version)){
    $np->nagios_exit( $NONOK_CODE, "perfSONAR-PS Toolkit version is $version (require $req_version).")
}else{
    $np->nagios_exit( OK, "perfSONAR-PS Toolkit version is $version.")
}


