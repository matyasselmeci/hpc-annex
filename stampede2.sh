#!/bin/bash

BIRTH=`date +%s`
echo "Starting script at `date`..."

# FIXME: from the command line
JOB_NAME=hpc-annex
# FIXME: from the command line
QUEUE_NAME=development

#
# Download and configure the pilot on the head node before running it
# on the execute node(s).
#
# The following variables are constants.
#
# The binaries must be a tarball named condor-*, and unpacking that tarball
# must create a directory which also matches condor-*.
#
# The configuration must be a tarball which does NOT match condor-*.  It
# will be unpacked in the root of the directory created by unpacking the
# binaries and as such should contain files in local/config.d/*.
#

WELL_KNOWN_COLLECTOR=azaphrael.org
WELL_KNOWN_TOKEN_FILE=${HOME}/pilot.token
WELL_KNOWN_LOCATION_FOR_BINARIES=https://research.cs.wisc.edu/htcondor/tarball/current/9.3.2/update/condor-9.3.2-20211130-x86_64_CentOS7-stripped.tar.gz
WELL_KNOWN_LOCATION_FOR_CONFIGURATION=https://cs.wisc.edu/~tlmiller/hpc-config.tar.gz

#
# Create pilot-specific directory on shared storage.  The least-awful way
# to do this is by having the per-node script NOT exec condor_master, but
# instead configure the condor_master to exit well before the "run time"
# of the job, and the script carry on to do the clean-up.
#
# That won't work for multi-node jobs, which we'll need eventually, but
# we'll leave that for then.
#

echo "Creating temporary directory for pilot..."
PILOT_DIR=`/usr/bin/mktemp --directory --tmpdir=${SCRATCH} 2>&1`
if [[ $? != 0 ]]; then
    echo "Failed to create temporary directory for pilot, aborting."
    echo ${PILOT_DIR}
    exit 1
fi

function cleanup() {
    echo "Cleaning up temporary directory..."
    # FIXME
    # rm -fr ${PILOT_DIR}
}
trap cleanup EXIT

#
# Download the configuration.  (Should be smaller, and we fail if either
# of these downloads fail, so we may as well try this one first.)
#

cd ${PILOT_DIR}

echo "Downloading configuration..."
CONFIGURATION_FILE=`basename ${WELL_KNOWN_LOCATION_FOR_CONFIGURATION}`
CURL_LOGGING=`curl -fsSL ${WELL_KNOWN_LOCATION_FOR_CONFIGURATION} -o ${CONFIGURATION_FILE} 2>&1`
if [[ $? != 0 ]]; then
    echo "Failed to download configuration from '${WELL_KNOWN_LOCATION_FOR_CONFIGURATION}', aborting."
    echo ${CURL_LOGGING}
    exit 2
fi

#
# Download the binaries.
#
echo "Downloading binaries..."
BINARIES_FILE=`basename ${WELL_KNOWN_LOCATION_FOR_BINARIES}`
CURL_LOGGING=`curl -fsSL ${WELL_KNOWN_LOCATION_FOR_BINARIES} -o ${BINARIES_FILE} $2>&1`
if [[ $? != 0 ]]; then
    echo "Failed to download configuration from '${WELL_KNOWN_LOCATION_FOR_BINARIES}', aborting."
    echo ${CURL_LOGGING}
    exit 2
fi

#
# Unpack the binaries.
#
echo "Unpacking binaries..."
TAR_LOGGING=`tar -z -x -f ${BINARIES_FILE} 2>&1`
if [[ $? != 0 ]]; then
    echo "Failed to unpack binaries from '${BINARIES_FILE}', aborting."
    echo ${TAR_LOGGING}
    exit 3
fi

#
# Make the personal condor.
#
rm condor-*.tar.gz
cd condor-*

echo "Making a personal condor..."
MPC_LOGGING=`./bin/make-personal-from-tarball 2>&1`
if [[ $? != 0 ]]; then
    echo "Failed to make personal condor, aborting."
    echo ${MPC_LOGGING}
    exit 4
fi

# It may have take some time to get everything installed, so to make sure
# we get our full five minutes to clean up, subtract off how long we've
# been running already.
YOUTH=$((`date +%s` - ${BIRTH}))
# FIXME: from the command-line
LIFETIME=$((2 * 60 * 60))
DEATH=300
REMAINING_LIFETIME=$(((${LIFETIME} - ${YOUTH}) - ${DEATH}))

echo "Converting to a pilot..."
rm local/config.d/00-personal-condor
echo "
use role:execute
use security:recommended_v9_0
use feature:PartitionableSLot

COLLECTOR_HOST = ${WELL_KNOWN_COLLECTOR}

# We shouldn't ever actually need this, but it's convenient for testing.
SHARED_PORT_PORT = 0

# Allows condor_off (et alia) to work from the head node.
ALLOW_ADMINISTRATOR = \$(ALLOW_ADMINISTRATOR) $(whoami)@$(hostname)

# Eliminate a bogus, repeated warning in the logs.  This is a bug;
# it should be the default.
SEC_PASSWORD_DIRECTORY = \$(LOCAL_DIR)/passwords.d

# This is a bug; it should be the default.
SEC_TOKEN_SYSTEM_DIRECTORY = \$(LOCAL_DIR)/tokens.d
# Having to set it twice is also a bug.
SEC_TOKEN_DIRECTORY = \$(LOCAL_DIR)/tokens.d

# Don't run benchmarks.
RUNBENCHMARKS = FALSE

# We definitely need CCB.
CCB_ADDRESS = \$(COLLECTOR_HOST)

# On the Knight's Bridge nodes, the hyperthreads-to-RAM ratio is pants.  It
# should be less queue-specific to just turn off counting hyperthreads.
#
# COUNT_HYPERTHREAD_CPUS = FALSE
#
# Rather than figure out why things start falling apart at 68 jobs, let's
# just have a plausible reason for having fewer.
#
NUM_CPUS = \$(DETECTED_MEMORY) / 2048

#
# Commit suicide after being idle for five minutes.
#
STARTD_NOCLAIM_SHUTDOWN = 300

#
# Don't run for more than two hours, to make sure we have time to clean up.
#
MASTER.DAEMON_SHUTDOWN_FAST = (CurrentTime - DaemonStartTime) > ${REMAINING_LIFETIME}

" > local/config.d/00-basic-pilot

mkdir local/passwords.d
mkdir local/tokens.d
cp ${WELL_KNOWN_TOKEN_FILE} local/tokens.d

#
# Unpack the configuration on top.
#

echo "Unpacking configuration..."
TAR_LOGGING=`tar -z -x -f ../${CONFIGURATION_FILE} 2>&1`
if [[ $? != 0 ]]; then
    echo "Failed to unpack binaries from '${CONFIGURATION_FILE}', aborting."
    echo ${TAR_LOGGING}
    exit 5
fi

#
# Add our own customizations to the end.  This includes a more-restrictive
# START expression and the suicide-if-idle-for-too-long bits.
#

#
# Write the SLURM job.
#
# FIXME: we'll work on appropriate sizes and durations later.
#
echo '#!/bin/bash' > ${PILOT_DIR}/stampede2.slurm
echo "
#SBATCH -J ${JOB_NAME}
#SBATCH -o ${PILOT_DIR}/%j.out
#SBATCH -e ${PILOT_DIR}/%j.err
#SBATCH -p ${QUEUE_NAME}
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 02:00:00

# FIXME: ...
${HOME}/hpc-annex/stampede2.pilot ${PILOT_DIR}
" >> ${PILOT_DIR}/stampede2.slurm

#
# Submit the SLURM job.
#
echo "Submitting SLURM job..."
SBATCH_LOGGING=`sbatch ${PILOT_DIR}/stampede2.slurm 2>&1`
if [[ $? != 0 ]]; then
    echo "Failed to submit job to SLURM ($?), aborting."
    echo ${SBATCH_LOGGING}
    exit 6
fi
echo "..done."

# Reset the EXIT trap so that we don't delete the temporary directory
# that the SLURM job needs.
trap EXIT
exit 0
