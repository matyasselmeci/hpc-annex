"HPC Annex Phase 2"
===================
April 21, 2022

See [design.md](design.md) for the originally-intended design and the
current state of the world.

Problem
-------

We expect increasingly large numbers of researchers to have allocations for HPC
machines and want to use those allocations for the HTC work.  This is
non-trivial, since it basically involves running your own glide-in pool.  Phase
1 of this project has made command-line tooling (and some infrastructure)
available to researchers with access to the OS Pool Access Point.

This project is not presently intended to address other "bring-your-own"
resources, such as PATh HTC allocations, although we it will probably be
worthwhile to consider that (and those) resource(s) when improving the UI.

Goals
-----

These goals are posited as items for discussion.

- Improve deployability, in the sense that we think that it should require
  no more than turning a single meta-knob to enable users of an access point
  to use the HPC Annex tools.
- 

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
is a collector; if we can leverage the (coming) ability of remote startds to
report directly to schedds, we can eliminate the collector.  (See elsewhere
in this document for details.)

Specifications
--------------

### Switch to per-user flocking.

Switch to per-user flocking eliminates the need for an external collector
under the conditions below, which improves **deployability**.  <FIXME:
other goals met by this specification?>

<conditions include: security, condor_status'ability, the schedd only
sending jobs set with `FlockTarget`, FIXME: etc?>

Milestones
----------

### Milestone 1

### Milestone 2

### Milestone 3

BITS FOR DRAFTING
=================

- `htcondor annex create` needs to know about the various queue restrictions
  and enforce them itself, so it doesn't make the user login only to get
  bounced back right away for an invalid request.  Some of this information
  has already been encoded, but none if it is currently being use, and it
  should probably be read from a config file   (of some sort) instead. 
- Right now, `htcondor annex create` is used to both create annexes and expand
  them.  This is, at best, confusing.  We should certainly add something like
  `htcondor annex expand` (even if it’s just an alias); it’s not clear if we
  should also require users to specify expand rather than create if there’s
  already an annex by that name (as recorded in the local universe job queue).
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
- Add a tool that targets jobs to annex after their submission.  Presently,
  this would make them run _only_ on that annex.  This is currently required
  at a technical level because of the container image restrictions mentioned
  above, and because the annex attempts to prevent random jobs from the same
  user from running on them.  The latter is a UI/UX choice that could be
  revisited, especially if the job could otherwise run unmodified elsewhere
  (once the container image restrictions are lifted).
- Allow annex creation before job submission (for DAGMan).  Again, this
  requires removing the current restrictions on container images.
- Replace the current PASSWORD-based `htcondor annex shutdown` implementation
  with one based on passing admin capabilities through the collector.
- If we still need to rewrite jobs, mark them so we don't rewrite them again.
- Implement `htcondor jobset submit annex-name`.  We're going to need it.
- Pull resource requests from the annex collector rather than push them to
  the pilot via command-line arguments, mostly for strategic reasons.
- For now, barring requests from our UI/UX people and/or the users, the
  front-end will know if a given queue works with whole nodes or allocates
  individual cores (or chunks of RAM) and require the user to specify the
  size appropriately.
- Look into supporting "noun" plug-ins in `htcondor`.  This may be a (partial)
  solution to the documentation problem, but `htcondor gromacs ...` also
  sounds really attractive to GregT.
- Some command, currently unnamed, to unbind a job from an annex.  It’s not
  clear if this is really worth it – ChristinaK thinks that many users may
  just instinctively remove and resubmit jobs targeting the wrong annex.  Also,
  we intend to make targeting a specific annex optional in the near future, so
  this may be largely wasted work.  (If you _want_ a job only to run on a
  specific annex and change your mind, I guess such a tool would be useful.)
- Should `htcondor annex create` not have "mandatory options" (named
  arguments)?  This was done without much thought, but since all of the
  machine names are also valid annex names, it seems like maybe
  purely postional arguments aren't the right thing either.  Another argument
  in favor would be if we were being careful to be consistent/orthogonal
  across all our commands...
- Add `hpc_annex_lifetime` to the startds for `annex status`'s convenience
  (so that we can always say how long the annex has left, even if the local
  universe job was removed or submitted on a different machine)?
- Improve the job transforms in the metaknob.
  - `ANNEX_TOKEN_DOMAIN = $(2:$(ANNEX_COLLECTOR))
  - Replace the expression in the second (optional) transform with another
    defaulted variable so that it can be tweaked more easily.
