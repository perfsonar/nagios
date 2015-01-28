package perfSONAR_PS::ServiceChecks::Commands::NagiosCmd;

use Mouse;
use Nagios::Plugin;
use Statistics::Descriptive;

our $VERSION = 3.4;

=head1 NAME

perfSONAR_PS::ServiceChecks::Commands::NagiosCmd

=head1 DESCRIPTION

Base class for writing a Nagios command. Provides hooks for defining command-line 
parameters, building class to perform the check and parsing the results. This class
is abstract and should never be instantiated directly. Its main function 'run' compares
thresholds on an average value calculated from a series of numbers.

=cut

has 'nagios_name' => (is => 'rw', isa => 'Str'); 
has 'metric_name' => (is => 'rw', isa => 'Str', default => sub{ 'metric' });
has 'units' => (is => 'rw', isa => 'Str', default => sub{ '' });
has 'units_long_name' => (is => 'rw', isa => 'Str|Undef');
has 'unit_prefix' => (is => 'rw', isa => 'Str', default => sub{ '' });
has 'metric_scale' => (is => 'rw', isa => 'Num', default => sub { 1 });
has 'timeout' => (is => 'rw', isa => 'Int', default => sub { 60 });
has 'default_digits' => (is => 'rw', isa => 'Int', default => sub { 3 });

=head2 build_plugin()

Returns a Nagios::Plugin. Subclasses should construct an initial Nagios::Plugin
in this class with the desired command-line options.
=cut
sub build_plugin {
    die "build_plugin must be overridden"
}

=head2 build_check($np)

Given the Nagios::Plugin object created by build_plugin, this method creates the subclass 
of perfSONAR_PS::ServiceChecks::Check that will be used to perform the actual check
=cut
sub build_check {
    die "build_check must be overridden"
}

=head2 build_check_parameters($np)

Given the Nagios::Plugin object created by build_plugin, this method creates the subclass 
of perfSONAR_PS::ServiceChecks::Parameters::CheckParamaters that will be passed to the 
object created by build_check()
=cut
sub build_check_parameters {
    die "build_check_parameters must be overridden"
}

=head2 run($np)

The main logic that builds, runs and analyzes the check results. It compares the given
thresholds to the average of a Statistics::Descriptive class returned by a 
perfSONAR_PS::ServiceChecks::Check->doCheck() call.
=cut
sub run{
    my $self = shift;
    
    my $np = $self->build_plugin();
    $np->getopts;                              

    #call client
    my $checker = $self->build_check($np);
    my $parameters = $self->build_check_parameters($np);
    my ($result, $stats, $extra_code, $extra_msg, $extra_stats);
    eval{
        ($result, $stats, $extra_stats, $extra_code, $extra_msg) = $checker->do_check($parameters);
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
    
    if($extra_stats){
        foreach my $stat_label(keys %{$extra_stats}){
            $np->add_perfdata(
                label => $stat_label,
                value => $extra_stats->{$stat_label},
            );
        }
    }
        
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
    
    if($extra_code && $code eq OK){
        $code = $extra_code;
        $msg = $extra_msg;
    }
    
    $np->nagios_exit($code, $msg);
}

__PACKAGE__->meta->make_immutable;

1;
