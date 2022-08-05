package perfSONAR_PS::ServiceChecks::ThroughputCheck;

use Mouse;

our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Check';

use perfSONAR_PS::ServiceChecks::EsmondThroughputCheck;

override 'do_check' => sub {
    my ($self, $params) = @_;
    
    my $check = new perfSONAR_PS::ServiceChecks::EsmondThroughputCheck(memd => $self->memd, memd_expire_time => $self->memd_expire_time);
    
    return $check->do_check($params);
};

__PACKAGE__->meta->make_immutable;

1;