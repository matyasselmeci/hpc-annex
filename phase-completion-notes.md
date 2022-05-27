Phase 1
-------

We need to get all of the C++ code changes in before the code freeze.
In particular:
- [x]  (HTCONDOR-1024)  `condor_token_fetch -key`; in code review.
- [x]  (HTCONDOR-1015)  `htcondor job submit --annex-name` as a job transform.
- [x]  (HTCONDOR-1022)  Add a job transform to prevent inadvertent flocking.

Required changes before the release:
- [x]  (HTCONDOR-1025)  Modify `htcondor job submit --annex-name` to use job transform.
- [x]  (HTCONDOR-1033)  2022-03-25 demo feedback.  (ToddM)  Parts will become other tickets, some in
       phase 2).
- [x]  (HTCONDOR-1020)  Fetch a new token on every annex creation;
       in progress.  (ToddM)  Will need to add the "step X of Y" treatment
       to the Bridges 2 back-end on merge.
- [x]  (HTCONDOR-983)   The Bridges 2 back-end; in code review.  (ToddM)         
- [x]  We need to add the HPC annex CM as an old-school flock target on login*.osgconnect.net;
       per-user flocking is broken for multiple users (flocking to the same CM).
- [ ]  (HTCONDOR-958)   Documentation and code review.

Good ideas:
- [x]  (HTCONDOR-1021)  The `htcondor annex` nouns should check if `HPC_ANNEX_ENABLED`
       is set and politely refuse to do anything if not.  Done for `htcondor job submit --annex-name`
       in HTCONDOR-1025.  (JasonP)

Phase 1.5
---------

- [ ]  (HTCONDOR-1088)  EXECUTE should be on local disk.
- [ ]  (HTCONDOR-1089)  Refactor back-end scripts.  All of the machines so far share identical
       `.pilot` and `.multi-pilot` scripts, so we should just condense them.
       The `.sh` scripts are all very similar; it should be possible to make
       one script and have it source in machine-specific overrides (function
       redefinitions) as necessary, or something.
- [ ] Improve the job transforms in the metaknob.
  - `ANNEX_TOKEN_DOMAIN = $(2:$(ANNEX_COLLECTOR))
  - Replace the expression in the second (optional) transform with another
    defaulted variable so that it can be tweaked more easily.
- [ ] Add `hpc_annex_lifetime` to the startds for `annex status`'s convenience
  (so that we can always say how long the annex has left, even if the local
  universe job was removed or submitted on a different machine)?

Phase 2+
--------

- [ ]  Write a retro design doc for Phase 1.
- [ ]  Write a proto design doc for Phase 2. ;)
- [x]  Finish debugging Anvil back-end.
- [ ]  Frontera back-end.  (Blocked on BrianB for access.)
- `htcondor annex create` needs to know about the various queue restrictions
  and enforce them itself, so it doesn't make the user login only to get
  bounced back right away for an invalid request.  Some of this information
  has already been encoded, but none if it is currently being use, and it
  should probably be read from a config file   (of some sort) instead.
- For now, barring requests from our UI/UX people and/or the users, the
  front-end will know if a given queue works with whole nodes or allocates
  individual cores (or chunks of RAM) and require the user to specify the
  size appropriately.
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
- Look into supporting "noun" plug-ins in `htcondor`.  This may be a (partial)
  solution to the documentation problem, but `htcondor gromacs ...` also
  sounds really attractive to GregT.
- Some command, currently unnamed, to unbind a job from an annex.  It’s not
  clear if this is really worth it – ChristinaK thinks that many users may
  just instinctively remove and resubmit jobs targeting the wrong annex.  Also,
  we intend to make targeting a specific annex optional in the near future, so
  this may be largely wasted work.  (If you _want_ a job only to run on a
  specific annex and change your mind, I guess such a tool would be useful.)

Superceded
----------

- Miron has decreed (for now) that `create` and `add` are separate verbs.  We may
  radically change what those two verbs do, depending on what we end up deciding
  about the "annex template" issue.
  - Right now, `htcondor annex create` is used to both create annexes and expand
    them.  This is, at best, confusing.  We should certainly add something like
    `htcondor annex expand` (even if it’s just an alias); it’s not clear if we
    should also require users to specify expand rather than create if there’s
    already an annex by that name (as recorded in the local universe job queue).

- Miron decreed that `htcondor annex create` would have two positional arguments
  (and may decree a third for the project ID?). 
  - Should `htcondor annex create` not have "mandatory options" (named
    arguments)?  This was done without much thought, but since all of the
    machine names are also valid annex names, it seems like maybe
    purely postional arguments aren't the right thing either.  Another argument
    in favor would be if we were being careful to be consistent/orthogonal
  across all our commands...
