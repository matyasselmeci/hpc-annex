So I was listening to a meeting and had a Miron moment, where I heard the same
word used like a dozen times in two minutes and just really wanted to tell
everyone to stop using that word.  The meeting had turned to discussing how to
ease the debugging of file-transfer problems, and the word was 'site.'

After listening to my rant about 'site' not actually having any meeting, TJ
pointed out that what people probably meant by it was "the set of file-transfer
infrastructure" [used by this job because it was run on that startd].

This is brilliant.  It's a return to the idea that startds should advertise
what characterizes them as an execution point.  So the idea is that we get
somebody who knows what matters about Ceph, or about CVMFS, or about the
proxy setting(s), etc, to write a script that spits this all out so that we
can just _know_ the file-transfer infrastructure, not just infer it from
this mystical "site" concept.  We can do even better.

Suppose in addition to (or instead of?) advertising the file-transfer
infrastructure script output, we actually hash it?  Then it becomes
very easy to look at a collection of slot ads and determine which of
them "should" behave the same way when transferring files ... regardless
of how anyone _expects_ them to behave.  This is not just useful for
debuggers, but also for site admins, who frequently (as we discovered
in CHTC this week) don't even know if their EPs are all configured the
same way.  (Sometimes, they aren't supposed to be.)  So this could be
the basis for both debugging and for a relatively lightweight way of
doing black-hole avoidance for file-transfer problems.

The concept extends to other specific ways of grouping or characterizing
startds.  Particularly, we could get the ball rolling by doing the same
thing for startd (and other daemon?) configuration.  The CHTC already
does something similar for the config-on-disk by recording and reporting
the git hash, but we could build it into HTCondor and record and report
the hash of the configuration that's actually being used (in memory).  (We'd
have to engage in a little cleverness to avoid including, e.g., IP_ADDRESS
and FULL_HOSTNAME in the hash.)  This is potentially very
useful/informative/instructive by itself, in the same set of ways that a
file-transfer infrastructure hash would be.

So: instead of explicitly naming a concept we have trouble defining, why
not start smaller and for a particular problem domain, and do compute
membership based on observed properties of the system rather than
desired ones?
