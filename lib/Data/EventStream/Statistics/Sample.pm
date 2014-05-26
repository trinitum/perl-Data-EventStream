package Data::EventStream::Statistics::Sample;
use Moose;

has value_sub => ( is => 'ro', required => 1, );

has _sum => ( is => 'rw', default => 0, );

has _sq_sum => ( is => 'rw', default => 0, );

has _count => ( is => 'rw', default => 0, );

sub count { shift->_count }

sub sum { shift->_sum }

sub mean {
    my $self = shift;
    return $self->_count ? $self->_sum / $self->_count : undef;
}

sub variance {
    my $self  = shift;
    my $count = $self->_count;
    return undef unless $count;
    return 0 if $count == 1;
    my $variance = ( $self->_sq_sum - $count * $self->mean**2 ) / ( $count - 1 );
    return $variance > 0 ? $variance : 0;
}

sub standard_deviation {
    my $variance = shift->variance;
    return defined $variance ? sqrt($variance) : undef;
}

sub enter {
    my ( $self, $event, $window ) = @_;
    my $val = $self->value_sub->($event);
    $self->_sum( $self->_sum + $val );
    $self->_sq_sum( $self->_sq_sum + $val * $val );
    $self->_count( $self->_count + 1 );
}

sub leave {
    my ( $self, $event, $window ) = @_;
    my $val = $self->value_sub->($event);
    $self->_sum( $self->_sum - $val );
    $self->_sq_sum( $self->_sq_sum - $val * $val );
    $self->_count( $self->_count - 1 );
}

sub reset {
    my ( $self, $window ) = @_;
    $self->_sum(0);
    $self->_sq_sum(0);
    $self->_count(0);
}

sub window_update {
    1;
}

__PACKAGE__->meta->make_immutable;

1;
