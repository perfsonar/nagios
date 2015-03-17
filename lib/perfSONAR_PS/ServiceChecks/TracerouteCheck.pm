package perfSONAR_PS::ServiceChecks::TracerouteCheck;

use Mouse;

our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Check';
use constant ENABLE_PSB => 0;

use if ENABLE_PSB, 'perfSONAR_PS::ServiceChecks::PSBTracerouteCheck';
use perfSONAR_PS::ServiceChecks::EsmondTracerouteCheck;

override 'do_check' => sub {
    my ($self, $params) = @_;
    
    my $check;
    if($params->ma_url =~ /\/perfSONAR_PS\/services\/tracerouteMA\/*$/){
        $check = new perfSONAR_PS::ServiceChecks::PSBTracerouteCheck(memd => $self->memd, memd_expire_time => $self->memd_expire_time);
    }else{
        $check = new perfSONAR_PS::ServiceChecks::EsmondTracerouteCheck(memd => $self->memd, memd_expire_time => $self->memd_expire_time);
    }
    
    return $check->do_check($params);
};

__PACKAGE__->meta->make_immutable;

1;