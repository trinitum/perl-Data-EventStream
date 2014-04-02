use Test::Most;
use Test::FailWarnings;

use Data::EventStream::LengthWindow;

{

    package Summator;
    sub new { return bless { count => 0 }, shift }
    sub accumulate { $_[0]{count} += $_[1] }
    sub compensate { $_[0]{count} -= $_[1] }
    sub count { $_[0]{count} }
}

{

    package Counter;
    sub new { return bless { count => 0 }, shift }
    sub accumulate { $_[0]{count}++ }
    sub compensate { 1 }
    sub count      { $_[0]{count} }
}

my $sum = Summator->new;
my $cnt = Counter->new;

my $sw = Data::EventStream::LengthWindow->new(
    size       => 3,
    processors => [$sum],
);
$sw->add_processor($cnt);

my @data =
  ( [ 1, 1, 1 ], [ 2, 3, 2 ], [ 3, 6, 3 ], [ 4, 9, 4 ], [ 3, 10, 5 ], [ 2, 9, 6 ], [ 1, 6, 7 ], );

my $i;
for (@data) {
    $i++;
    $sw->enqueue( $_->[0] );
    is $sum->count, $_->[1], "Correct sum on step $i";
    is $cnt->count, $_->[2], "Correct count on step $i";
}

done_testing;
