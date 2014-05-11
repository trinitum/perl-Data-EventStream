use Test::Most;
use Test::FailWarnings;

use Data::EventStream;

{

    package TimeAverager;
    use Moose;

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
            _add_num => 'add',
            _sub_num => 'sub',
        },
    );

    has _start_event => ( is => 'rw', );

    has _last_event => ( is => 'rw', );

    sub _duration {
        my $self = shift;
        return $self->_last_event->[0] - $self->_start_event->[0];
    }

    sub value {
        my $self = shift;
        return
            $self->_duration    ? $self->_sum / $self->_duration
          : $self->_start_event ? $self->_start_event->[1]
          :                       'NaN';
    }

    sub in {
        my ( $self, $event, $window ) = @_;
        my ( $time, $value ) = $self->time_value_sub->($event);
        if ( $self->_start_event ) {
            my $prev_last = $self->_last_event;
            $self->_last_event( [ $time, $value ] );
            $self->_add_num( ( $time - $prev_last->[0] ) * $prev_last->[1] );
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

    sub out {
        my ( $self, $event, $window ) = @_;
        my ( $time, $value ) = $self->time_value_sub->($event);
        my $start_ev = $self->_start_event;
        $self->_sub_num( ( $time - $start_ev->[0] ) * $start_ev->[1] );
        $start_time = $window->start_time;
        $self->_sub_num( ( $start_time - $time ) * $value );
        $self->_start_event( [ $start_time, $value ] );
    }
}

my $es = Data::EventStream->new();

my %params = (
);

my %average;
my %ins;
my %outs;
my %resets;

for my $as ( keys %params ) {
    $average{$as} = TimeAverager->new;
    $es->add_state(
        $average{$as}, %{ $params{$as} },
        on_in    => sub { $ins{$as}    = $_[0]->value; },
        on_out   => sub { $outs{$as}   = $_[0]->value; },
        on_reset => sub { $resets{$as} = $_[0]->value; },
    );
}

my @events = (
);

my $i = 1;
for my $ev (@events) {
    subtest "event $i: time=$ev->{time} val=$ev->{val}" => sub {
        $es->add_event( { val => $ev->{val} } );
        eq_or_diff \%ins, $ev->{ins} // {}, "got expected ins";
        %ins = ();
        eq_or_diff \%outs, $ev->{outs} // {}, "got expected outs";
        %outs = ();
        eq_or_diff \%resets, $ev->{resets} // {}, "got expected resets";
        %resets = ();
    };
    $i++;
}

done_testing;
