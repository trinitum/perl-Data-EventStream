package Data::EventStream::ClockMonotonic;
use Moose;
with 'Data::EventStream::Clock';
use Carp;

has time => (
    is      => 'ro',
    writer  => '_set_time',
    default => sub { time },
);

has _alarm_time => ( is => 'rw' );

has _alarm_cb => ( is => 'rw' );

sub get_time {
    shift->time;
}

sub set_time {
    my ( $self, $time ) = @_;
    croak "New time must not be before current time" if $time < $self->time;
    $self->_set_time($time);
    $self->check_alarm;
}

sub set_alarm {
    my ( $self, $alarm_time, $alarm_cb ) = @_;
    $self->_alarm_time($alarm_time);
    $self->_alarm_cb($alarm_cb);
    $self->check_alarm;
}

sub check_alarm {
    my $self = shift;
    if ( $self->_alarm_time and $self->_alarm_time <= $self->get_time ) {
        my $cb = $self->_alarm_cb;
        $self->clear_alarm;
        $cb->( $self->get_time );
    }
}

sub clear_alarm {
    my $self = shift;
    $self->_alarm_time(undef);
    $self->_alarm_cb(undef);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
