Feature Work
------------

- [ ] Share `.sif` files between different machines in the same annex
  (request).

  Given the first point, below, we can relatively easily determine the
  full path to each and every `.sif` file that will be used by the jobs
  in the queue when the annex is created.
  We can than transfer (using scp over the shared connection) those
  `.sif` files to a directory that will be cleaned up (because the pilot
  already does) on the shared filesystem.
  
  For software engineering purposes, the code to make this happen should
  be sufficiently well-isolated that it could easily be called as part
  of a future command that adds an existing set of jobs to an existing
  annex (rather than submits them only there).
  
  For now, let's not worry about
  letting jobs created by the step below run anywhere else; it seems like
  sharing `.sif` files is largely a special case of pre-staged data, or
  of granting the AP its own sandbox, and we should figure that out before
  trying to do anything very clever.  In that case, we can rewrite the
  jobs to request that the `.sif` file never be transferred (see the
  container universe documentation) and set up a stard transform in the
  pilot to prepend the full path to the shared `.sif` directory.
  
  - [ ] It may not be hard to instead change HTCondor to evaluate
    `transfer_container` in the shadow in the context of the machine ad,
    which would allow us to not transfer the .sif file if we're running
    on an annex of the right name (or that advertises having a pre-staged
    .sif file).  This would let a startd transform on the EP fix up the
    .sif file's location.

UX/UI Work
----------

- [ ] `htcondor job submit ...`

  Implement `--annex-name <annex-name>`, which limits the submitted job to
  running on _annex-name_.

  The annex will be reporting to another collector with a user-specific IDTOKEN.
  This command will add per-job flocking to the submitted job.  It will alter
  the job's requirements to match the given _annex-name_ to the machine-ad
  attribute `AnnexName`, as well as `AuthenticatedIdentity` to
  `<user-name>@annex.osgdev.chtc.io`.  This should suffice to prevent the job
  from running anywhere else, but if we can add something to exclude it from the
  default central manager's matchmaking, so much the better.
  
  Also tag the job so that `htcondor annex create` has an easier / more
  reliable time finding the jobs it needs to scan for .sif files.

- [ ] `htcondor annex create ...`

  The back-end for this command is already implemented by `htpc-annex.py`,
  although that script does not presently take any arguments.
  The required arguments in the UI include `--project`, to identify the
  allocation, `--name`, to set the _annex-name_, and `--machine`, to pick
  which HPC machine to use (initially, only Stampede 2 will be supported).
  The back-end needs to know how many nodes and the annex's lifetime,
  both of which the UI script can supply via defaults.  See `hpc-annex.py`
  near the beginning of the script proper, for details on the other
  required arguments.  Notes:

  - `owners` should be automagically generated in the singular but
    (eventually) allowed on the command-line.
  - `queue_name` should have a machine-specific default in the UI,
    but may also need a CLI option as well.
  - `collector` is configuration constant.  Not sure how to do
    configuration for this script.
  - `token_file` is also a configuration constant, but should
    probably understand `~`, e.g., be set to `~/.condor/pilot.token`.

- [ ] `htcondor annex status <annex-name>`

  The status of _annex-name_ will be obtainable from either the annex
  collector (a configuration constant) or from one or more local
  universe jobs being used to store state in their `hpc_annex_*`
  attributes.  These attributes will include the _annex-name_.  An
  annex with just a local-universe job is considering "pending."
  Otherwise, report on the size of the annex (reported cores) and
  how many jobs it's currently running.  If one _annex-name_ has
  multiple components, sum the components by type (in-collector
  or pending) and display the summed output for each type
  appropriately.

- [x] `htcondor job resources <job-ad>`

  This command exists but isn't documented in the output of
  `htcondor jobs`.  If it doesn't work properly for annex
  jobs (I don't know why it wouldn't), it needs fixing.
  
  This works fine.  It might be improved by mentioning the
  annex name explicitly; Miron may think that the output
  shouldn't include the slot name.

- [ ] `htcondor annex shutdown <annex-name>`

  Shut down the annex.  The corresponding SLURM job(s) will terminate
  when the the startds shut themselves down, so we'd like to use
  HTCondor's security mechanisms if at all possible.  This will
  require additional back-end configuration, because right now HTCondor
  won't let us use the collector to pass an admin capability from
  the startd.

  We can consider adding a command which reconnects to the HPC machine
  in question and `scancel`s the job later (it would require the user
  to reauthenticate).

Other Machines
--------------

The existing front- and back- end code should be broadly applicable to
Bridges 2 and Expanse because they're both accessible via `gsissh` from
`login.xsede.org`, XSEDE's SSO site.  It would be nice to share scripts
between the three, as well, but it's by no means required, and if doing
so would slow down adding either of the other two, then we should save
the refactoring for later.

- [ ] `Bridges 2`
- [ ] `Expanse`
