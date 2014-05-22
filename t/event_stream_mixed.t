use Test::Most;
use Test::FailWarnings;

use Data::EventStream;

use lib 't/lib';
use MaxMin;

my $es = Data::EventStream->new( time => 1, time_sub => sub { $_[0]->{time} }, );

my %params = (
    t10 => { duration => 10, },
    c3  => { count    => 3, },
    ct  => { duration => 10, count => 3, },
    ctb => { duration => 10, count => 3, batch => 1, },
);

my %average;
my %ins;
my %outs;
my %resets;

sub store_observed_value {
    my ( $hr, $key, $value ) = @_;
    if ( defined $hr->{$key} ) {
        if ( ref $hr->{$key} eq 'ARRAY' ) {
            push @{ $hr->{$key} }, $value;
        }
        else {
            $hr->{$key} = [ $hr->{$key}, $value, ];
        }
    }
    else {
        $hr->{$key} = $value;
    }
}

for my $as ( keys %params ) {
    $average{$as} = MaxMin->new;
    $es->add_aggregator(
        $average{$as},
        %{ $params{$as} },
        on_enter => sub {
            store_observed_value( \%ins, $as, $_[0]->value );
        },
        on_leave => sub {
            store_observed_value( \%outs, $as, $_[0]->value );
        },
        on_reset => sub {
            store_observed_value( \%resets, $as, $_[0]->value );
        },
    );
}

my @events = (
    {
        time => 3,
        val  => 52,
        ins  => { t10 => "52,52,1", c3 => "52,52,1", ct => "52,52,1", ctb => "52,52,1", },
    },
    {
        time => 5,
        val  => 33,
        ins  => { t10 => "33,52,1", c3 => "33,52,1", ct => "33,52,1", ctb => "33,52,1", },
    },
    {
        time   => 7,
        val    => 47,
        resets => { ctb => "33,52,1", },
        ins    => { t10 => "33,52,1", c3 => "33,52,1", ct => "33,52,1", ctb => "33,52,1", },
    },
    {
        time => 16,
        outs => { t10 => [ "33,52,3", "33,47,5", ], ct => [ "33,52,3", "33,47,5", ], },
        vals => { t10 => "47,47,6", c3 => "33,52,1", ct => "47,47,6", ctb => "NaN,NaN,7", },
    },
    {
        time   => 18,
        val    => 23,
        resets => { ctb => "NaN,NaN,7" },
        outs   => { t10 => "47,47,7", c3 => "33,52,3", ct => "47,47,7", },
        ins    => { t10 => "23,23,8", c3 => "23,47,3", ct => "23,23,8", ctb => "23,23,17", },
    },
    {
        time => 19,
        val  => 15,
        outs => { c3 => "23,47,5", },
        ins  => { t10 => "15,23,9", c3 => "15,47,5", ct => "15,23,9", ctb => "15,23,17", },
    },
    {
        time   => 20,
        val    => 22,
        resets => { ctb => "15,23,17" },
        outs   => { c3 => "15,47,7", },
        ins    => { t10 => "15,23,10", c3 => "15,23,7", ct => "15,23,10", ctb => "15,23,17", },
    },
    {
        time => 21,
        val  => 14,
        outs => { c3 => "15,23,18", ct => "15,23,18", },
        ins  => { t10 => "14,23,11", c3 => "14,22,18", ct => "14,22,18", ctb => "14,14,20", },
    },
);

my $i = 1;
for my $ev (@events) {
    subtest "event $i: time=$ev->{time}" . ( $ev->{val} ? " val=$ev->{val}" : "" ) => sub {
        $es->set_time( $ev->{time} ) unless $ev->{val};
        $es->add_event( { time => $ev->{time}, val => $ev->{val} } ) if $ev->{val};
        eq_or_diff \%ins, $ev->{ins} // {}, "got expected ins";
        %ins = ();
        eq_or_diff \%outs, $ev->{outs} // {}, "got expected outs";
        %outs = ();
        eq_or_diff \%resets, $ev->{resets} // {}, "got expected resets";
        %resets = ();

        if ( $ev->{vals} ) {
            my %vals;
            for ( keys %{ $ev->{vals} } ) {
                $vals{$_} = $average{$_}->value;
            }
            eq_or_diff \%vals, $ev->{vals}, "aggregators have expected values";
        }
    };
    $i++;
    last if $ev->{stop};
}

done_testing;
