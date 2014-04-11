package perfSONAR_PS::ServiceChecks::OWDelayCheck;

use Moose;

our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Check';

use perfSONAR_PS::ServiceChecks::PSBOWDelayCheck;
use perfSONAR_PS::ServiceChecks::EsmondOWDelayCheck;

override 'do_check' => sub {
    my ($self, $params) = @_;
    
    my $check;
    if($params->ma_url =~ /\/perfSONAR_PS\/services\/pSB\/*$/){
        $check = new perfSONAR_PS::ServiceChecks::PSBOWDelayCheck(memd => $self->memd, memd_expire_time => $self->memd_expire_time);
    }else{
        $check = new perfSONAR_PS::ServiceChecks::EsmondOWDelayCheck(memd => $self->memd, memd_expire_time => $self->memd_expire_time);
    }
    
    return $check->do_check($params);
};

1;