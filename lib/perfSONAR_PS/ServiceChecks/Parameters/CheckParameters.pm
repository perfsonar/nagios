package perfSONAR_PS::ServiceChecks::Parameters::CheckParameters;

use Moose;

has 'ma_url' => (is => 'rw', isa => 'Str');
has 'source' => (is => 'rw', isa => 'Str');
has 'destination' => (is => 'rw', isa => 'Str');
has 'time_range' => (is => 'rw', isa => 'Int');
has 'bidirectional' => (is => 'rw', isa => 'Bool', default => sub { 0 });
has 'timeout' => (is => 'rw', isa => 'Int', default => sub { 60 });

1;
