package perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters;

use Mouse;

extends 'perfSONAR_PS::ServiceChecks::Parameters::CheckParameters';

has 'metric' => (is => 'rw', isa => 'Str');
has 'as_percentage' => (is => 'rw', isa => 'Bool', default => sub { 1 });

__PACKAGE__->meta->make_immutable;

1;
