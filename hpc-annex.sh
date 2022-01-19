#!/bin/bash

## From the user.
TARGET="stampede2"
JOB_NAME="hpc-annex"

## Defaults.
QUEUE_NAME="development"
COLLECTOR="azaphrael.org"
LIFETIME=7200
OWNERS=`whoami`
NODES=1
SSH_TARGET="login.xsede.org"
SSH_INDIRECT_COMMAND="gsissh ${TARGET}"

## Things we need to know.
# This must be a basename.
TOKEN_FILE=pilot.token

# For testing.
NODES=2

# -------------------------------------
# This should be removed in production.
CONTROL_PATH=~/.ssh/sockets
PRESERVE_CONTROL_PATH=TRUE
# -------------------------------------

if [[ -z $CONTROL_PATH ]]; then
	CONTROL_PATH=`/bin/mktemp --directory 2>&1`
	if [[ $? != 0 ]]; then
		echo "Failed to create local temporary directory, aborting."
		echo ${CONTROL_PATH}
		exit 1
	fi
fi

# ControlPersist may not be a good idea in general,
# but it avoids stupid duo-based complications in testing.
CONNECTION_SHARING='-o ControlPersist="5m" -o ControlMaster="auto" -o ControlPath="'${CONTROL_PATH}'/master-%C"'

function cleanup() {
	if [[ -z $PRESERVE_CONTROL_PATH ]]; then
		echo "Cleaning up local temporary directory..."
		rm -fr ${CONTROL_PATH}
	fi

	if [[ -n $SCRIPT_DIR ]]; then
		echo "Cleaning up remote temporary directory..."
#		ssh \
#			${CONNECTION_SHARING} \
#			${SSH_TARGET} \
#			${SSH_INDIRECT_COMMAND} \
#			rm -fr ${SCRIPT_DIR}
	fi
}
trap cleanup EXIT


## The user will do the 2FA/SSO dance here.
##
## SSH ignores -f if the connection is re-used,
## so depend on ControlPersist for now.
echo "Making intial SSH connection..."
ssh \
	-f \
	${CONNECTION_SHARING} \
	${SSH_TARGET} \
	${SSH_INDIRECT_COMMAND} \
	exit 0

## Copy the back-end scripts to the target.
echo "Making remote temporary directory..."
SCRIPT_DIR=`ssh \
	${CONNECTION_SHARING} \
	${SSH_TARGET} \
	${SSH_INDIRECT_COMMAND} \
	mktemp --tmpdir='\\\${SCRATCH}' --directory 2>&1`
if [[ $? != 0 ]]; then
	echo "Failed to make remote temporary directory, aborting."
	echo ${SCRIPT_DIR}
	exit 2
fi

echo "Copying back-end scripts to ${SCRIPT_DIR} on ${TARGET}..."
FILES="${TARGET}.sh ${TARGET}.pilot ${TARGET}.multi-pilot ${TOKEN_FILE}"
COPY_LOGGING=`tar -c -f- ${FILES} | \
	ssh \
	${CONNECTION_SHARING} \
	${SSH_TARGET} \
	${SSH_INDIRECT_COMMAND} \
	tar -C ${SCRIPT_DIR} -x -f-`
if [[ $? != 0 ]]; then
	echo "Failed to copy scripts to ${TARGET}, aborting."
	echo ${COPY_LOGGING}
	exit 3
fi
echo "... scripts copied to ${SCRIPT_DIR} on ${TARGET}."


## FIXME all of the LOGGING should probably be () 2>&1, but this whole
## script will probably become Python sooner rather than later...
##
## Until then, note that it would be nice to just run the pilot script,
## since it prints out its own progress...

## Invoke the pilot script.
echo "Submitting SLURM job on ${TARGET}..."
ssh \
	${CONNECTION_SHARING} \
	${SSH_TARGET} \
	${SSH_INDIRECT_COMMAND} \
	${SCRIPT_DIR}/${TARGET}.sh \
		${JOB_NAME} ${QUEUE_NAME} ${COLLECTOR} ${SCRIPT_DIR}/${TOKEN_FILE} ${LIFETIME} \
		${SCRIPT_DIR}/${TARGET}.pilot ${OWNERS} ${NODES} \
		${SCRIPT_DIR}/${TARGET}.multi-pilot
exit $?
