#!/usr/bin/env python3

#
# The initial task for this script is to write a function which, given the
# correct arguments, will create-or-reuse a connection through login.xsede.org
# to the target machine and execute the given command there.
#
# There are five use cases:
#
# (a) run the command and throw away the exit code and output and error
#     streams; no input stream will be provided.  (`rm -fr ${SCRIPT_DIR}`)
# (b) run a null command (`exit 0`) to initialize the SSH connection.  This
#     version must allow the user to interact as normal at the terminal,
#     but should return the exit code.
# (c) run a command and return the exit code and a log of the combined
#     output and error streams.  (`mktemp --tmpdir ... --directory`)
# (d) as (c), except that the command's standard input will be supplied
#     from a pipe.  (`tar -c -f- ${FILES} | ... | tar -C ... -x -f-`)
#     It may be easier to instead implement as (c), except for a parameter
#     which will be executed locally and whose standard output will be
#     be redirected.
# (e) as (c), except that the command's combined output and error streams
#     must be returned as a stream instead of in a log.  Obviously, this
#     makes return the exit code from the same call impossible.
#
# As for implementation, (c) can be implemented by calling (d) with /dev/null
# for the input stream.  Likewise, (a) could be implemented by calling (c)
# and throwing away parts of the results.  One could implement (d) by
# calling (e) and blocking on the exit result becoming available, if (e)
# allowed specification of the input FD.  In such a case, (b) could be
# implemented by wiring the input, output, and error FDs appropriately.
#
# We probably have to use FDs, rather than Python stream, to ensure that
# [pseudo-]TTY allocation/inheritance happens correctly.
#

