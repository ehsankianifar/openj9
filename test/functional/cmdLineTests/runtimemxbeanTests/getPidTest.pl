#!/usr/bin/perl

##############################################################################
#  Copyright IBM Corp. and others 2017
#
#  This program and the accompanying materials are made available under
#  the terms of the Eclipse Public License 2.0 which accompanies this
#  distribution and is available at https://www.eclipse.org/legal/epl-2.0/
#  or the Apache License, Version 2.0 which accompanies this distribution and
#  is available at https://www.apache.org/licenses/LICENSE-2.0.
#
#  This Source Code may also be made available under the following
#  Secondary Licenses when the conditions for such availability set
#  forth in the Eclipse Public License, v. 2.0 are satisfied: GNU
#  General Public License, version 2 with the GNU Classpath
#  Exception [1] and GNU General Public License, version 2 with the
#  OpenJDK Assembly Exception [2].
#
#  [1] https://www.gnu.org/software/classpath/license.html
#  [2] https://openjdk.org/legal/assembly-exception.html
#
#  SPDX-License-Identifier: EPL-2.0 OR Apache-2.0 OR GPL-2.0-only WITH Classpath-exception-2.0 OR GPL-2.0-only WITH OpenJDK-assembly-exception-1.0
##############################################################################

use strict;
use warnings;
use IPC::Open3;
use IO::Select;

my $javaCmd = join(' ', @ARGV);

my ($in, $out, $err);

my $perlPid;

my $javaPid;

if ($^O eq 'cygwin') {
	open3($in, $out, $err, $javaCmd);
	$javaPid = <$out>;
	# Command gets the list of PIDs of the Java processes system is running
	$perlPid = `powershell -Command "& { Get-Process java | Select-Object -ExpandProperty Id }"`;
	print $in "getPid finished";
	# String trim both sides of javaPid and perlPid for the index check
	$javaPid =~ s/^\s+|\s+$//g;
	$perlPid =~ s/^\s+|\s+$//g;
	# After trimming, check if javaPid is in the list of PIDs system returns
	# index() would return an index if it is in the list, return -1 otherwise
	# (PASS if not -1)
	if (index($perlPid, $javaPid) != -1) {
		$perlPid = $javaPid;
	}
} else {
	$perlPid = open3($in, $out, $err, $javaCmd);
	my $s = IO::Select->new();
	$s->add($out);
	$javaPid = 0;
	while (my @ready = $s->can_read(5)) { # set timeout of 5 seconds
		my $buf = '';
		$! = 0;
		my $read = sysread($ready[0], $buf, 1024);
		if (defined($read)) {
			if ($buf =~ /^\d+$/) {
				$javaPid = $buf;
				last;
			}
		} else {
			print "Error in reading output of the Java process\n";
			last;
		}
	}
	print $in "getPid finished";
}

if ($perlPid == $javaPid) {
	print "PASS: RuntimeMXBean.getPid() returned correct PID.";
}
else {
	print "FAIL: RuntimeMXBean.getPID() returned ${javaPid} instead of ${perlPid}";
}
