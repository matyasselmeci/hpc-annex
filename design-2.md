# HPC Annex "Phase 2"
April 21, 2022

See [design.md](design.md) for the originally-intended design and the
current state of the world.

## Problem

We expect increasingly large numbers of researchers to have allocations for HPC
machines and want to use those allocations for the HTC work.  This is
non-trivial, since it basically involves running your own glide-in pool.  Phase
1 of this project has made command-line tooling (and some infrastructure)
available to researchers with access to the OS Pool Access Point.

This project is not presently intended to address other "bring-your-own"
resources, such as PATh HTC allocations, although we it will probably be
worthwhile to consider that (and those) resource(s) when improving the UI.

## Goals

These goals are posited as items for discussion.

- Improve deployability, in the sense that we think that it should require
  no more than turning a single meta-knob to enable users of an access point
  to use the HPC Annex tools, and ideally not even that.  (Specifically,
  we don't want the admin to have to issue tokens or run another CM.)
- Improve the direct usability of the tooling.  This potentially includes:
  - Checking resource requests for correctness before sending them to the
    back-end script.  Much of this information is already encoded in the
    scripts but not actually used; it may also be better-represented in
    an external configuration file.  This specifically does _not_ include,
    until otherwise specified, converting between node units and CPUs/memory
    units.
  - Report to the user (before prompting them to log in) the various
    attributes about the resource request they're making and how (which
    command-line flags) to change them.  This includes the size of the
    annex and its duration and idle times, for instance.
  - Providing a tool to mark and unmark jobs as requiring an annex.
  - Allow the user to start an annex without any jobs.
  - Providing a tool for use as a DAGMan provisioning node.
  - Making it easy to specify that all nodes in a DAG should run on
    a particular annex.
  - Small, focused improvements to the wording, especially in using
    a consistent vocabulary within and between different commands.
  - Allow researchers to share their annexes.
  - Allow researchers to specify that their annexes are allowed to run
    jobs that aren't annex-specific.
  - Implement `htcondor jobset submit --annex-name`.
- Support file-transfer efficiency for more (types of) jobs.  Right now,
  the tooling only pre-stages `.sif` files from container universe jobs,
  and implicitly assumes that any usefully-shareable input files have
  been embedded into the `.sif` file.  Further, this `.sif` is assumed
  to be resident on the AP's local disk.  Implementing AP-managed sandboxes
  would eliminate the need for the HPC Annex tooling to do anything
  specific here and also benefit almost all other users.
- Reconceptualize the HPC Annex (tooling).  My initial concept of the HPC
  Annex was to make it just like `condor_annex`, only with a necessarily
  but almost completely different implementation.  However, it has become
  clear that we need a strong and well-decribed conceptual basis in
  order to provide a good user interface and experience.
- Start down the road towards switching from job-oriented push-based
  glide-ins towards pool-oriented pull-based glide-ins.

### Deployability

We presently require a metaknob to be turned for the HPC Annex tooling to
work for three reasons:

1.  To implement a new job ad command (`TargetAnnexName`).  This was done
    to reduce implementation overhead, as well as making it easier for,
    say, DAGMan-submitted jobs to run on an annex.  This was implemented
    as a job transform.
2.  To make it impossible for jobs which don't have `TargetAnnexName` set
    to run on an annex EP, even if that EP is misconfigured (and willing
    run non-annex jobs).  This was also implemented as a job transform.
3.  So that the tooling can complain if the necessary infrastructure for
    making the tooling work doesn't exist.

Obviously, if we successfully eliminate the need for any additional
infrastructure, point 3 becomes irrelevant.  The additional infrastructure
is a collector; if we can leverage the (coming) ability of remote EPs to
report directly to APs, we can eliminate the collector.

If jobs must each individually opt-in to run on user-supplied EPs, we
don't need to provide for point 2 explicitly.

We still want a job ad command which targets a specific annex.  However,
assuming point 2, if a job must opt-in to running on user-supplied EPs,
then opting in could also specify the specific annex.

### Usability Improvements

#### Providing a tool to mark and unmark jobs as requiring an annex.

- Support adding jobs to an annex after its creation.
  - Running `htcondor job submit --annex-name` will only work right now
    (for container-universe jobs) if:
    - the container image was already staged to the annex, and
    - `container_image` is a basename.
    This is because of limitations in the hand-rigged `.sif` file-sharing
    implementation.  Neither restriction would apply if we had AP-managed
    sandboxes.  However, if that takes too long to arrive, we could write
    a script to copy the `.sif` files to the right place (which would require
    the user to log-in again).
- Support removing jobs from an annex after their submission.
  - In the present implementation, this implies undoing a job transformation.
    As far as I know, there's no general way to do this, although we might
    be able to used `qedit` to do this specific change.  This implies that
    we'd rather _not_ implement `TargetAnnexName` as a job transform, so that
    we can simply remove it as requested.
  - ChristinaK thinks that many users may just instinctively remove and
    resubmit jobs targeting the wrong annex.  Also, if we intend to make
    targeting a specific annex optional in the near future, this may be
    largely wasted work.  (If you _want_ a job only to run on a specific
    annex and change your mind, I guess such a tool would be useful.)

#### Support creating an annex before submitting the corresponding jobs.
- This won't work right now because we can't presently prestage files
    on the annex after its creation without making the user log in again.
- This problem goes away if the AP takes care of prestaging for us.

#### Providing a tool for use as a DAGMan provisioning node.

...

#### Making it easy to specify that all nodes in a DAG should run on a particular annex.

This is very similar to, or perhaps entailed, by the above, but could be distinct,
if, for instance, the researcher wanted to run multiple DAGs sequentially (on the
same annex).

### File-Transfer Efficiency (AP-managed Sandboxes)

See some other design document.  Not needing to transfer `.sif` or other
files after submitting the pilot jobs would dramatically simplify things.

### Conceptual Improvements

How we define "annex" in the HTCondor context and in the specific context
of a tool for "bringing your own resources"?  What vocabulary do we use for
the parts of an annex and/or its components?  What adjectives describe
annexes, what verbs can act on annexes?  Clear, consistent, and coherent
answers to these questions will make our tooling more understandable
and easier for us to introduce.  A strawman argument follows.

Thinking about "bringing your own resources," what we want is some way
for a researcher to direct HTCondor to use their allocation(s) to run
their job(s).  We could have taken a cue from the grid universe, and required
that the researcher specify everything necessary to run their job using
a specific allocation in every job which they want to use that allocation,
but we did not.  In part, this was because implementation difficulties --
we need the researcher to complete the 2FA process to grant us access to
their allocation -- but it did follow good principles: don't make the
user repeat themselves led to a layer of indirection and an opportunity
for late binding.

That is, we introduced a name to connect the details necessary to use an
allocation with the jobs which wanted to do so.  More precisely, the name
allows a job to be matched to the EPs using the corresponding allocation.
The tooling currently also uses that name to organize usage reports.

The details necessary to use an allocation are not the same object, or
indeed the same type of object, as a group of self-identifying group of EPs,
but the tooling presently uses the same word -- annex -- to refer to both.

#### Begin Random Vocabulary Interjection

##### annex
A named set of resources leased to run HTCondor jobs.

Note that the set is named, not self-identifying.  The implementaion may
rely on EPs self-identifying in a cryptographically verifiable way, but
the EP does not decide which set it's in; whoever supplied the necessary
cyrptographic token did.  Note that I just conflated "EPs" with "resources"
in the definition.  I'm not sure if this is imprecise thinking, or a useful
if minorly deceptive allusion to BYOR.

I used "resources" here because (a) "BYOR" and (b) we may not be leasing
whole nodes (see below).  Amplifying on (a), another possibility would be
to say "EPs", but I think "leased EP" is potentially confusing (do we mean
the running daemon is leased, or the resources it's making available to jobs?)
and maybe unnecessarily jargony.

I like "leased" in this definition because it carries three important connotations:
1.  A lease is temporary.
2.  You don't own what you lease; you have restricted rights and privileges with it.
3.  Leases aren't free (even if you're just with your allocation).

Having a name is critical.

An important caveat here is that this definition is both time- and set-membership-
independent.  Resources could come or go at any time, but that doesn't change the
identity of the annex.  Likewise, this definition doesn't permit us to distinguish
between the "example" annex that ran my jobs last week from the "example" anne that
ran my jobs last week.  This same problem has caused us grief with jobs which
are started more than once.  I don't know if that means we should adjust the definition
to be time-dependent, or if we just need to decide on way of referring to yesterday's
annex as opposed to last weeks annex ahead of time and stick with it.

I added the purpose -- "to run HTCondor jobs" -- to the definition because
it makes the specfic value the tooling is adding clearer.  (This came up
in the context of trying to use the previous definition in the context of,
say, the third or fourth slide of a talk.)

(We could define an unqualified annex as "... to run jobs" and make an "HTCondor
annex" an annex which ran HTCondor jobs, but that's probably more subtle than
we need to be; we're not writing a paper, here.)

##### resource request
By definition, the resources in an annex have already been leased.  How
does one obtain a lease to a resource?  By asking for it; such a question
is a resource request.  In the HPC Annex tooling, we ask for a lease by
submitting a SLURM job, but we record the resouce request even before
starting the back-end script.

##### node
SLURM jobs run on "nodes", not machines.  More importantly, the limits
on a researcher's resource requests may include "nodes" as a resource limit,
so we should use the same word.

##### cores
If a SLURM system allocates fractional nodes, it will usually split them
by "core", not by CPU.  (Although the documentation for Expanse, Stampede 2,
Bridges 2, and Anvil all use "cores", just to be confusing, the corresponding SLURM
option is `--tasks-per-node`.)  We should use the same word.

#### End Random Vocabulary Interjction

If we restrict the tooling so that each named set (of details required to
use an allocation) corresponds to at most one set of leased resources, we
may be able to sustain the conflation between this two different ideas and
not need separate them with different names.  (Further, if every annex has
a fixed size, we may be able to avoid introducing the idea of resource
requests, because there will only ever be one at a time for each name.)

However, such a restriction would prevent a few scenarios which seem likely:
- The researcher has placed a number of jobs for a particular annex, but
  they're runnning more slowly than anticipated.  We could provide a tool
  to create a new, larger annex and rewrite all placed jobs to target the
  new annex, but that's technologically challenging (because of job factories
  and DAGMan) and may result in substantial delays (because who knows when the
  new, larger set of resources may become available).  It may be "more natural"
  to allow the researcher to add more resources with the same name, instead.
- The researcher, having completed one workflow using an HPC system, now wants
  to run a few more instances of the same workflows at the same time.  Regardless
  of the internals, we shouldn't require the user to repeat themselves.  We
  need to think about copying ("cloning"?) the set of allocation details, as
  opposed to having multiple instances of the set of details.  They'd still have
  to have individual names, but perhaps the name would be automatically generated?
  Would instances of same annex be presented differently in the summary report(s)?
  How would I automate (via DAGMan or other tools) referring to the same named set
  of details but wanting a different set of resources?
- We probably want to keep some memory of a particular named set of leased
  resources past the time at which the lease expires, perhaps semi-permanently,
  so that a researcher who asks about that set of resources doesn't get a blank
  stare.  Even with restricted tooling, this means we'd still want to distinguish
  between yesterday's "example" annex and last week's "example" annex.
- It may be useful and/or good UI/UX to remember the name of a set of details
  permanently, or at least for a lot longer than we do an `individual "annex instance."
  This of course leads to the question of what to call those sets ("annex template"s?)
  and how to/how the researcher can manage them.  Along the "don't repeat yourself"
  line, perhaps the tooling should remember the details from the last command-line
  creation of an instance and use those if none are specified?  Does this integrate
  cleanly into the idea of user-managed/explicit templates?  Does, or how does,
  this idea integrate with copying/cloning, above?

### Towards a Pull-based Model

An annex, conceptually, is a push-based model: the researcher decides that now is a
good time to make a resource request.  Presently, the implementation is also
push-based: for each resource request, all of the necessary details are sent
along in the submitted SLURM job.  We could, instead, only send along enough details
to contact the annex collector and ask _it_ for the details (of a given resource
request).  This has no immediate benefit for the annex, but a working example of such
a system would make it easier to switch from glideInWMS pushing jobs to administrators
configuring pools to pull resource requests.

## Specifications

### (Deployability)  Switch to directly-reporting EPs.

If the Annex EPs directly reported to the researcher's AP, the
HPC Annex tooling would no longer need its own central manager.
This would improve **deployability**.

This direct-reporting feature does not yet exist, although it
is under active development.  The HPC Annex tooling would be
able to use this feature under the following conditions:

1.  That the AP issue user-specific IDTOKENS (via `condor_token_fetch`)
    whose bearer can use them to directly report an EP to the AP.
2.  That each job specifies if it's willing to run on such EPs, and if
    so, which one(s).  This need not initially include the ability
    to run one user's jobs on another user's EPs.  This requirement
    may overlap with properly implementing per-user flocking,
    depending on how we want to represent the directly-reporting EPs.
    The opt-in specification should include both (optionally) the "group"
    (annex) name, defaulting to any; and (optionally) the identity of the
    user supplying the EP, which defaults to only the submitting user.
3.  That the HPC Annex tooling have some mechanism very much like,
    and ideally identical to, `condor_status` which works on EPs
    directly reported to the local AP.
4.  That mechanism support transferring the remote-administration
    capability to the researcher['s tools].
5.  The jobs run on the directly-reporting EPs do not count against the
    the job owner's priority.

### Usability Improvements

...

### (File-Transfer Efficiency)  Implement AP-Managed Sandboxes

...

### Reconceptualization

...

### Pull-Based Model

...

## Milestones

### Milestone 1

...

### Milestone 2

...

### Milestone 3

...
