package perfSONAR_PS::ServiceChecks::ThroughputCheck;

use Moose;

our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Check';

use perfSONAR_PS::ServiceChecks::PSBThroughputCheck;
use perfSONAR_PS::ServiceChecks::EsmondThroughputCheck;

override 'do_check' => sub {
    my ($self, $params) = @_;
    
    my $check;
    if($params->ma_url =~ /\/perfSONAR_PS\/services\/pSB\/*$/){
        $check = new perfSONAR_PS::ServiceChecks::PSBThroughputCheck(memd => $self->memd, memd_expire_time => $self->memd_expire_time);
    }else{
        $check = new perfSONAR_PS::ServiceChecks::EsmondThroughputCheck(memd => $self->memd, memd_expire_time => $self->memd_expire_time);
    }
    
    return $check->do_check($params);
};

1;