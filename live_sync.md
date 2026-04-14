# live sync proposal

We now have a functional two-way manual sync of local docs to remote google docs!

When using two open instances of real google docs, you see remote edits in near-realtime
as the other party is editing.  We don't currently do that, you have to click 'sync now'.

Let's add a lazy - less aggressive - live sync feature.

I suggest "lazy" because this app is largely intended to serve as a note taker and
note organizer, and not a full blown local clone of google docs, necessarily, but it
would be nice to realize that a doc is being edited simultaneously and not 1. be
completely oblivious to that as a user, and 2. have a large backlog of edits on both
sides that then have to be merged, which complicates the merge.

For a "lazy" model, I propose the opposite of "exponential backoff".  While editing
locally, or sitting idle, we check every few seconds or even tens of seconds just to
see if the google doc has changed.  If it has, update the local doc with the merged
changes (as we already can do during a manual sync.)

Once we have noticed that the google side is seeing remote edits, ramp up the frequency
of checks so that we see the edits in closer-to-realtime fashion.  For some period of
time, maintain the higher polling frequency to emulate the google doc simultaneous
editing behavior.  If the remote edits stop arriving for a while, back off again
into "lazy mode".

This accounts for the fact that we normally don't expect remote edits, so we don't
burn a lot of cycles and api calls on checking the doc unnecessarily, but allows the
app to start acting more like google docs when there are remote edits occuring.


