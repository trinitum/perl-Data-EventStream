package Data::Event::Processor::LengthWindow;
use Moose;
with 'Data::Event::Processor::Window';

has size => ( is => 'ro', required => 1 );

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

no Moose;

__PACKAGE__->meta->make_immutable;

1;
