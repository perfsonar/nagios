package perfSONAR_PS::ServiceChecks::RecordsCountCheck;

use Mouse;

our $VERSION = 3.4;

extends 'perfSONAR_PS::ServiceChecks::Check';
use constant ENABLE_PSB => 0;

use if ENABLE_PSB, 'perfSONAR_PS::ServiceChecks::PSBThroughputCheck';
use perfSONAR_PS::ServiceChecks::EsmondRecCountCheck;

override 'do_check' => sub {
    my ($self, $params) = @_;
    
    my $check;
    if($params->ma_url =~ /\/perfSONAR_PS\/services\/pSB\/*$/){
	      return ("This check does not support pre 3.4 perfSONAR releases");
#        $check = new perfSONAR_PS::ServiceChecks::PSBThroughputCheck(memd => $self->memd, memd_expire_time => $self->memd_expire_time);
    }else{
        $check = new perfSONAR_PS::ServiceChecks::EsmondRecCountCheck(memd => $self->memd, memd_expire_time => $self->memd_expire_time);
    }
    
    return $check->do_check($params);
};

__PACKAGE__->meta->make_immutable;

1;