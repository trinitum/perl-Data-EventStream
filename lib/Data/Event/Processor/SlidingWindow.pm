package Data::Event::Processor::SlidingWindow;
use Moose;

has size => ( is => 'ro', required => 1 );

has processors => (
    is      => 'ro',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        all_processors => 'elements',
        add_processor  => 'push',
    },
);

has events => (
    is      => 'ro',
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        push_event   => 'push',
        shift_event  => 'shift',
        count_events => 'count',
    }
);

sub enqueue {
    my ( $self, $event ) = @_;
    for my $proc ( $self->all_processors ) {
        $proc->accumulate($event);
    }
    $self->push_event($event);
    if ( $self->count_events > $self->size ) {
        my $evictee = $self->shift_event;
        for my $proc ( $self->all_processors ) {
            $proc->compensate($evictee);
        }
    }
}

1;
