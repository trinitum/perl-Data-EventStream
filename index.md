---
layout: default
---
## Introducion

Suppose you receive stream of events, where each event represents state of some
process at given time. In many cases it may be usefull to calculate certain
parameters of this stream over a sliding window, for example an average over
the last 5 minutes. Data::EventStream is a module that helps you to solve this
task. Data::EventStream object represents stream of events, you can attach
aggregator objects to the stream, and they will be updated each time event
enters or leave sliding window.

### Windows

There are two basic types of sliding window -- length based and time based.
Length based window holds certain number of events, e.g. last 10 events. If new
event enters length window that already contains maximum number of events, the
oldest event leaves window before the new event enters it. Time based window
holds events for the specified period of time, e.g. last 10 minutes. When time
is updated, all events older than specified period leave window. Window may
combine time and length limits, e.g. it is possible to define a sliding window
which holds up to 10 last events for up to 10 minutes. Window may be defined as
"batch", which means that when maximum number of events is added to the window,
or it covers full period of time, it shrinks to zero and starts growing again.
Each aggregator has its own sliding window, so you can attach to a single event
stream aggregators which calculate parameters for different periods of time or
number of events.

### Aggregators

Aggregator is an object that implements four methods: enter, leave, reset, and
window_update.  When event enters or leaves sliding window, `enter`, or `leave`
method is invoked with two parameters -- event, and window object which
describes current sliding window. For batch windows, `reset` method is invoked
when window reaches maximum allowed size, `leave` method is not invoked in this
case.  Finally, `window_update` method is invoked when time changes.

### Time

Data::EventStream does not use real time, instead it allows you to set initial
time when you creating an object and when update it using `set_time` method, or
just by adding new events containing updated time. Time is arbitrary numeric
value which may only increase, attempt to set new time that is less than
current time, or add an event with timestamp less than current time will
trigger an error.

### Events

Events are arbitrary data structures -- it may be a hash, object, array, scalar
or any other data type. Data::EventStream only needs to be able to extract
timestamp from the event if you use time based sliding windows. For that
purpose you should specify `time_sub` attribute when creating Data::EventStream
object, this attribute should be a reference to the subroutine that returns
timestamp for the event passed to it as the only argument. For example, if your
events are references to hashes that contain timestamp in `timestamp` element,
then you can create Data::EventStream object like this:

{% highlight perl %}
my $es = Data::EventStream->new(
    time_sub => sub { shift->{timestamp} },
)
{% endhighlight %}

In a similar manner, some aggregators may require you to specify `value_sub`
that extracts some value from the event.

Now lets have a look at some [examples]({{site.url}}/examples).
