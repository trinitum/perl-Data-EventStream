package Data::Event::Processor::Window;
use Moose::Role;

has processors => (
    is      => 'ro',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        all_processors => 'elements',
        add_processor  => 'push',
    },
);

has events => (
    is      => 'ro',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        push_event   => 'push',
        shift_event  => 'shift',
        count_events => 'count',
    },
);

requires 'enqueue';

1;
