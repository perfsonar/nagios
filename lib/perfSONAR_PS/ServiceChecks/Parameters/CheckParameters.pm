package perfSONAR_PS::ServiceChecks::Parameters::CheckParameters;

use Mouse;

=head1 NAME

perfSONAR_PS::ServiceChecks::Parameters::CheckParameters

=head1 DESCRIPTION

A base class with standard parameters for an MA check such as URL, source, destination
and other. This may be instantiated directly or extended if additional parameters are 
required for a check.

=cut

has 'ma_url' => (is => 'rw', isa => 'Str');
has 'source' => (is => 'rw', isa => 'Str|Undef');
has 'destination' => (is => 'rw', isa => 'Str|Undef');
has 'time_range' => (is => 'rw', isa => 'Int');
has 'bidirectional' => (is => 'rw', isa => 'Bool', default => sub { 0 });
has 'timeout' => (is => 'rw', isa => 'Int', default => sub { 60 });
has 'ip_type' => (is => 'rw', isa => 'Str', default => sub { 'v4v6' });


__PACKAGE__->meta->make_immutable;

1;
