UX/UI Work
----------

`htcondor job submit ...`

Implement `--annex-name <annex-name>`, which limits the submitted job to
running on _annex-name_.

The annex will be reporting to another collector with a user-specific IDTOKEN.
This command will add per-job flocking to the submitted job.  It will alter
the job's requirements to match the given _annex-name_ to the machine-ad
attribute `AnnexName`, as well as `AuthenticatedIdentity` to
`<user-name>@annex.osgdev.chtc.io`.  This should suffice to prevent the job
from running anywhere else, but if we can something to exclude it from the
default central manager's matchmaking, so much the better.

[] TODO: Alter the CM's configuration to require that `AnnexName` is set
in all of its ads.  This will let us write the requirement for the
authenticated identity conditioned on the machine having an `AnnexName`,
which will make it easier for the job to run elsewhere, should we allow
that in the future.

&nbsp;

`htcondor annex create ...`

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

&nbsp;

`htcondor annex status <annex-name>`

The status of _annex-name_ will be obtainable from either the annex
collector (a configuration constant) or from one or more local
universe jobs being used to store state in their `hpc_annex_*`
attributes.  These attributes will include the _annex-name_.  An
annex with just a local-universe job is considering "pending."
Otherwise, report on the size of the annex (reported cores) and
how many jobs it's currently running.

&nbsp;

`htcondor job resources <job-ad>`

This command exists but isn't documented in the output of
`htcondor jobs`.  If it doesn't work properly for annex
jobs (I don't know why it wouldn't), it needs fixing.

&nbsp;

`htcondor annex shutdown <annex-name>`

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
