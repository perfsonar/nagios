package perfSONAR_PS::ServiceChecks::Parameters::LatencyParameters;

use Mouse;

extends 'perfSONAR_PS::ServiceChecks::Parameters::CheckParameters';

has 'metric' => (is => 'rw', isa => 'Str');
has 'as_percentage' => (is => 'rw', isa => 'Bool', default => sub { 1 });
has 'compare' => (is => 'rw', isa => 'Bool', default => sub { 1 });
has 'compare_mindelay' => (is => 'rw', isa => 'Num', default => sub { 0 });
has 'compare_mindelaydelta' => (is => 'rw', isa => 'Num', default => sub { 0 });
has 'compare_maxdelaydeltafactor' => (is => 'rw', isa => 'Num', default => sub { 10 });
has 'compare_quantile' => (is => 'rw', isa => 'Str', default => sub { 'min' });

__PACKAGE__->meta->make_immutable;

1;
