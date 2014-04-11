package perfSONAR_PS::ServiceChecks::Commands::NagiosCmd;

use Moose;
use Nagios::Plugin;
use Statistics::Descriptive;

our $VERSION = 3.4;

has 'nagios_name' => (is => 'rw', isa => 'Str');
has 'metric_name' => (is => 'rw', isa => 'Str', default => sub{ 'metric' });
has 'units' => (is => 'rw', isa => 'Str', default => sub{ '' });
has 'units_long_name' => (is => 'rw', isa => 'Str|Undef');
has 'unit_prefix' => (is => 'rw', isa => 'Str', default => sub{ '' });
has 'metric_scale' => (is => 'rw', isa => 'Num', default => sub { 1 });
has 'timeout' => (is => 'rw', isa => 'Int', default => sub { 60 });
has 'default_digits' => (is => 'rw', isa => 'Int', default => sub { 3 });

sub build_plugin {
    die "build_plugin must be overridden"
}

sub build_check {
    die "build_check must be overridden"
}

sub build_check_parameters {
    die "build_check_parameters must be overridden"
}

sub run{
    my $self = shift;
    
    my $np = $self->build_plugin();
    $np->getopts;                              

    #call client
    my $checker = $self->build_check($np);
    my $parameters = $self->build_check_parameters($np);
    my ($result, $stats);
    eval{
        ($result, $stats) = $checker->do_check($parameters);
    };
    if($@){
        $np->nagios_die("Error with underlying check: " . $@);
    }elsif($result){
        $np->nagios_die($result);
    }elsif($stats->count() == 0 ){
        my $errMsg = "No data returned";
        $errMsg .= " for direction where" if($np->opts->{'s'} || $np->opts->{'d'});
        $errMsg .= " src=" . $np->opts->{'s'} if($np->opts->{'s'});
        $errMsg .= " dst=" . $np->opts->{'d'} if($np->opts->{'d'});
        $np->nagios_die($errMsg);
    }

    # format nagios output
    my $digits = $self->default_digits;
    if(defined $np->opts->{'digits'} && $np->opts->{'digits'} ne '' && $np->opts->{'digits'} >= 0){
        $digits = $np->opts->{'digits'};
    }
    
    $np->add_perfdata(
            label => 'Count',
            value => $stats->count(),
        );
    $np->add_perfdata(
            label => 'Min',
            value => $stats->min() * $self->metric_scale,
        );
    $np->add_perfdata(
            label => 'Max',
            value => $stats->max() * $self->metric_scale,
        );
    $np->add_perfdata(
            label => 'Average',
            value => $stats->mean() * $self->metric_scale,
        );
    $np->add_perfdata(
            label => 'Standard_Deviation',
            value => $stats->standard_deviation() * $self->metric_scale,
        );

    my $code = $np->check_threshold(
         check => $stats->mean() * $self->metric_scale,
         warning => $np->opts->{'w'},
         critical => $np->opts->{'c'},
       );

    my $msg = "";   
    if($code eq OK || $code eq WARNING || $code eq CRITICAL){
        $msg = "Average " . $self->metric_name . " is " . sprintf("%.${digits}f", ($stats->mean() * $self->metric_scale)) . $self->unit_prefix . (defined $self->units_long_name ? $self->units_long_name : $self->units);
    }else{
        $msg = "Error analyzing results";
    }
    $np->nagios_exit($code, $msg);
}

1;
