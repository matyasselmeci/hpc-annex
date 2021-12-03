#!/bin/bash

#
# The "normal" queue on Stampede2 is limited to 256 nodes, 48 hours
# and 50 jobs; the nodes are Knights Landing.
#
# It may be easier to deal with the "skx-normal" queue, which is limited
# to 128 nodes, 48 hours, and 20 jobs, because the nodes are Sky Lake.
#

#
# We'll begin with a single serial job.  We may need to switch this around
# a little bit to run more startds; the documentation seems to suggest
# using the 'launcher' module to do this.
#

# begin SLURM magic

#SBATCH -J hpc-annex       # Job name
#SBATCH -o hpc-annex/%j.out
#SBATCH -e hpc-annex/%j.err
#SBATCH -p normal          # Queue (partition) name
#SBATCH -N 1               # Total # of nodes (must be 1 for serial)
#SBATCH -n 1               # Total # of mpi tasks (should be 1 for serial)
#SBATCH -t 00:30:00        # Run time (hh:mm:ss)
#SBATCH --mail-user=tlmiller@cs.wisc.edu
#SBATCH --mail-type=all    # Send email at begin and end of job

# end SLURM magic

