package perfSONAR_PS::ServiceChecks::Parameters::ThroughputParameters;

use Mouse;

extends 'perfSONAR_PS::ServiceChecks::Parameters::CheckParameters';

has 'protocol' => (is => 'rw', isa => 'Str|Undef');
has 'udp_bandwidth' => (is => 'rw', isa => 'Str|Undef');

__PACKAGE__->meta->make_immutable;

1;
