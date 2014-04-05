package Data::EventStream::TimedEvent;
use Moose;
use Time::HiRes qw();

has time => ( is => 'ro', default => sub { Time::HiRes::time } );
has data => ( is => 'ro', required => 1 );

no Moose;
__PACKAGE__->meta->make_immutable;

1;
