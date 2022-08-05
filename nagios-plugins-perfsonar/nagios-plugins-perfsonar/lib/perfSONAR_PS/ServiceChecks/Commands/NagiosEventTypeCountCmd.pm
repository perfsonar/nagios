package perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCountCmd;

use Mouse;
use Nagios::Plugin;
use Statistics::Descriptive;
use perfSONAR_PS::ServiceChecks::SimpleEventTypeCheck;
use perfSONAR_PS::ServiceChecks::Parameters::CheckParameters;

our $VERSION = 3.4;

=head1 NAME

perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCmd

=head1 DESCRIPTION

A generic nagios command for grabbing data of a given event type from an MA 
implementing the REST API. A script should instantiate this if they simply want to
grab and get the count of a single event type with simple
source, destination and time-range filters.

=cut

extends 'perfSONAR_PS::ServiceChecks::Commands::NagiosEventTypeCmd';

sub get_stat{
    my $self = shift;
    my $stats = shift;
    
    return ( 'Total', ($stats->count()) );
}

__PACKAGE__->meta->make_immutable;

1;
