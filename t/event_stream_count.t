use Test::Most;
use Test::FailWarnings;

use Data::EventStream;

{

    package Averager;
    use Moose;

    has value_sub => (
        is      => 'rw',
        default => sub {
            sub { shift->{val} }
        },
    );

    has _sum => (
        is      => 'rw',
        traits  => ['Number'],
        default => 0,
        handles => {
            _sum_add => 'add',
            _sum_sub => 'sub',
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

    sub value {
        my $self = shift;
        return $self->_count ? $self->_sum / $self->_count : 'NaN';
    }

    sub enter {
        my ( $self, $event ) = @_;
        my $val = $self->value_sub->($event);
        $self->_sum_add($val);
        $self->_inc_count;
    }

    sub reset {
        my $self = shift;
        $self->_sum(0);
        $self->_reset_count;
    }

    sub leave {
        my ( $self, $event ) = @_;
        my $val = $self->value_sub->($event);
        $self->_dec_count;
        $self->_sum_sub($val);
    }
}

my $es = Data::EventStream->new();

my %params = (
    'c3' => { type => 'count', length => 3 },
    'c5' => { type => 'count', length => 5 },
    'b4' => { type => 'count', length => 4, batch => 1 },
    'd4' => { type => 'count', length => 4, batch => 1, shift => 2 },
    'd3' => { type => 'count', length => 3, shift => 2 },
);

my %average;
my %ins;
my %outs;
my %resets;

for my $as ( keys %params ) {
    $average{$as} = Averager->new;
    $es->add_aggregator(
        $average{$as}, %{ $params{$as} },
        on_enter => sub { $ins{$as}    = $_[0]->value; },
        on_leave => sub { $outs{$as}   = $_[0]->value; },
        on_reset => sub { $resets{$as} = $_[0]->value; },
    );
}

my @events = (
    {
        val => 2,
        ins => { c3 => 2, c5 => 2, b4 => 2, },
    },
    {
        val => 4,
        ins => { c3 => 3, c5 => 3, b4 => 3, },
    },
    {
        val => 3,
        ins => { c3 => 3, c5 => 3, b4 => 3, d4 => 2, d3 => 2, },
    },
    {
        val => 5,
        ins => { c3 => 4, c5 => 3.5, b4 => 3.5, d4 => 3, d3 => 3, },
        outs   => { c3 => 3, },
        resets => { b4 => 3.5 },
    },
    {
        val => 1,
        ins => { c3 => 3, c5 => 3, b4 => 1, d4 => 3, d3 => 3, },
        outs => { c3 => 4, },
    },
    {
        val => 6,
        ins => { c3 => 4, c5 => 3.8, b4 => 3.5, d4 => 3.5, d3 => 4, },
        outs   => { c3 => 3, c5 => 3, d3 => 3, },
        resets => { d4 => 3.5 },
    },
    {
        val => 8,
        ins => { c3 => 5, c5 => 4.6, b4 => 5, d4 => 1, d3 => 3, },
        outs => { c3 => 4, c5 => 3.8, d3 => 4, },
    },
    {
        val => 4,
        ins => { c3 => 6, c5 => 4.8, b4 => 4.75, d4 => 3.5, d3 => 4, },
        outs   => { c3 => 5, c5 => 4.6, d3 => 3, },
        resets => { b4 => 4.75 },
    },
    {
        val => 0,
        ins => { c3 => 4, c5 => 3.8, b4 => 0, d4 => 5, d3 => 5, },
        outs => { c3 => 6, c5 => 4.8, d3 => 4, },
    },
    {
        val => 5,
        ins => { c3 => 3, c5 => 4.6, b4 => 2.5, d4 => 4.75, d3 => 6, },
        outs   => { c3 => 4, c5 => 3.8, d3 => 5, },
        resets => { d4 => 4.75 },
    },
);

my %exp_resets = ( b4 => [ 3.5, 4.75, ], );

my $i = 1;
for my $ev (@events) {
    subtest "event $i: val=$ev->{val}" => sub {
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
