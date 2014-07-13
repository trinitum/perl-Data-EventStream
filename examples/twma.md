---
layout: default
---
## Time weighted moving average

Now we will assume that each event contain timestamp and value, and that stream
of events defines step function that changes its value on each event. In this
case average value will be equal to integral of this function on a given
interval divided by the length of the interval.

### Aggregator

In this case event contains both timestamp and value, so aggregator will
require `time_value_sub` attribute that extracts both from the event.

{% highlight perl %}
package TWMA;
use strict;
use warnings;

sub new {
    my ($class, %params) = @_;
    die "time_value_sub parameter must be specified" unless $params{time_value_sub};
    $params{_sum} = 0;
    return bless \%params, $class;
}
{% endhighlight %}

`_sum` attribute will contain integral of our function over the sliding window.
To calculate duration we will use `_start_point` and `_end_point` attributes
which will contain timestamp and function value for start and end of the
sliding window respectively. To calculate the average we will have to divide
`_sum` by duration:

{% highlight perl %}
sub duration {
    my ($self) = @_;
    $self->{_start_point} ? $self->{_end_point}[0] - $self->{_start_point}[0] : 0;
}

sub average {
    my ($self) = @_;
    $self->duration ? $self->{_sum} / $self->duration : undef;
}
{% endhighlight %}

When event enters window we should update `_last_point` with time and value of
the event, and when event leaves window we should update `_end_point` with
sliding window start time and value of the leaving event:

{% highlight perl %}
sub enter {
    my ($self, $event, $win) = @_;
    my ($time, $value) = $self->{time_value_sub}->($event);
    $self->{_end_point} = [$time, $value];
    unless ($self->{_start_point}) {
        # this is the first event we've got
        $self->{_start_point} = [$time, $value];
    }
}

sub leave {
    my ($self, $event, $win) = @_;
    my ($time, $value) = $self->{time_value_sub}->($event);
    $self->{_start_point} = [$win->start_time, $value];
}
{% endhighlight %}

For reset we will set `_sum` to zero, but we will preserve the current value of
our function in `_start_point` and `_end_point` attributes:

{% highlight perl %}
sub reset {
    my ($self, $win) = @_;
    $self->{_sum} = 0;
    $self->{_start_point} = [$win->start_time, $self->{_end_point}[1]];
    $self->{_end_point}[0] = $win->end_time;
}
{% endhighlight %}

`window_update` method is called when time has changed. It should subtract from
the `_sum` integral for the interval that left the window, and it should add to
it integral for the interval that has been added to the window:

{% highlight perl %}
sub window_update {
    my ($self, $win) = @_;
    # return if we didn't receive a single event yet
    return unless $self->{_start_point};
    if ($win->start_time > $self->{_start_point}[0]) {
        $self->{_sum} -=
            ($win->start_time - $self->{_start_point}[0]) * $self->{_start_point}[1];
        $self->{_start_point}[0] = $win->start_time;
    }
    if ($win->end_time > $self->{_end_point}[0]) {
        $self->{_sum} +=
            ($win->end_time - $self->{_end_point}[0]) * $self->{_end_point}[1];
        $self->{_end_point}[0] = $win->end_time;
    }
}
{% endhighlight %}

### Processing event stream

We will assume that events are hashes with `time` and `price` elements, and we
will calculate moving average for the last 1 minute and minutely averages. By
minutely averages here I mean that once minute is finished we will reset the
aggregator.

{% highlight perl %}
my $now = time;
my $es = Data::EventStream->new(time_sub => sub { shift->{time} }, time => $now);
my $moving = TWMA->new(time_value_sub => sub { ($_[0]->{time}, $_[1]->{price}) });
$es->add_aggregator(
    $moving,
    duration => 60,
    on_enter => sub {
        my $val = shift->average;
        say "Last minute average: $val" if defined $val;
    },
);
my $minutely = TWMA->new(time_value_sub => sub { ($_[0]->{time}, $_[1]->{price}) });
$es->add_aggregator(
    $minutely,
    duration   => 60,
    batch      => 1,
    start_time => $now - ($now % 60),
    on_reset   => sub {
        my $val = shift->average;
        say "Reseting aggregator, last minute average: $val" if defined $val;
    }
);
while (my $event = wait_for_new_event()) {
    $es->add_event($event);
}
{% endhighlight %}

Here we defined `on_enter` and `on_reset` callbacks for aggregators. `on_enter`
callback is called just after event has entered aggregator (after `enter`
method has been called on aggregator), `on_reset` callback is called when
aggregator's window is full, just before calling `reset` method on aggregator.
There is also `on_leave` callback that is called when event leaves aggregator,
just before `leave` method is called.

First aggregator calculates moving average for the last 60 seconds, second
aggregator calculates moving average since the start of the current minute, and
is reset every minute, so it produces minutely averages.
