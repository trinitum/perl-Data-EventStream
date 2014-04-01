package Data::Event::Processor::LengthBatchWindow;
use Moose;
with 'Data::Event::Processor::Window';

has size => ( is => 'ro', required => 1 );

sub enqueue {
    my ( $self, $event ) = @_;
    $self->push_event($event);
    if ( $self->count_events == $self->size ) {
        for my $proc ( $self->all_processors ) {
            $proc->accumulate( $self->all_events );
            $proc->reset;
        }
        $self->clear_events;
    }
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;
