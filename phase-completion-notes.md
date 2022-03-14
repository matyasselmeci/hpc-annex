Phase 1
-------

- [ ]  (Mat)  Expanse back end.  Well on its way.
- [ ]  Bridges 2 back end.
- [ ]  Minimal front-end changes to support new machines.
- [ ]  HTCONDOR-1004
- [ ]  How do we deal with documentation and --help for features not intended for general use?
       (ToddT is thinking maybe we can reduce the infrastructure requirements so that it's
       reasonable to document them.)

Phase 2+
--------

- `htcondor annex create` needs to know about the various queue restrictions and enforce them
  itself, so it doesn't make the user login only to get bounced back right away for an invalid
  request.
- Frontera back-end.
- Support adding jobs to an annex after its creation.
  - Running `htcondor job submit --annex-name` will only work right now (for container-universe jobs) if:
    - the container image was already staged to the annex, and
    - `container_image` is a basename.
    This is because of limitations in the hand-rigged `.sif` file-sharing implementation.  Neither
    restriction would apply if we had AP-managed sandboxes.  However, if that takes too long to
    arrive, we could write a script to copy the `.sif` files to the right place (which would require
    the user to log-in again).
- Add a tool that targets jobs to annex after their submission.  Presently, this would make them
  run _only_ on that annex.  This is currently required at a technical level because of the
  container image restrictions mentioned above, and because the annex attempts to prevent random jobs
  from the same user from running on them.  The latter is a UI/UX choice that could be revisited,
  especially if the job could otherwise run unmodified elsewhere (once the container image restrictions
  are lifted).
- Allow annex creation before job submission (for DAGMan).  Again, this requires removing the
  current restrictions on container images.
- Replace the current PASSWORD-based `htcondor annex shutdown` implementation with one based on
  passing admin capabilities through the collector.
- If we still need to rewrite jobs, mark them so we don't rewrite them again.
- Implement `htcondor jobset submit annex-name`.  We're going to need it.
- Pull resource requests from the annex collector rather than push them to the pilot via command-line
  arguments, mostly for strategic reasons.
- For now, barring requests from our UI/UX people and/or the users, the front-end will know if a given
  queue works with whole nodes or allocates individual cores (or chunks of RAM) and require the user
  to specify the size appropriately.
- Look into supporting "noun" plug-ins in `htcondor`.  This may be a (partial) solution to the
  documentation problem, but `htcondor gromacs ...` also sounds really attractive to GregT.
