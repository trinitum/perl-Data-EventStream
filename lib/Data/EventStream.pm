package Data::EventStream;
use Moose;
our $VERSION = "0.02";
$VERSION = eval $VERSION;
use Carp;
use Data::EventStream::Window;

=head1 NAME

Data::EventStream - Perl extension for processing event stream

=head1 VERSION

0.01

=head1 SYNOPSIS

    use Data::EventStream;

=head1 DESCRIPTION

B<WARNING:> this distribution is in the phase of active development, all
interfaces are likely to change and documentation is non-existent.

Collection of modules for processing streams of events.

=head1 METHODS

=cut

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

has aggregate_states => (
    is      => 'ro',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        push_state => 'push',
    },
);

has time => ( is => 'ro', default => 0, writer => '_time', );

has time_length => ( is => 'ro', default => 0, writer => '_set_time_length' );

has time_sub => ( is => 'ro', );

has length => ( is => 'ro', default => 0, writer => '_set_length' );

sub set_time {
    my ( $self, $time ) = @_;
    croak "new time ($time) is less than current time (" . $self->time . ")" if $time < $self->time;
    $self->_time($time);
    my $gt = $self->time_sub;
    croak "time_sub must be defined if you using time states" unless $gt;

    for my $state ( @{ $self->aggregate_states } ) {
        if ( $state->{type} eq 'time' ) {
            my $win = $state->{_window};
            $win->end_time($time);
            if ( $win->time_length >= $state->{period} ) {
                my $st = $time - $state->{period};
                while ( $win->count and ( my $ev_time = $gt->( $win->get_event(-1) ) ) <= $st ) {
                    $win->start_time($ev_time);
                    $state->{_obj}->out( $win->shift_event, $win );
                }
                $win->start_time($st);
            }
            $state->{_obj}->window_update($win);
        }
    }

    my $limit = $self->time - $self->time_length;
    while ( $self->count_events > $self->length
        and $gt->( $self->events->[0] ) <= $limit )
    {
        $self->shift_event;
    }
}

sub add_state {
    my ( $self, $state, %params ) = @_;
    $params{_obj} = $state;
    if ( $params{type} eq 'count' ) {
        $params{shift} //= 0;
        $params{_window} = Data::EventStream::Window->new(
            shift  => $params{shift},
            events => $self->events,
        );
        if ( $params{shift} + $params{length} > $self->length ) {
            $self->_set_length( $params{shift} + $params{length} );
        }
    }
    elsif ( $params{type} eq 'time' ) {
        croak "time_sub must be defined for using time states"
          unless $self->time_sub;
        $params{_window} = Data::EventStream::Window->new( events => $self->events, );
        if ( $params{period} > $self->time_length ) {
            $self->_set_time_length( $params{period} );
        }
    }
    else {
        croak "Unknown state type $params{type}";
    }
    $self->push_state( \%params );
}

sub add_event {
    my ( $self, $event ) = @_;
    my $ev     = $self->events;
    my $ev_num = $self->count_events;
    my $as     = $self->aggregate_states;
    my $time;
    my $gt = $self->time_sub;
    if ($gt) {
        $time = $gt->($event);
    }

    for my $state (@$as) {
        if ( $state->{type} eq 'count' ) {
            if ( $state->{_window}->count == $state->{length} ) {
                $state->{on_out}->( $state->{_obj} ) if $state->{on_out};
                my $ev_out = $state->{_window}->shift_event;
                $state->{_obj}->out( $ev_out, $state->{_window} );
            }
        }
    }

    $self->push_event($event);

    for my $state (@$as) {
        if ( $state->{type} eq 'count' ) {
            next if $ev_num < $state->{shift};
            my $ev_in = $state->{_window}->push_event;
            $state->{_obj}->in( $ev_in, $state->{_window} );
            $state->{on_in}->( $state->{_obj} ) if $state->{on_in};
            if ( $state->{batch} and $state->{_window}->count == $state->{length} ) {
                $state->{on_reset}->( $state->{_obj} ) if $state->{on_reset};
                $state->{_window}->reset_count;
                $state->{_obj}->reset( $state->{_window} );
            }
        }
        elsif ( $state->{type} eq 'time' ) {
            my $ev_in = $state->{_window}->push_event;
            $state->{_obj}->in( $ev_in, $state->{_window} );
            $state->{on_in}->( $state->{_obj} ) if $state->{on_in};
        }
    }

    if ( $self->count_events > $self->length ) {
        if ($gt) {
            my $limit = $self->time - $self->time_length;
            while ( $gt->( $self->events->[0] ) <= $limit ) {
                $self->shift_event;
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
