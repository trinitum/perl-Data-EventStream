package Data::EventStream::TimeBatchWindow;
use Moose;
our $VERSION = "0.02";
$VERSION = eval $VERSION;
with 'Data::EventStream::Window';
use Data::EventStream::Clock;

has batch_start_time => ( is => 'ro', writer => '_set_batch_start_time', default => 0 );

has size => ( is => 'ro', required => 1 );

has clock => ( is => 'ro', default => sub { Data::EventStream::MonotonicClock->new; } );

sub enqueue {
    my ( $self, $event ) = @_;
    $_->accumulate($event) for $self->all_processors;
    $self->push_event($event);
    $self->dequeue_old_events();
}

sub dequeue_old_events {
    my $self   = shift;
    my $events = $self->events;

    my $batch_start_time = $self->batch_start_time;
    my $batch_size       = $self->size;
    my $batch_end_time   = $batch_start_time + $batch_size;

    if ( @$events and $batch_end_time <= $events->[0]->time ) {
        my $n = int( ( $events->[0]->time - $batch_start_time ) / $batch_size );
        $batch_start_time += $n * $batch_size;
        $batch_end_time = $batch_start_time + $batch_size;
        $self->_set_batch_start_time($batch_start_time);
    }

    if ( $batch_end_time <= $self->clock->time ) {
        my @evictees;
        while ( @$events && $events->[0]->time < $batch_end_time ) {
            push @evictees, shift @$events;
        }
        $_->compensate(@evictees) for $self->all_processors;
        $_->reset for $self->all_processors;
        $self->_set_batch_start_time($batch_end_time);
    }

    $self->clock->set_alarm(
        $self->batch_start_time + $self->size,
        sub { $self->dequeue_old_events },
    );
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;
