package TestStream;
use Moose;
use Data::EventStream;
use Test::Most;

has aggregator_class => ( is => 'ro', required => 1 );

has aggregator_params => ( is => 'ro', isa => 'HashRef', required => 1 );

has events => ( is => 'ro', isa => 'ArrayRef', required => 1 );

has time_sub => ( is => 'ro' );

has start_time => ( is => 'ro' );

has expected_time_length => ( is => 'ro' );

has expected_length => ( is => 'ro' );

sub _store_observed_value {
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

sub run {
    my $test = shift;

    my $es = Data::EventStream->new(
        ( defined $test->start_time ? ( time     => $test->start_time ) : () ),
        ( defined $test->time_sub   ? ( time_sub => $test->time_sub )   : () ),
    );

    my %aggregator;
    my %ins;
    my %outs;
    my %resets;

    for my $as ( keys %{ $test->aggregator_params } ) {
        $aggregator{$as} = $test->aggregator_class->new;
        $es->add_aggregator(
            $aggregator{$as},
            %{ $test->aggregator_params->{$as} },
            on_enter => sub {
                _store_observed_value( \%ins, $as, $_[0]->value );
            },
            on_leave => sub {
                _store_observed_value( \%outs, $as, $_[0]->value );
            },
            on_reset => sub {
                _store_observed_value( \%resets, $as, $_[0]->value );
            },
        );
    }
    if ( defined $test->expected_time_length ) {
        is $es->time_length, $test->expected_time_length, "correct time length for event stream";
    }
    if ( defined $test->expected_length ) {
        is $es->length, $test->expected_length, "correct length for event stream";
    }

    my $i = 1;
    for my $ev ( @{ $test->events } ) {
        my $title =
            "event $i: "
          . ( defined $ev->{time} ? "time=$ev->{time} " : "" )
          . ( defined $ev->{val}  ? " val=$ev->{val}"   : "" );
        subtest $title => sub {
            $DB::single = 1 if $ev->{debug};
            $es->set_time( $ev->{time} ) if $ev->{time} and not defined $ev->{val};
            $es->add_event( { time => $ev->{time}, val => $ev->{val} } ) if defined $ev->{val};
            eq_or_diff \%ins, $ev->{ins} // {}, "got expected ins";
            %ins = ();
            eq_or_diff \%outs, $ev->{outs} // {}, "got expected outs";
            %outs = ();
            eq_or_diff \%resets, $ev->{resets} // {}, "got expected resets";
            %resets = ();

            if ( $ev->{vals} ) {
                my %vals;
                for ( keys %{ $ev->{vals} } ) {
                    $vals{$_} = $aggregator{$_}->value;
                }
                eq_or_diff \%vals, $ev->{vals}, "aggregators have expected values";
            }
        };
        $i++;
        last if $ev->{stop};
    }
}

__PACKAGE__->meta->make_immutable;
