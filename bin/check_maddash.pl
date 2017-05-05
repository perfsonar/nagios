#!/usr/bin/perl

use Nagios::Plugin;
use URI::Escape;
use LWP::UserAgent;
use JSON;

=head1 NAME

check_maddash.pl

=head1 DESCRIPTION

A nagios check that contacts that contacts the MaDDash/MaDAlert report interface and 
creates alarms based on result

=cut

#create plugin
my $np = Nagios::Plugin->new( shortname => "MADDASH",
                              timeout => 30,
                              usage => "Usage: %s <options>" );

#parse opts
$np->add_arg(spec => "u|url=s",
                 help => "The URL of maddash server creating the report. Usually ends in /maddash.",
                 required => 1 );
$np->add_arg(spec => "x|external=s",
                 help => "The URL of an external maddash server that has the grid. Usually ends in /maddash. Defaults to value of -u if not specified.",
                 required => 0 );
$np->add_arg(spec => "g|grid=s",
                 help => "The name of the grid to check",
                 required => 1 );
$np->add_arg(spec => "s|site=s",
                 help => "The label of the row/column to check",
                 required => 0 );
$np->getopts;


#checkopts

#init various urls and vars
my $base_url = $np->opts->{'u'};
$base_url .= '/' if( $base_url !~ /\/$/);
my $remote_url = $np->opts->{'x'};
my $site = $np->opts->{'s'};

#determine proper url
my $report_url = "";
if($remote_url){
    #remote grid
    $remote_url .= '/' if( $remote_url !~ /\/$/);
    my $grid_url = $remote_url . "grids/" . uri_escape($np->opts->{'g'});
    $report_url = $base_url . "report?json=" . $grid_url;
}else{
    #local grid
    $report_url = $base_url . "report/?grid=" .  uri_escape($np->opts->{'g'});
}

#contact server
my $ua = LWP::UserAgent->new;
$ua->timeout(30);
$ua->env_proxy();
my $response = $ua->get($report_url);
if (!$response->is_success){
    $np->nagios_die("Error contacting server: " . $response->status_line);    
}
my $json_result = '';
eval { $json_result = decode_json($response->content); };
$np->nagios_die("Error parsing server response: " . $@) if($@);

#parse result
my $serverity = 0;
my $msg = "";
my $stats = [];
my $problems = [];
if($site){
    $np->nagios_die("Invalid result: JSON missing 'sites' field") unless(exists $json_result->{'sites'} && $json_result->{'sites'});
    $np->nagios_die("Invalid result: Unable to find report for $site. Verify you specified the name correctly and that it is in the grid") unless(exists $json_result->{'sites'}->{$site} && $json_result->{'sites'}->{$site});
    $np->nagios_die("Invalid result: Unable to find severity in report for $site.") unless(exists $json_result->{'sites'}->{$site}->{'severity'});
    $serverity = $json_result->{'sites'}->{$site}->{'severity'};
    $problems = $json_result->{'sites'}->{$site}->{'problems'} if(exists $json_result->{'sites'}->{$site}->{'problems'});
    $stats = $json_result->{'sites'}->{$site}->{'stats'} if(exists $json_result->{'sites'}->{$site}->{'stats'});
}else{
    $np->nagios_die("Invalid result: JSON missing 'global' field") unless(exists $json_result->{'global'} && $json_result->{'global'});
    $np->nagios_die("Invalid result: Unable to find severity in report.") unless(exists $json_result->{'global'}->{'severity'});
    $serverity = $json_result->{'global'}->{'severity'};
    $problems = $json_result->{'global'}->{'problems'} if(exists $json_result->{'global'}->{'problems'});
    $stats = $json_result->{'global'}->{'stats'} if(exists $json_result->{'global'}->{'stats'});
}
foreach my $problem(@{$problems}){
    $msg .= "," if($msg);
    $msg .= '[' . $problem->{'category'} . '] ' if(exists $problem->{'category'} && $problem->{'category'});
    $msg .= $problem->{'name'} if(exists $problem->{'name'} && $problem->{'name'});
}

#generate output
my $retcode;
if($serverity == 0){
    $retcode = OK;
    $msg = "No problems to report" unless ($msg);
}elsif($serverity == 1){
    $retcode = WARN;
}elsif($serverity == 2){
    $retcode = CRITICAL;
}else{
    $retcode = UNKNOWN;
}

if($stats && @{$stats} == 4){
    $np->add_perfdata(
            label => 'OK_COUNT',
            value => $stats->[0],
        );
    $np->add_perfdata(
            label => 'WARN_COUNT',
            value => $stats->[1],
        );
    $np->add_perfdata(
            label => 'CRITICAL_COUNT',
            value => $stats->[2],
        );
    $np->add_perfdata(
            label => 'UNKNOWN_COUNT',
            value => $stats->[3],
        );
}
$np->nagios_exit($retcode, $msg);