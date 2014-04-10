package perfSONAR_PS::ServiceChecks::Check;

use Moose;
use Moose::Util::TypeConstraints;
use Cache::Memcached;

class_type 'CacheMemcached', { class => 'Cache::Memcached' };

has 'memd' => (is => 'rw', isa => 'CacheMemcached | Undef');
has 'memd_expire_time' => (is => 'rw', isa => 'Int', default => sub { 300 });

sub do_check {
    #my ($self, $ma_url, $src, $dst, $time_int, $bidir, $protocol, $timeout) = @_;
    #return ($result_code, $stats);
    die "Must override do_check";
}

1;