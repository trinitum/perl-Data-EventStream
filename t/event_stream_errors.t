use Test::Most;
use Test::FailWarnings;

use Data::EventStream;
use lib 't/lib';
use Averager;

subtest "EventStream without time_sub" => sub {
    my $es = Data::EventStream->new;
    throws_ok { $es->set_time(5) } qr/time_sub/, "can't set time if time_sub is not defined";
    my $agg = Averager->new( value_sub => sub { $_[0] } );
    throws_ok { $es->add_aggregator($agg) } qr/parameters/,
      "can't add aggregator without count and duration";
    throws_ok { $es->add_aggregator( $agg, duration => 20 ) } qr/time_sub/,
      "can't add time based aggregator without time_sub";
};

subtest "Time can only increase" => sub {
    my $es = Data::EventStream->new( time => 10, time_sub => sub { $_[0] } );
    my $agg = Averager->new( value_sub => sub { $_[0] } );
    $es->add_aggregator( $agg, count => 2 );
    throws_ok { $es->set_time(8) } qr/less than current/, "can't set time to past";
    is $es->time, 10, "time didn't change";
    $es->add_event(12);
    is $es->time,   12, "time changed to event time";
    is $agg->value, 12, "aggregator value set to event value";
    throws_ok { $es->add_event(11) } qr/less than current/, "can't add event from the past";
    is $es->time,   12, "time is still 12";
    is $agg->value, 12, "aggregator value is still 12";
    is @{ $es->events }, 1, "only one event in the stream";
};

done_testing;
