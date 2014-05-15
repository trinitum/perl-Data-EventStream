package Data::EventStream::Window;
use Moose;
our $VERSION = "0.02";
$VERSION = eval $VERSION;

has shift => ( is => 'ro', default => 0, );

has count => (
    is      => 'rw',
    default => 0,
    traits  => ['Counter'],
    handles => {
        inc_count   => 'inc',
        dec_count   => 'dec',
        reset_count => 'reset',
    },
);

has events => ( is => 'ro', required => 1, );

has start_time => ( is => 'rw', default => 0, );

has end_time => ( is => 'rw', default => 0, );

sub time_length {
    my $self = shift;
    return $self->end_time - $self->start_time;
}

sub get_event {
    my ( $self, $idx ) = @_;
    my $count = $self->count;
    return if $idx >= $count or $idx < -$count;
    if ( $idx >= 0 ) {
        return $self->events->[ -( $self->shift + $idx + 1 ) ];
    }
    else {
        return $self->events->[ -( $self->shift + $count + $idx + 1 ) ];
    }
}

sub shift_event {
    my ($self) = @_;
    $self->dec_count;
    return $self->events->[ -( $self->shift + $self->count + 1 ) ];
}

sub push_event {
    my ($self) = @_;
    $self->inc_count;
    return $self->events->[ -( $self->shift + 1 ) ];
}

1;
