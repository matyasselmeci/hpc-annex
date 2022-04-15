Original Design
===============

The original design for the HPC Annex minimized what the AP admin(s) would
have to do in part to avoid administrative overheads, in part thinking
that such a design would be more plausibly useful outside of the one place
where the PEP goal required that the HPC annex software work.

HTCondor Architecture
---------------------

This design used a separate central manager to
  - make security easier to deal with
  - and to avoid altering a user's priority in the existing pool and
    punishing them for bringing their own resources.
(For OSG Connect, we -- the developers -- would deploy a CM in Tiger.)

Jobs targeting an annex would use per-using flocking to get to the
CM.  This required that the user have a token for that CM in
`~/.condor/tokens.d` (for as long as they wanted their jobs to run).
Such a token could also be used for connecting the pilot jobs on the
HPC systems to the annex CM.

Software Architecture
---------------------

These HPC tools have one front-end (the UI) and a back-end script for
each HPC machine we care about (Stampede 2, Anvil, Expanse, and Bridges 2);
for convenience, each back-end script currently assumes that its corresponding
pilot scripts exist, rather than write it out itself.

Researchers do not interact with the back-end.  They request annexes
via the front-end, whose interface will be consistent across back-ends and
as abstract as possible.  The reason we're using a manual front-end tool is
primarily because of two-factor authentication: we need the user to to
authorize connections on our behalf.  The front-end will therefore invoke
SSH with the appropriate options to establish a shared connection, so that
the front-end can return as soon as possible to the user.

The front-end will use the shared connection to transfer the back-end
script(s) to the target machine.  We intend to keep the connection open
(and the researcher waiting) for error reporting and handling purposes until
the pilot job goes into the queue.  By that time, the front-end will have
submitted the local-universe job responsible for maintaining state about
the newly-created HPC annex, and future invocations of the front-end will
be able to use the queue to retrieve that state.  Additionally, the front-end
is responsible for the initial staging of `.sif` files (based on which ones
are required by jobs targeting the annex at submissions time).  These files
will be stored and shared storage, and the job will transformed at submit time
(to make sure the `.sif` is not transferred) and again by the startd (to
point its `.sif` file at the prestaged copy).

The front-end is (will be) responsible for machine-specific logical constraints,
because it would suck for the user to go through the log-in sign and dance
and then be told about a logic error we could have detected earlier.

The back-end is responsible for downloading HTCondor and any administrative
customization of the pilot config from the corresponding well-known
locations.  (Barring truly dire need, the pilots will use the official
release tarballs.)  It is also responsible for constructing the pilot's on-disk
environment in a temporary directory and submitting the pilot(s) as a job to the
local batch system.  To support multi-node jobs (necessary, because some SLURM
queues have very shallow depth/simultaneous jobs limits), we run a script that
SSHs to each node in the job (including itself) and waits for the master to
terminate.  When they're all done, it's safe to clean up the shared directory.

While it's not necessary for the back-ends to share command-line arguments
and semantics, it seems like it would make the front-end's job quite a bit
easier, and so it is strongly encouraged; at a minimum, we really want error
reporting and failure modes to be the same.  It would also be nice, if it's
reasonable, for the back-ends to share code as well: maybe not be the same
script and switching on $ARGV[0], but perhaps sourcing or invoking
machine-specific functions or functionality appropriately.  (One could source
the common functions or functionality instead.)  It would be be responsibility
of the front-end to transfer a machine-specific file for sourcing, if that's
the implementation.

9.8.0 Design
============

HTCondor Architecture
---------------------

The 9.8.0 design was severely compromised by the discovery that
per-user flocking
  - only works for one user at a time
  - and flocks all of that user's jobs, not just the marked ones.

We therefore had to result to administrative-level flocking and
use job transforms to protect non-annex jobs from rogue nodes
added using an annex security credential (whether accidentally
or maliciously misconfigured).

Additionally, ToddT felt that asking the OSG connect admins to create
and distribute a token for every new user was too much.  Instead, the
`htcondor` CLI should generate a new (temporary) token every time it
needed one.  This has the advantage of making it easy to replace the
token signing key, because the old tokens don't need to be explicitly
invalidated or replaced.  Since we were no long using per-user flocking,
this became plausible.  In practice, creating the token is probably only
mandatory for `htcondor annex create`, because it needs to be copied
to the pilot job.  Otherwise, the `htcondor` CLI doesn't ever actually
write to the collector; SSL-secured anonymous `READ` access is
perfectly sufficient.

Because we still haven't implement remote key-sigining, the annex CM's
key must be on every AP which wishes to use the CM, and additional code
in HTCondor was required to allow `condor_token_request` to specify a
non-default signing key.  Further code could be added to allow the
request to specify the issuer; without it, we must artificially ensure
that the `TRUST_DOMAIN` is the same on all APs flocking to the annex CM.
On the other hand, remote key-signing is better anyway, so we should
just do that instead.  (Which should also eliminate the temptation to
add yet another option specifying the `UID_DOMAIN` to request.)

For lack of a better way to handle it (see below), the HPC annex uses
the `PASSWORD` method to enable remote administration (shutdown).

Software Architecture
---------------------

The software architecture is almost unchanged from its original conception,
although it is incomplete.  (For instance, the front-end doesn't help the
user avoid requesting impossible things.)  In practice, it turns out that the
pilot-creation scripts are very similar, and the the pilot scripts proper are
identical on all four machines.

Further Refinements
===================

HTCondor Architecture
---------------------

The general idea, again, is that the AP admin shouldn't have to know or do
anything if the user wants to bring their own resource.

- Fix per-user flocking so that we don't need to set up global flocking.
  This will probably involve
  - implementing session invalidation for per-user flock targets;
  - not caching the same session/daemon client object for different owners;
  - and only flocking jobs with `FlockTo` set.
- Allow startd remote administration capability to be retrieved by the
  same `AuthenticatedIdentity` that advertised it; this will eliminate the
  need to use PASSWORD (and maintain a per-user private password file) for
  administration.
- Implement token request forwarding, so that we don't have to have the same
  `TRUST_DOMAIN` on the APs and the annex CM.  This will also allow us to
  use the CM's `UID_DOMAIN` in all cases in the job transforms used to control
  flocking, which will simplify administration further.  (Assuming, and we can
  easily ensure this, that the UID_DOMAIN of the Annex CM isn't the same as any
  of the APs.)

Software Architecture
---------------------

- The back-end scripts
  - should arrange for EXECUTE to be on local disk.
  - should be refactored (see above).
  - should pull/answer resource requests in the HPC Annex collector,
    rather than depend on that information being embedded in the
    command-line.  This may simplify the back-end (yay!), but more
    importantly, serve the strategic purpose of establish a convention
    useful for moving glide-ins/pilots to a pull model.
- Improve the implementation of the job transforms in the metaknob.
  - `ANNEX_TOKEN_DOMAIN = $(2:$(ANNEX_COLLECTOR))`
  - Replace the expression in the second (optional) transform with
    another defaulted variable so that it can be tweaked more easily.

We will need to allow more flexibility in binding and unbinding jobs
and annexes, and obviously allow multiple jobs (perhaps only jobsets?)
to be submitted.  However, we're in the middle of ongoing discussions
for big UI/UX changes for Phase 2, so this work should probably be
delayed until we get that sorted out.

We should implement AP-managed (and shared FS -aware) sandboxes and
eliminate the manual prestaging done by the HPC Annex tools.  This
should make job/annex binding considerably simpler.

Anticipated Future Design
=========================

(This section will become part of the "phase 2" design doc.)

ToddT anticipates having the startds report directly to the AP from which
the annex was requested.  This should eliminate the need for someone to
maintain an annex CM, but it's not clear that simply querying the schedd
for the startd as if it were a collector will work.  Likewise, the
implications for control over which jobs go where are unclear, are as the
effects of such startds on a user's priority (or priority-equivalent,
depending on how the AP schedules).  Likewise, it's unclear if the method
proposed for remote administration above would work.
