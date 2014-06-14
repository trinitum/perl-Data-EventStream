package Data::EventStream::Aggregator;
use Moose::Role;

our $VERSION = "0.08";
$VERSION = eval $VERSION;

=head1 NAME

Data::EventStream::Window - Perl extension for event processing

=head1 VERSION

This document describes Data::EventStream::Window version 0.08

=head1 DESCRIPTION

This role defines interface that should be implemented by any aggregator used
with L<Data::EventStream>.

=cut

=head2 $self->enter($event, $window)

This method is invoked when a new event enters aggregator's window

=cut

requires 'enter';

=head2 $self->leave($event, $window)

This method is invoked when an event leaves aggregator's window

=cut

requires 'leave';

=head2 $self->reset($window)

This method is invoked when aggregator is used in the batch mode, each time
after it finished processing another batch

=cut

requires 'reset';

=head2 $self->window_update($window)

This method is invoked when time changes and window contains new time limits

=cut

requires 'window_update';

1;
