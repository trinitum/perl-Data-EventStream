---
layout: default
---
## Simple moving average

### Aggregator class

In this case we will compute an average of all events inside the sliding
window. We will initialize aggregator with zero sum and zero events, and then
each time event enters window we increase number of events and add event value
to the sum, and each time event leaves window we decrease number of events and
subtract event value from the sum. Moving average at any time can be
calculated as sum divided by count of events. So let us implement aggregator class.

{% highlight perl %}
package MovingAverage;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    die "value_sub parameter should be specified" unless $args{value_sub};
    $args{_sum} = 0;
    $args{_count} = 0;
    return bless \%args, $class;
}
{% endhighlight %}

Constructor as you can see initializes `_sum` and `_count` attributes with
zero, and it requires `value_sub` parameter. Events are arbitrary data
structures as it was already mentioned, and `value_sub` is required for
aggregator to be able to extract the value from an event. This subroutine
should return numeric value corresponding to the event.

Now, here is what we do when event enters or leaves window:

{% highlight perl %}
sub enter {
    my ($self, $event) = @_;
    $self->{_count}++;
    $self->{_sum} += $self->{value_sub}->($event);
}

sub leave {
    my ($self, $event) = @_;
    $self->{_count}--;
    $self->{_sum} -= $self->{value_sub}->($event);
}

sub reset {
    my ($self) = @_;
    $self->{_count} = 0;
    $self->{_sum} = 0;
}
{% endhighlight %}

`enter` is called by Data::EventStream object when event enters window, it has
two arguments other than aggregator object itself -- event and window, but we
do not need window object in this case. `leave` is called when event leaves
the window, it has the same parameters as `enter`. For batch windows instead
of `leave` Data::EventStream invokes `reset` method when window is full.

Next, we need a method to get current value of the moving average:

{% highlight perl %}
sub value {
    my ($self) = @_;
    $self->{_count} ? $self->{_sum} / $self->{_count} : undef;
}
{% endhighlight %}

Also method that returns `_count` value might be useful:

{% highlight perl %}
sub count {
    shift->{_count}
}
{% endhighlight %}

The last method that we need to implement for aggregator class is
`window_update`, it is invoked when time changes. We are not handling time in
this aggregator, so it is an empty method:

{% highlight perl %}
sub window_update {}
{% endhighlight %}

### Processing event stream

Now let's see how to use this aggregator class for processing event stream. We
will assume that our events are hashes with `bid` and `ask` elements, and will
calculate moving averages for both for 10 and 20 latest events.

First we need to create event stream object. As we do not have time assosiated
with our events, there is no need to specify `time_sub` attribute:

{% highlight perl %}
my $es = Data::EventStream->new;
{% endhighlight %}

Now we should create aggregator object for each aggregated parameter and attach
it to our event stream.

{% highlight perl %}
my $ask_10 = MovingAverage->new(value_sub => sub { shift->{ask} });
$es->add_aggregator($ask_10, length => 10);
my $ask_20 = MovingAverage->new(value_sub => sub { shift->{ask} });
$es->add_aggregator($ask_20, length => 20);
my $bid_10 = MovingAverage->new(value_sub => sub { shift->{bid} });
$es->add_aggregator($bid_10, length => 10);
my $bid_20 = MovingAverage->new(value_sub => sub { shift->{bid} });
$es->add_aggregator($bid_20, length => 20);
{% endhighlight %}

As you can see `value_sub` for ask aggregators will use `ask` element from the
event as a value, and for bid aggregators it will use `bid` element. To attach
aggregator to stream we are using `add_aggregator` method which accepts
aggregator as its first argument and sliding window parameters as the following
arguments. In this case sliding window parameters just specify the length of
the sliding window.

And now we can start adding events:

{% highlight perl %}
while (my $event = wait_for_new_event()) {
    $es->add_event($event);
    say "Average spread for the last ", $bid_10->count, " events: ",
        $bid_10->value, " - ", $ask_10->value;
    say "Average spread for the last ", $bid_20->count, " events: ",
        $bid_20->value, " - ", $ask_20->value;
}
{% endhighlight %}

`wait_for_new_event` here is an abstract subroutine that waits for a new event
and returns it. Note, that our aggregators start computing average even if they
have only one event, so for the first 10 events two moving averages will be
identical.
