package TimeAverager;
use Moose;
with 'Data::EventStream::Aggregator';

has time_value_sub => (
    is      => 'ro',
    default => sub {
        sub { ( $_[0]->{time}, $_[0]->{val} ) }
    },
);

has _sum => (
    is      => 'rw',
    traits  => ['Number'],
    default => 0,
    handles => {
        _sum_add => 'add',
        _sum_sub => 'sub',
    },
);

has _start_event => ( is => 'rw', );

has _last_event => ( is => 'rw', );

sub _duration {
    my $self = shift;
    return $self->_start_event ? $self->_last_event->[0] - $self->_start_event->[0] : 0;
}

sub value {
    my $self = shift;
    return
        $self->_duration ? 0 + sprintf( "%.6g", $self->_sum / $self->_duration )
      : $self->_start_event ? $self->_start_event->[1]
      :                       'NaN';
}

sub enter {
    my ( $self, $event, $window ) = @_;

    my ( $time, $value ) = $self->time_value_sub->($event);
    if ( $self->_start_event ) {
        my $prev_last = $self->_last_event;
        $self->_last_event( [ $time, $value ] );
        $self->_sum_add( ( $time - $prev_last->[0] ) * $prev_last->[1] );
    }
    else {
        # this is first observed event
        $self->_start_event( [ $time, $value ] );
        $self->_last_event( [ $time, $value ] );
    }
}

sub reset {
    my ( $self, $window ) = @_;
    my $last = $self->_last_event;
    if ($last) {
        my $start_time = $window->start_time;
        $self->_start_event( [ $start_time, $last->[1] ] );
        $self->_last_event( [ $start_time, $last->[1] ] );
    }
    $self->_sum(0);
}

sub leave {
    my ( $self, $event, $window ) = @_;
    my ( $time, $value ) = $self->time_value_sub->($event);
    my $start_ev = $self->_start_event;
    $self->_sum_sub( ( $time - $start_ev->[0] ) * $start_ev->[1] );
    my $start_time = $window->start_time;
    $self->_sum_sub( ( $start_time - $time ) * $value );
    $self->_start_event( [ $start_time, $value ] );
    $self->window_update($window);
}

sub window_update {
    my ( $self, $window ) = @_;
    my $last = $self->_last_event;
    if ($last) {
        $self->_last_event( [ $window->end_time, $last->[1] ] );
        $self->_sum_add( ( $window->end_time - $last->[0] ) * $last->[1] );
    }
    my $start = $self->_start_event;
    if ( $start and $start->[0] < $window->start_time ) {
        $self->_start_event( [ $window->start_time, $start->[1] ] );
        $self->_sum_sub( ( $window->start_time - $start->[0] ) * $start->[1] );
    }
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;
