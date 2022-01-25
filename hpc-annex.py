#!/usr/bin/env python3


import os
import sys
import time
import fcntl
import atexit
import signal
import tempfile
import subprocess


INITIAL_CONNECTION_TIMEOUT = 180
REMOTE_CLEANUP_TIMEOUT = 60
REMOTE_MKDIR_TIMEOUT = 5
REMOTE_POPULATE_TIMEOUT = 60


def make_initial_ssh_connection(
	ssh_connection_sharing, ssh_target, ssh_indirect_command,
):
	proc = subprocess.Popen([
			'ssh', '-f',
			* ssh_connection_sharing,
			ssh_target,
			* ssh_indirect_command,
			'exit', '0',
		],
	)

	try:
		return proc.wait(timeout=INITIAL_CONNECTION_TIMEOUT)
	except subprocess.TimeoutExpired:
		print(f"Did not make initial connection after {INITIAL_CONNECTION_TIMEOUT} seconds, aborting.")
		sys.exit(1)

def remove_remote_temporary_directory(
	ssh_connection_sharing, ssh_target, ssh_indirect_command,
	script_dir
):
	if script_dir is not None:
		print("Cleaning up remote temporary directory...")
		proc = subprocess.Popen([
				'ssh',
				* ssh_connection_sharing,
				ssh_target,
				* ssh_indirect_command,
				'rm', '-fr', script_dir,
			],
		)

	try:
		return proc.wait(timeout=REMOTE_CLEANUP_TIMEOUT)
	except subprocess.TimeoutExpired:
		print(f"Did not clean up remote temporary directory after {INITIAL_CONNECTION_TIMEOUT} seconds, '{script_dir}' may need to be deleted manually.")


def make_remote_temporary_directory(
	ssh_connection_sharing, ssh_target, ssh_indirect_command,
):
	proc = subprocess.Popen([
			'ssh',
			* ssh_connection_sharing,
			ssh_target,
			* ssh_indirect_command,
			'mktemp', '--tmpdir=\\${SCRATCH}', '--directory'
		],
		stdout=subprocess.PIPE,
		stderr=subprocess.STDOUT,
		text=True,
	)

	try:
		out, err = proc.communicate(timeout=REMOTE_MKDIR_TIMEOUT)

		if proc.returncode == 0:
			return out.strip()
		else:
			print("Failed to make remote temporary directory, aborting.")
			print(out)

	except subprocess.TimeoutExpired:
		print(f"Failed to make remote temporary directory after {REMOTE_MKDIR_TIMEOUT} seconds, aborting.")
		proc.kill()
		out, err = proc.communicate()

	sys.exit(2)


def populate_remote_temporary_directory(
	ssh_connection_sharing, ssh_target, ssh_indirect_command,
	script_dir, token_file,
):
	files = f"{target}.sh {target}.pilot {target}.multi-pilot {token_file}"
	proc = subprocess.Popen([
			f'tar -c -f- {files} | ssh {" ".join(ssh_connection_sharing)} {ssh_target} {" ".join(ssh_indirect_command)} tar -C {script_dir} -x -f-'
		],
		shell=True,
		stdout=subprocess.PIPE,
		stderr=subprocess.STDOUT,
		text=True,
	)

	try:
		out, err = proc.communicate(timeout=REMOTE_POPULATE_TIMEOUT)

		if proc.returncode == 0:
			return 0
		else:
			print("Failed to populate remote temporary directory, aborting.")
			print(out)

	except subprocess.TimeoutExpired:
		print(f"Failed to populate remote temporary directory in {REMOTE_POPULATE_TIMEOUT} seconds, aborting.")
		proc.kill()
		out, err = proc.communicate()

	sys.exit(3)


def extract_full_lines(buffer):
	last_newline = buffer.rfind(b'\n')
	if last_newline == -1:
		return buffer, []

	lines = [line.decode('utf-8') for line in buffer[:last_newline].split(b'\n')]
	return buffer[last_newline + 1:], lines


def process_line(line):
	control = '=-.-= '
	if line.startswith(control):
		command = line[len(control):]
		attribute, value = command.split(' ')

		# FIXME Update the job ad with these values.  Also, record
		# somewhere -- I guess in a global? -- which of these pairs
		# we actually say.  The caller should clean up the job ad
		# if we didn't see one of them.  Actually, the caller
		# should pass in a lambda to call here, so we can just
		# update the values in there (and thus the caller) naturally.
		print(f"Found control {attribute} value {value}")

	else:
		print("   ", line)


def invoke_pilot_script(
	ssh_connection_sharing, ssh_target, ssh_indirect_command,
	script_dir, target, job_name, queue_name, collector, token_file,
	lifetime, owners, nodes, allocation
):
	args = [
		'ssh',
		* ssh_connection_sharing,
		ssh_target,
		* ssh_indirect_command,
		f'{script_dir}/{target}.sh',
		job_name, queue_name, collector, f"{script_dir}/{token_file}",
		str(lifetime), f"{script_dir}/{target}.pilot", owners, str(nodes),
		f"{script_dir}/{target}.multi-pilot"
	]
	if allocation is not None:
		args.append(allocation)
	proc = subprocess.Popen(
		args,
		stdout=subprocess.PIPE,
		stderr=subprocess.STDOUT,
		bufsize=0,
	)

	#
	# An alternative to nonblocking I/O and select.poll() would be to
	# spawn a thread to do blocking read()s and feed a queue.Queue;
	# the main thread would use queue.Queue.get_nowait().
	#
	# This should be pretty safe and easy to implement, but let's not
	# bother unless we need to (because we lose data while processing).
	#

	# Make the output stream nonblocking.
	out_fd = proc.stdout.fileno()
	flags = fcntl.fcntl(out_fd, fcntl.F_GETFL)
	fcntl.fcntl(out_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

	# Check to see if the child process is still alive.  Regardless, empty
	# the output stream, then process it.  If the child process was not alive,
	# we've read all of its output and are done.  Otherwise, repeat.

	out_bytes = bytes()
	out_buffer = bytes()

	while True:
		rc = proc.poll()

		while True:
			try:
				out_bytes = os.read(proc.stdout.fileno(), 1024)
				if len(out_bytes) == 0:
					break
				out_buffer += out_bytes

				# Process the output a line at a time, since the control
				# sequences where care about are newline-terminated.

				out_buffer, lines = extract_full_lines(out_buffer)
				for line in lines:
					process_line(line)

			# Python throws a BlockingIOError if an asynch FD is unready.
			except BlockingIOError:
				pass

		if rc == None:
			break

	# Print the remainder, if any.
	if len(out_buffer) != 0:
		print("   ", out_buffer.decode('utf-8'))
	print()

	return rc

if __name__ == "__main__":
	# FIXME: The primary command-line argument.
	target = "stampede2"

	# FIXME: command-line arguments (required).
	nodes = 2
	lifetime = 7200

	# FIXME: command-line options (may override defaults).
	job_name = "hpc-annex"
	queue_name = "development"
	owners = "tlmiller"
	allocation = None

	# Constants.  Not sure how these first two will get set in production.
	collector = "azaphrael.org"
	token_file = "pilot.token"

	control_path = os.path.expanduser("~/.hpc-annex")
	if not os.path.isdir(control_path):
		if not os.path.exists(control_path):
			os.mkdir(control_path)
		else:
			print("~/.hpc-annex must be a directory, aborting.")
			sys.exit(4)

	# Derived constants.
	ssh_connection_sharing = [
		'-o', 'ControlPersist="5m"',
		'-o', 'ControlMaster="auto"',
		'-o', f'ControlPath="{control_path}/master-%C"',
	]
	# FIXME: should be derived two command-line arguments with
	# $USER and 'login.xsede.org' as arguments.
	ssh_target = "tlmiller@login.xsede.org"
	ssh_indirect_command = [ "gsissh", target ]

	##
	## The user will do the 2FA/SSO dance here.
	##
	print("Making initial SSH connection...")
	print(f"  (You can run 'ssh {' '.join(ssh_connection_sharing)} {ssh_target}' to use the shared connection.)")
	rc = make_initial_ssh_connection(
		ssh_connection_sharing, ssh_target, ssh_indirect_command,
	)
	if rc != 0:
		print(f"Failed to make initial connection to {target}, aborting.")
		sys.exit(5)

	##
	## Register the clean-up function before creating the mess to clean-up.
	##
	script_dir = None

	# Allow atexit functions to run on SIGTERM.
	signal.signal(signal.SIGTERM, lambda signal, frame: sys.exit(128 + 15))
	# Hide the traceback on CTRL-C.
	signal.signal(signal.SIGINT, lambda signal, frame: sys.exit(128 + 2))
	# Remove the temporary directories on exit.
	atexit.register(lambda: remove_remote_temporary_directory(ssh_connection_sharing, ssh_target, ssh_indirect_command, script_dir))

	print("Making remote temporary directory...")
	script_dir = make_remote_temporary_directory(
		ssh_connection_sharing, ssh_target, ssh_indirect_command,
	)

	print(f"Populating {script_dir} ...")
	populate_remote_temporary_directory(
		ssh_connection_sharing, ssh_target, ssh_indirect_command,
		script_dir, token_file
	)
	print("... remote directory populated.")

	# FIXME: submit local universe job

	print(f"Submitting SLURM job on {target}:\n")
	invoke_pilot_script(
		ssh_connection_sharing, ssh_target, ssh_indirect_command,
		script_dir, target, job_name, queue_name, collector, token_file,
		lifetime, owners, nodes, allocation
	)
	print(f"... remote SLURM job submitted.")
