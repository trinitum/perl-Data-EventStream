package Data::EventStream;
use Moose;
our $VERSION = "0.02";
$VERSION = eval $VERSION;

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

has length => ( is => 'ro', default => 0, writer => '_set_length' );

sub add_state {
    my ( $self, $state, %params ) = @_;
    $params{_obj} = $state;
    if ( $params{type} eq 'count' ) {
        $params{_in} = 0;
        if ( $params{length} > $self->length ) {
            $self->_set_length( $params{length} );
        }
    }
    $self->push_state( \%params );
}

sub add_event {
    my ( $self, $event ) = @_;
    my $ev     = $self->events;
    my $ev_num = $self->count_events;
    my $as     = $self->aggregate_states;

    for my $state (@$as) {
        if ( $state->{type} eq 'count' ) {
            if ( $state->{_in} == $state->{length} ) {
                $state->{on_out}->( $state->{_obj} ) if $state->{on_out};
                $state->{_obj}->out( $ev->[ -$state->{_in} ] );
                $state->{_in}--;
            }
        }
    }

    $self->push_event($event);

    for my $state (@$as) {
        if ( $state->{type} eq 'count' ) {
            $state->{_obj}->in($event);
            $state->{_in}++;
            $state->{on_in}->( $state->{_obj} ) if $state->{on_in};
        }
    }

    if ( $self->count_events > $self->length ) {
        $self->shift_event;
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
