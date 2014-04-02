use Test::Most;
use Test::FailWarnings;

use Data::EventStream::LengthBatchWindow;

my @sums;
{

    package Summator;
    sub new { return bless { count => 0 }, shift }
    sub accumulate { my $self = shift; $self->{count} += $_ for @_; }
    sub reset { push @sums, $_[0]{count}; $_[0]{count} = 0; }
}

my @cnts;
{

    package Counter;
    sub new { return bless { count => 0 }, shift }
    sub accumulate { my $self = shift; $self->{count} = @_; }
    sub reset { push @cnts, $_[0]{count}; $_[0]{count} = 0; }
}

my $sum = Summator->new;
my $cnt = Counter->new;

my $sw = Data::EventStream::LengthBatchWindow->new(
    size       => 3,
    processors => [$sum],
);
$sw->add_processor($cnt);

my @data = ( 1, 2, 3, 4, 3, 2, 1 );
$sw->enqueue($_) for @data;
eq_or_diff \@sums, [ 6, 9 ], "expected sums sequence";
eq_or_diff \@cnts, [ 3, 3 ], "expected counts sequence";
is $sum->{count}, 0, "summator is in initial state";
is $cnt->{count}, 0, "counter is in initial state";
is $sw->count_events, 1, "single event in queue";

done_testing;
