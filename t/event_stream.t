use Test::Most;
use Test::FailWarnings;

use Data::EventStream;

{

    package Averager;
    use Moose;

    has value_sub => (
        is      => 'rw',
        default => sub {
            sub { $_->{val} }
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

    has _count => (
        is      => 'rw',
        traits  => ['Counter'],
        default => 0,
        handles => {
            _inc_count   => 'inc',
            _dec_count   => 'dec',
            _reset_count => 'reset',
        },
    );

    sub value { my $self = shift; return $self->_count ? $self->_sum / $self->_count : 'NaN'; }

    sub in {
        my ( $self, $event ) = @_;
        my $val = $self->value_sub->($event);
        $self->_add_num($val);
        $self->_inc_count;
    }

    sub reset {
        my $self = shift;
        $self->_sum(0);
        $self->_reset_count;
    }

    sub out {
        my ( $self, $event ) = @_;
        my $val = $self->value_sub->($event);
        $self->_dec_count;
        $self->_sub_num($val);
    }
}

my $es = Data::EventStream->new();

my %params = (
    'c3' => { type => 'count', length => 3 },
    'c5' => { type => 'count', length => 5 },
);

my %average;
my %ins;
my %outs;

for my $as ( keys %params ) {
    $average{$as} = Averager->new;
    $es->add_state(
        $average{$as}, %{ $params{$as} },
        on_in  => sub { $ins{$as}  //= []; push @{ $ins{$as} },  $_[0]->value; },
        on_out => sub { $outs{$as} //= []; push @{ $outs{$as} }, $_[0]->value; },
    );
}

my @events = (
    { val => 2 },
    { val => 4 },
    { val => 3 },
    { val => 5 },
    { val => 1 },
    { val => 6 },
    { val => 8 },
    { val => 4 },
    { val => 0 },
    { val => 5 },
);

my %exp_ins = (
    c3 => [ 2, 3, 3, 4,   3, 4,   5,   6,   4,   3, ],
    c5 => [ 2, 3, 3, 3.5, 3, 3.8, 4.6, 4.8, 3.8, 4.6, ],
);

my %exp_outs = (
    c3 => [ 3, 4,   4, 4,   5,   6,   4,   3, ],
    c5 => [ 3, 3.5, 3, 3.8, 4.6, 4.8, 3.8, 4.6, ],
);

for my $ev (@events) {
    $es->add_event($ev);
}

for my $as ( keys %params ) {
    eq_or_diff $ins{$as},  $exp_ins{$as},  "got expected ins for $as";
    eq_or_diff $outs{$as}, $exp_outs{$as}, "got expected outs for $as";
}

done_testing;
