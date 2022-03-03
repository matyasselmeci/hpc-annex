Feature Work
------------

- [ ] (ToddM) Share `.sif` files between different machines in the same annex
  (request).
  
  In the glorious future, HTCondor will manage this automatically,
  most likely by means of an AP-managed per-claim sandbox.
  
  For the present, observe the following.
  - Given a set of jobs, we can relatively easily determine the full
    path to each and every `.sif` file that will be used by the jobs.
  - We can easily determine the set of jobs by marking the ones submitted
    with the `--annex-name` flag appropriately.
  - We can transfer files at annex creation time.
  Thus, at annex creation time, we can transfer all the `.sif` files used
  by jobs marked for that annex at that time.
  
  This, however, is not sufficient; HTCondor will still transfer the `.sif`
  file for each job.  So when we create the annex, we modify the job(s)
  marked for that annex to (a) specify the absolute path to the pre-staged
  `.sif` file and (b) set `transfer_container` to `no`.  This will prevent
  the jobs from running on other resources, but for now, that's OK (and
  see the first task, below).
  
  For software engineering purposes, the code to make this happen should
  be sufficiently well-isolated that it could easily be called as part
  of a future command that adds an existing set of jobs to an existing
  annex.  (This will require the user log-in again.)
  
  If we need to allow jobs to run off the annex before the AP's sandbox
  becomes available, we may be able to change HTCondor to evaluate
  `transfer_container` in the shadow in the context of the machine ad,
  which would allow us to not transfer the .sif file if we're running
  on an annex of the right name (or that advertises having a pre-staged
  `.sif` file).  This would let a startd transform on the EP fix up the
  `.sif` file's location.

UX/UI Work
----------

- [x] (ToddM) `htcondor job submit ...`

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

- [ ] (Jason) `htcondor annex create ...`

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
    probably understand `~`, and be set to `~/.condor/tokens.d/<user>@annex.osgdev.chtc.io`,
    since that's the principal we'll be issuing tokens for
    automagically at some point.
  
  Important (Miron) note: if `htcondor annex create` doesn't find any jobs
  tagged with the given annex name, it should refuse to create an annex
  and say why (because there aren't jobs in the queue for it).  See above,
  about sharing `.sif` files, for why this is a good idea.

- [x] `htcondor annex status <annex-name>`

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

- [x] (ToddM) `htcondor annex shutdown <annex-name>`

  Shut down the annex.  The corresponding SLURM job(s) will terminate
  when the the startds shut themselves down, so we'd like to use
  HTCondor's security mechanisms if at all possible.  This will
  require additional back-end configuration, because right now HTCondor
  won't let us use the collector to pass an admin capability from
  the startd.  (Instead, we use a user-speific PASSWORD file.)
  
  - [ ] (ToddM) JaimeF is currently reviewing a PR that will 80% solve
    this problem, but would required the annex creator to have ADMIN
    level auth'n at the collector.  We think it could easily be extended
    to allow an identity authenticated by a method in the ADMIN list which
    matches the `AuthorizedIdentity` of the ad as well.

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

- [ ] (Mat) `Bridges 2`
- [ ] (Mat) `Expanse`
