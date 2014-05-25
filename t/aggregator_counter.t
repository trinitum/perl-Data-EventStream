use Test::Most;
use Test::FailWarnings;

use Data::EventStream;

use lib 't/lib';
use Data::EventStream::Statistics::Sample;
use TestStream;

my %params = ( stat => { count => 4 }, );

my @events = (
    {
        methods => {
            stat =>
              { count => 0, mean => 0, sum => 0, variance => 'NaN', standard_deviation => 'NaN', },
        };
    },
    { val => 10, },
    { val => 20, },
    { val => 30, },
    {
        methods => {
            stat =>
              { count => 3, mean => 20, sum => 60, variance => 100, standard_deviation => 10, },
        };
    },
    { val => 40, },
    { val => 50, },
    {
        methods => {
            stat => {
                count              => 4,
                mean               => 35,
                sum                => 140,
                variance           => 166.66667,
                standard_deviation => 12.90994,
            },
        };
    },
    { val => 19, },
    { val => 27, },
    {
        methods => {
            stat => {
                count              => 4,
                mean               => 34,
                sum                => 136,
                variance           => 188.66667,
                standard_deviation => 13.7356,
            },
        };
    },
);

TestStream->new(
    aggregator_class  => 'Data::EventStream::Statistics::Sample',
    aggregator_params => \%params,
    events            => \@events,
    no_callbacks => 1,
)->run;

done_testing;
