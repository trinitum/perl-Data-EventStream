package Data::EventStream::TimeWindow;
use Moose;
our $VERSION = "0.01";
$VERSION = eval $VERSION;
with 'Data::EventStream::Window';
use Data::EventStream::Clock;

has size => ( is => 'ro', required => 1 );

has clock => ( is => 'ro', default => sub { Data::EventStream::MonotonicClock->new; } );

sub enqueue {
    my ( $self, $event ) = @_;
    for my $proc ( $self->all_processors ) {
        $proc->accumulate($event);
    }
    $self->push_event($event);
    $self->dequeue_old_events();
}

sub dequeue_old_events {
    my $self        = shift;
    my $events      = $self->events;
    my $low_barrier = $self->clock->get_time - $self->size;
    my @evictees;
    $DB::single = 1 if $self->clock->get_time > 350;
    while ( @$events && $events->[0]->time <= $low_barrier ) {
        push @evictees, shift @$events;
    }
    if (@evictees) {
        for my $proc ( $self->all_processors ) {
            $proc->compensate(@evictees);
        }
    }
    if (@$events) {
        $self->clock->set_alarm(
            $events->[0]->time + $self->size,
            sub { $self->dequeue_old_events },
        );
    }
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;
