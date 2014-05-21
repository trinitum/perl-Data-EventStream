package Data::EventStream;
use 5.010;
use Moose;
our $VERSION = "0.04";
$VERSION = eval $VERSION;
use Carp;
use Data::EventStream::Window;

=head1 NAME

Data::EventStream - Perl extension for event processing

=head1 VERSION

This document describes Data::EventStream version 0.04

=head1 SYNOPSIS

    use Data::EventStream;

=head1 DESCRIPTION

B<WARNING:> this distribution is in the phase of active development, all
interfaces are likely to change in next versions.

Module provides methods to analyze stream of events.

=head1 METHODS

=head2 $class->new(%params)

Creates a new instance. The following parameters are accepted:

=over 4

=item B<time>

Initial model time, by default 0

=item B<time_sub>

Reference to a subroutine that returns time associated with the event passed
to it as the only parameter.

=back

=cut

has time => ( is => 'ro', default => 0, writer => '_time', );

has time_sub => ( is => 'ro', );

has events => (
    is      => 'ro',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        all_events   => 'elements',
        push_event   => 'push',
        shift_event  => 'shift',
        count_events => 'count',
        clear_events => 'clear',
    },
);

has aggregators => (
    is      => 'ro',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        push_aggregator => 'push',
    },
);

has time_length => ( is => 'ro', default => 0, writer => '_set_time_length' );

has length => ( is => 'ro', default => 0, writer => '_set_length' );

=head2 $self->set_time($time)

Set new model time. This time must not be less than the current model time.

=cut

sub set_time {
    my ( $self, $time ) = @_;
    croak "new time ($time) is less than current time (" . $self->time . ")" if $time < $self->time;
    $self->_time($time);
    my $gt = $self->time_sub;
    croak "time_sub must be defined if you using time aggregators" unless $gt;

    for my $aggregator ( @{ $self->aggregators } ) {
        if ( $aggregator->{duration} ) {
            my $win = $aggregator->{_window};
            next if $win->start_time > $time;
            my $period = $aggregator->{duration};
            my $obj    = $aggregator->{_obj};
            if ( $aggregator->{batch} ) {
                while ( $time - $win->start_time >= $period ) {
                    $win->end_time( $win->start_time + $period );
                    $obj->window_update($win);
                    $aggregator->{on_reset}->($obj) if $aggregator->{on_reset};
                    $win->start_time( $win->end_time );
                    $obj->reset($win);
                }
                $win->end_time($time);
            }
            else {
                $win->end_time($time);
                if ( $win->time_length >= $period ) {
                    my $st = $time - $period;
                    while ( $win->count and ( my $ev_time = $gt->( $win->get_event(-1) ) ) <= $st )
                    {
                        $win->start_time($ev_time);
                        $obj->window_update($win);
                        $aggregator->{on_leave}->($obj) if $aggregator->{on_leave};
                        $obj->leave( $win->shift_event, $win );
                    }
                    $win->start_time($st);
                }
            }
            $obj->window_update($win);
        }
    }

    my $limit = $self->time - $self->time_length;
    while ( $self->count_events > $self->length
        and $gt->( $self->events->[0] ) <= $limit )
    {
        $self->shift_event;
    }
}

=head2 $self->add_aggregator($aggregator, %params)

Add a new aggregator object. The following options are accepted:

=over 4

=item B<count>

Maximum number of event for which aggregator can aggregate data. When number
of aggregated events reaches this limit, each time before a new event enters
aggregator, the oldest aggregated event will leave it.

=item B<duration>

Maximum period of time handled by aggregator. Each time the model time is
updated, events with age exceeding specified duration are leaving aggregator.

=item B<batch>

If enabled, when I<count> or I<duration> limit is reached, aggregator is reset
and all events leaving it at once.

=item B<start_time>

Time when the first period should start. Used in conjunction with I<duration>
and I<batch>. By default current model time.

=item B<shift>

Aggregate data with delay. Event enters aggregator only after specified by
I<shift> number of events were added to the stream. Not compatible with
I<duration>. By default 0.

=item B<on_enter>

Callback that should be invoked after event entered aggregator.  Aggregator
object is passed as the only argument to callback.

=item B<on_leave>

Callback that should be invoked before event leaves aggregator.
Aggregator object is passed as the only argument to callback.

=item B<on_reset>

Callback that should be invoked before resetting the aggregator.
Aggregator object is passed as the only argument to callback.

=back

=cut

sub add_aggregator {
    my ( $self, $aggregator, %params ) = @_;
    $params{_obj} = $aggregator;
    $params{shift} //= 0;
    $params{_window} = Data::EventStream::Window->new(
        events     => $self->events,
        shift      => $params{shift},
        start_time => $params{start_time} // $self->time,
    );

    unless ( $params{count} or $params{duration} ) {
        croak 'At least one of "count" or "duration" parameters must be provided';
    }
    if ( $params{count} ) {
        if ( $params{shift} + $params{count} > $self->length ) {
            $self->_set_length( $params{shift} + $params{count} );
        }
    }
    if ( $params{duration} ) {
        croak "time_sub must be defined for using time aggregators"
          unless $self->time_sub;
        croak '"shift" parameter is not compatible with "duration"' if $params{shift};
        if ( $params{duration} > $self->time_length ) {
            $self->_set_time_length( $params{duration} );
        }
    }
    $self->push_aggregator( \%params );
}

=head2 $self->add_event($event)

Add new event

=cut

sub add_event {
    my ( $self, $event ) = @_;
    my $ev     = $self->events;
    my $ev_num = $self->count_events;
    my $as     = $self->aggregators;
    my $time;
    my $gt = $self->time_sub;
    if ($gt) {
        $time = $gt->($event);
        $self->set_time($time);
    }

    for my $aggregator (@$as) {
        if ( $aggregator->{count} ) {
            my $win = $aggregator->{_window};
            if ( $win->count == $aggregator->{count} ) {

                # TODO: review this condition
                if ($gt) {
                    $win->start_time( $gt->( $win->get_event(-1) ) );
                    $aggregator->{_obj}->window_update($win);
                }
                $aggregator->{on_leave}->( $aggregator->{_obj} ) if $aggregator->{on_leave};
                my $ev_out = $win->shift_event;
                $aggregator->{_obj}->leave( $ev_out, $win );
            }
        }
    }

    $self->push_event($event);

    for my $aggregator (@$as) {
        my $win = $aggregator->{_window};
        if ( $aggregator->{count} ) {
            next if $ev_num < $aggregator->{shift};
            my $ev_in = $win->push_event;
            my $event_time = $gt ? $gt->($ev_in) : undef;
            $win->end_time($event_time);
            $aggregator->{_obj}->enter( $ev_in, $win );
            $aggregator->{on_enter}->( $aggregator->{_obj} ) if $aggregator->{on_enter};
            if ( $aggregator->{batch} and $win->count == $aggregator->{count} ) {
                $aggregator->{on_reset}->( $aggregator->{_obj} ) if $aggregator->{on_reset};

                $win->reset_count;
                $win->start_time($event_time) if $event_time;
                $aggregator->{_obj}->reset($win);
            }
        }
        else {
            my $ev_in = $win->push_event;
            $aggregator->{_obj}->enter( $ev_in, $win );
            $aggregator->{on_enter}->( $aggregator->{_obj} ) if $aggregator->{on_enter};
        }
    }

    my $time_limit = $self->time - $self->time_length;
    while ( $self->count_events > $self->length ) {
        if ($gt) {
            if ( $gt->( $self->events->[0] ) <= $time_limit ) {
                $self->shift_event;
            }
            else {
                last;
            }
        }
        else {
            $self->shift_event;
        }
    }
}

1;

__END__

=head1 BUGS

Please report any bugs or feature requests via GitHub bug tracker at
L<http://github.com/trinitum/perl-Data-EventStream/issues>.

=head1 AUTHOR

Pavel Shaydo C<< <zwon at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Pavel Shaydo

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
