#!/usr/bin/perl

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use Nagios::Plugin;
use perfSONAR_PS::Common qw( find findvalue );
use SimpleLookupService::QueryObjects::QueryObject;
use SimpleLookupService::QueryObjects::QueryObjectFactory;
use SimpleLookupService::Client::SimpleLS;
use perfSONAR_PS::Client::LS::PSClient::PSQuery;

my $np = Nagios::Plugin->new(
	shortname => 'check_sls',
	timeout   => 60,
	usage     =>
"Usage: %s -c|--critical <critical-threshold> --key <key> -t|--type <type of record> -u|--url <serviceglsURL>  --value <value> -v|--verbose  -w|--warning <warning-threshold>"
);

#get arguments
$np->add_arg(
	spec     => "c|critical=s",
	help     => "threshold to show critical state",
	required => 1
);

$np->add_arg(
	spec     => "key=s",
	help     => "the key in key-value to be searched",
	required => 0
);

$np->add_arg(
	spec     => "t|type=s",
	help     => "type of record",
	required => 0
);

$np->add_arg(
	spec     => "u|url=s",
	help     => "URL of the sLS to contact",
	required => 0
);

$np->add_arg(
	spec     => "w|warning=s",
	help     => "threshold to show warning state",
	required => 1
);

$np->add_arg(
	spec     => "value=s",
	help     => "the value in key-value to be searched",
	required => 0
);

$np->add_arg(
	spec     => "v|verbose",
	help     => "allow verbose mode for debugging",
	required => 0
);

$np->getopts;

my $cThresh  = $np->opts->{'c'};
my $key = $np->opts->{'key'};
my $recordType = $np->opts->{'t'};
my $slsURL     = $np->opts->{'u'};
my $wThresh    = $np->opts->{'w'};
my $value    = $np->opts->{'value'};
my $verbose    = $np->opts->{'v'};

#result variable - default is 0
my $service_count = 0;
my $msg;

if (  (!defined $slsURL || $slsURL eq '' )) {
	print "Please specify LS URL or hints file \n";
	exit(1);
}

if((defined $key && !defined $value) || (!defined $key && defined $value)){
	print "Please specify key and value \n";
	exit(1);
}

my $host;
my $port;
if ( $slsURL ne '' ) {
	my $uri = URI->new($slsURL);
	$host = $uri->host;
	$port = $uri->port;
}

my $server = SimpleLookupService::Client::SimpleLS->new();
$server->setUrl($slsURL);
$server->connect();

if($verbose){
	print $server->getStatus, "--", $server->getLatency, "\n";	
}


if ( $server->getStatus eq 'alive' ) {
	my $queryObj;
	if ( defined $recordType && $recordType ne '' ) {
		$queryObj =SimpleLookupService::QueryObjects::QueryObjectFactory->instantiate($recordType);
		$queryObj->init();
	
		if($queryObj->getRecordType eq ''){
			$queryObj->setRecordType($recordType);
		}
		
	}
	else {
		$queryObj = SimpleLookupService::QueryObjects::QueryObject->new();
		$queryObj->init();
	}
	
	if(defined $key && defined $value){
		$queryObj->addField({key=>$key,value=>$value});
	}
	

	if($verbose){
		print $queryObj->toURLParameters, "\n";
	}
	
	my $client = perfSONAR_PS::Client::LS::PSClient::PSQuery->new();
	$client->init( { server => $server, query => $queryObj } );
	my $res = $client->query();

	my @recordArray = @{$res};

	$service_count = scalar @recordArray;
}

#add service count to output
$np->add_perfdata(
	'label' => 'RECORDS_COUNT',
	'value' => $service_count
);

# check thresholds and set return values
my $code = $np->check_threshold(
	check    => $service_count,
	warning  => $wThresh,
	critical => $cThresh,
);

if ( $code eq OK ) {
	$msg = "Records found in LS";
}
elsif ( $code eq WARNING || $code eq CRITICAL ) {
	$msg = "Low record count";
}
else {
	$msg = "Error analyzing results";
}

#exit the module with appropriate return values
$np->nagios_exit( $code, $msg );
