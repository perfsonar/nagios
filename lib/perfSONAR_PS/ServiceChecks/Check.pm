package perfSONAR_PS::ServiceChecks::Check;

use Moose;
use Moose::Util::TypeConstraints;
use Cache::Memcached;

=head1 NAME

perfSONAR_PS::ServiceChecks::Check

=head1 DESCRIPTION

A base class for a check. A check is something that implements do_check and returns
a Statistics::Descriptive object filled with requested data. This an abstract class and it
should never be directly instantiated. The subclasses will implement the logic. It provides
facilities for doing client caching with memcached which is useful for some checks but is 
not required to be utilized. 

=cut

class_type 'CacheMemcached', { class => 'Cache::Memcached' };

has 'memd' => (is => 'rw', isa => 'CacheMemcached | Undef');
has 'memd_expire_time' => (is => 'rw', isa => 'Int', default => sub { 300 });

sub do_check {
    #my ($self, parameters) = @_;
    #return ($result_msg, $stats);
    die "Must override do_check";
}

1;