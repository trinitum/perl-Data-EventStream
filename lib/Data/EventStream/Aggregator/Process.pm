package Data::EventStream::Aggregator::Process;
use Moose;

has _count => ( is => 'rw', default => 0, );

has _integral => ( is => 'rw', default => 0, );

has _start_pos => ( is => 'rw', );

has _cur_pos => ( is => 'rw', );

has time_sub => ( is => 'ro', required => 1, );

has value_sub => ( is => 'ro', required => 1, );

sub count { shift->_count }

sub mean {
    my $self = shift;
        $self->interval   ? $self->_integral / $self->interval
      : $self->_start_pos ? $self->_start_pos->[1]
      :                     undef;
}

sub integral { shift->_integral }

sub interval {
    my $self = shift;
    $self->_start_pos ? $self->_cur_pos->[0] - $self->_start_pos->[0] : 0;
}

sub change {
    my $self = shift;
    $self->_start_pos ? $self->_cur_pos->[1] - $self->_start_pos->[1] : 0;
}

sub enter {
    my ( $self, $event, $window ) = @_;
    my $time = $self->time_sub->($event);
    my $val  = $self->value_sub->($event);
    if ( $self->_start_pos ) {
        my $cur_pos = $self->_cur_pos;
        my $integral = $self->_integral + ( $time - $cur_pos->[0] ) * $cur_pos->[1];
        $self->_integral($integral);
        $self->_cur_pos( [ $time, $val ] );
    }
    else {
        $self->_start_pos( [ $time, $val ] );
        $self->_cur_pos( [ $time, $val ] );
    }
    $self->_count( $self->_count + 1 );
}

sub leave {
    my ( $self, $event, $window ) = @_;
    my $time     = $self->time_sub->($event);
    my $val      = $self->value_sub->($event);
    my $start    = $self->_start_pos;
    my $integral = $self->_integral - ( $window->start_time - $time ) * $val;
    $self->_integral($integral);
    my $start_ev = $window->get_event(-1);
    if ( $start_ev and $self->time_sub->($start_ev) == $window->start_time ) {
        $val = $self->value_sub->($start_ev);
    }
    $self->_start_pos( [ $window->start_time, $val ] );
    $self->_count( $self->_count - 1 );
}

sub reset { }

sub window_update {
    my ( $self, $window ) = @_;
    my $int_change = 0;
    my $start      = $self->_start_pos;
    my $new_start  = $window->start_time;
    if ( $start and $start->[0] < $new_start ) {
        $int_change -= ( $new_start - $start->[0] ) * $start->[1];
        $start->[0] = $new_start;
    }
    if ( my $cur = $self->_cur_pos ) {
        my $new_cur = $window->end_time;
        $int_change += ( $new_cur - $cur->[0] ) * $cur->[1];
        $cur->[0] = $new_cur;
    }
    if ($int_change) {
        $self->_integral( $self->_integral + $int_change );
    }
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;
