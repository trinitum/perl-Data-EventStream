use Test::Most;
use Test::FailWarnings;

use Data::EventStream::TimeBatchWindow;
use Data::EventStream::TimedEvent;

{

    package Summator;
    sub new { return bless { count => 0, last => 0, }, shift }
    sub accumulate { my $self = shift; $self->{count} += $_->data for @_; }
    sub compensate { 1 }
    sub reset { my $self = shift; ( $self->{last}, $self->{count} ) = ( $self->{count}, 0 ); }
    sub last { shift->{last} }
}

{

    package Counter;
    sub new { return bless { count => 0, last => 0, }, shift }
    sub accumulate { my $self = shift; $self->{count} += @_; }
    sub reset { my $self = shift; ( $self->{last}, $self->{count} ) = ( $self->{count}, 0 ); }
    sub compensate { 1 }
    sub last       { shift->{last} }
}

my $sum   = Summator->new;
my $cnt   = Counter->new;
my $clock = Data::EventStream::MonotonicClock->new( time => 100 );

my $sw = Data::EventStream::TimeBatchWindow->new(
    size       => 100,
    clock      => $clock,
    processors => [$sum],
);
$sw->add_processor($cnt);

my @data = (
    { time  => 110, sum => 0,  cnt => 0, },
    { event => 1,   sum => 0,  cnt => 0, },
    { event => 2,   sum => 0,  cnt => 0, },
    { time  => 150, sum => 0,  cnt => 0, },
    { event => 3,   sum => 0,  cnt => 0, },
    { time  => 200, sum => 6,  cnt => 3, },
    { event => 4,   sum => 6,  cnt => 3, },
    { time  => 240, sum => 6,  cnt => 3, },
    { event => 3,   sum => 6,  cnt => 3, },
    { time  => 245, sum => 6,  cnt => 3, },
    { event => 2,   sum => 6,  cnt => 3, },
    { time  => 290, sum => 6,  cnt => 3, },
    { event => 1,   sum => 6,  cnt => 3, },
    { time  => 380, sum => 10, cnt => 4, },
    { time  => 390, sum => 10, cnt => 4, },
    { time  => 410, sum => 0,  cnt => 0, },
);

for (@data) {
    if ( $_->{time} ) {
        $clock->set_time( $_->{time} );
        pass "Set time to $_->{time}";
    }
    if ( $_->{event} ) {
        my $event = Data::EventStream::TimedEvent->new(
            time => $clock->get_time,
            data => $_->{event},
        );
        $sw->enqueue($event);
        pass "Enqueued event $_->{event}";
    }
    is $sum->last, $_->{sum}, "Expected value of sum";
    is $cnt->last, $_->{cnt}, "Expected count of events";
}

done_testing;
