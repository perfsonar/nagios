package perfSONAR_PS::ServiceChecks::RecordsCountCheck;

use Mouse;

our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Check';

use perfSONAR_PS::ServiceChecks::EsmondRecCountCheck;

override 'do_check' => sub {
    my ($self, $params) = @_;
    
    my $check = new perfSONAR_PS::ServiceChecks::EsmondRecCountCheck(memd => $self->memd, memd_expire_time => $self->memd_expire_time);
    
    return $check->do_check($params);
};

__PACKAGE__->meta->make_immutable;

1;