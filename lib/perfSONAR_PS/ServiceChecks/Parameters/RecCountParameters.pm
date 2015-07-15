package perfSONAR_PS::ServiceChecks::Parameters::RecCountParameters;

use Mouse;

extends 'perfSONAR_PS::ServiceChecks::Parameters::CheckParameters';

has 'protocol' => (is => 'rw', isa => 'Str|Undef');
has 'event_type' => (is => 'rw', isa => 'Str|Undef');

__PACKAGE__->meta->make_immutable;

1;
