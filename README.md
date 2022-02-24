# HPC Annex

This project is a set of tools designed to support the bring-your-own-resources model for the OS Pool.

#### hpc-annex.py

Run this script to test the back-end scripts.  It has a bunch of random constants in it, some of which
you'll need to change in order to make things work for you.  It assumes the existence of a local schedd
(to which it will submit local-universe jobs for state-tracking).  It assumes that the caller has an
account at login.xsede.org and the ability to gsissh to the HPC machine(s) from there.

#### local.py

The local-universe job.

#### stampede2.multi-pilot

SLURM doesn't actually ever start jobs concurrently (at least not the way we're using it).  This script
is the SLURM job and in charge of starting `stampede2.pilot` on each machine assigned to the SLURM job.
It also cleans up the temporary directory when all of those pilot scripts have completed.

Although the script is named to be specific to Stampede 2, I don't think that it actually is.

#### stampede2.pilot

Start a single pilot (condor_master).

Although the script is named to be specific to Stampede 2, I don't think that it actually is.

#### stampede2.sh

This is the magic shell script that creates a complete personal condor in a shared directory
on Stampede 2, and then submits a SLURM job which runs it (see `stampede2.multi-pilot`).  I
expect that large parts of it are re-usable, if not directly shareable, across other machines.
