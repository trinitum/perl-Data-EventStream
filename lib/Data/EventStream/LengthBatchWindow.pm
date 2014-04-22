package Data::EventStream::LengthBatchWindow;
use Moose;
our $VERSION = "0.02";
$VERSION = eval $VERSION;
with 'Data::EventStream::Window';

has size => ( is => 'ro', required => 1 );

sub enqueue {
    my ( $self, $event ) = @_;
    $_->accumulate($event) for $self->all_processors;
    $self->push_event($event);
    if ( $self->count_events == $self->size ) {
        $_->compensate( $self->all_events ) for $self->all_processors;
        $_->reset for $self->all_processors;
        $self->clear_events;
    }
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;
