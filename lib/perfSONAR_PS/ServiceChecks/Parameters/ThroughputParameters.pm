package perfSONAR_PS::ServiceChecks::Parameters::ThroughputParameters;

use Moose;

extends 'perfSONAR_PS::ServiceChecks::Parameters::CheckParameters';

has 'protocol' => (is => 'rw', isa => 'Str|Undef');

1;
