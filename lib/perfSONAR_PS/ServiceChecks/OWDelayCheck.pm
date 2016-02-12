package perfSONAR_PS::ServiceChecks::OWDelayCheck;

use Mouse;

our $VERSION = 3.4;
use perfSONAR_PS::ServiceChecks::EsmondOWDelayCheck;
extends 'perfSONAR_PS::ServiceChecks::Check';

override 'do_check' => sub {
    my ($self, $params) = @_;
    
    my $check = new perfSONAR_PS::ServiceChecks::EsmondOWDelayCheck(memd => $self->memd, memd_expire_time => $self->memd_expire_time);
    
    return $check->do_check($params);
};

__PACKAGE__->meta->make_immutable;

1;