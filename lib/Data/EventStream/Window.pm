package Data::EventStream::Window;
use 5.010;
use Moose;
our $VERSION = "0.07";
$VERSION = eval $VERSION;

=head1 NAME

Data::EventStream::Window - Perl extension for event processing

=head1 VERSION

This document describes Data::EventStream::Window version 0.07

=head1 DESCRIPTION

This class represents time window for which aggregator aggregates data.
Normally window objects are passed to aggregators' callbacks and user has no need to build them himself.

=head1 METHODS

=cut

=head2 $self->count

Number of events in the window

=cut

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

=head2 $self->start_time

Window start time

=cut

has start_time => ( is => 'rw', default => 0, );

=head2 $self->end_time

Window end time

=cut

has end_time => ( is => 'rw', default => 0, );

=head2 $self->time_length

Window length in time

=cut

sub time_length {
    my $self = shift;
    return $self->end_time - $self->start_time;
}

=head2 $self->get_event($idx)

Returns event with the specified index. 0 being the latest, most recent event,
and -1 being the oldest event.

=cut

sub get_event {
    my ( $self, $idx ) = @_;
    my $count = $self->count;
    return if $idx >= $count or $idx < -$count;
    if ( $idx >= 0 ) {
        return $self->events->[ -( $idx + 1 ) ];
    }
    else {
        return $self->events->[ -( $count + $idx + 1 ) ];
    }
}

=head2 $self->get_iterator

Returns callable iterator object. Each time you call it, it returns the next
event starting from the latest one. For example:

    my $next_event = $win->get_iterator;
    while ( my $event = $next_event->() ) {
        ...
    }

=cut

sub get_iterator {
    my $self   = shift;
    my $idx    = 0;
    my $events = $self->events;
    my $count  = $self->count;
    return sub {
        return if $idx++ >= $count;
        return $events->[ -($idx) ];
    };
}

sub shift_event {
    my ($self) = @_;
    $self->dec_count;
    return $self->events->[ -( $self->count + 1 ) ];
}

sub push_event {
    my ($self) = @_;
    $self->inc_count;
    return $self->events->[ -(1) ];
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;
