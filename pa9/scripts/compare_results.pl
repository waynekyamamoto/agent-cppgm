#!/usr/bin/perl

use strict;
use warnings;
use Cwd qw(getcwd);
use File::Basename qw(basename dirname);

if (scalar(@ARGV) != 3)
{
	die "Usage: compare_results.pl <ref_suffix> <my_suffix> <testlocation>";
}

my $ref_suffix = $ARGV[0];
my $my_suffix = $ARGV[1];
my $tests = $ARGV[2];
my $verbose = $ENV{VERBOSE} || $ENV{CPPGM_TEST_VERBOSE};
my $keep_going = $ENV{KEEP_GOING};
my $cwd = getcwd();
my $assignment = basename($cwd);
my $repo_root = dirname($cwd);

my @tests = grep { m/\.t\.1$/ } sort split(/\s+/, `find $tests -type f`);
my $suite_total = scalar(@tests);

my $npass = 0;
my $failed = 0;

sub rooted_path
{
	my ($path) = @_;
	return $path =~ m{^/} ? $path : "$cwd/$path";
}

sub fail_prefix
{
	return "$tests: FAIL after $npass/$suite_total passed\n";
}

sub rerun_hint
{
	return "To rerun this assignment with per-test output from the repo root:\n\n    \$ cd $repo_root && VERBOSE=1 make $assignment\n\n";
}

sub getdata
{
	my $file = shift @_;

	my $data = `cat $file`;
	$data =~ s/\s+$//;
	return $data;
}

	for my $test (@tests)
	{
		print "\n$test: " if $verbose;
	
		my $display_test = $keep_going ? "$assignment/$test" : $test;
		my $testbase = $test;
		$testbase =~ s/\.t\.1$//;
	
		my $ref = "$testbase.$ref_suffix";
		my $ref_impl_exit_status = "$ref.impl.exit_status";
		my $ref_program_exit_status = "$ref.program.exit_status";
		my $ref_program_stdout = "$ref.program.stdout";
	
		my $my = "$testbase.$my_suffix";
		my $my_impl_exit_status = "$my.impl.exit_status";
		my $my_program_exit_status = "$my.program.exit_status";
		my $my_program_stdout = "$my.program.stdout";
	
	if (getdata($ref_impl_exit_status) ne getdata($my_impl_exit_status))
	{
		print fail_prefix() unless $keep_going;
		if (getdata($my_impl_exit_status) eq "124") {
			print "$display_test: ERROR: Compilation timed out\n";
		} elsif (getdata($my_impl_exit_status) > 128) {
			print "$display_test: ERROR: Internal Compiler Error (Crash)\n";
		} else {
			print "$display_test: ERROR: Expected compilation exit status " . getdata($ref_impl_exit_status) . ", got " . getdata($my_impl_exit_status) . "\n";
		}
		if (!$keep_going) {
			print "\n";
			print rerun_hint();
			print "TEST FAIL\n";
		}
			$failed = 1;
			next if $keep_going;
			exit(1);
		}
		elsif (getdata($ref_impl_exit_status) ne "0")
		{
			$npass++;
			print "PASS\n\n" if $verbose;
		}
		elsif ((getdata($ref_program_exit_status) ne getdata($my_program_exit_status)) and
			(getdata($ref_program_stdout) ne getdata($my_program_stdout)))
		{
			print fail_prefix() unless $keep_going;
			if (getdata($my_program_exit_status) eq "124") {
				print "$display_test: ERROR: Program execution timed out\n";
			} elsif (getdata($my_program_exit_status) > 128) {
				print "$display_test: ERROR: Program Execution Error (Crash)\n";
			} else {
				print "$display_test: ERROR: Program execution does not match reference output and exit status\n";
			}
			if (!$keep_going) {
					print "\n";
					print rerun_hint();
					print "To compare generated program output:\n\n    \$ diff " . rooted_path($ref_program_stdout) . " " . rooted_path($my_program_stdout) . "\n\n";
					print "TEST FAIL\n";
			}
			$failed = 1;
			next if $keep_going;
			exit(1);
		}
		elsif (getdata($ref_program_exit_status) ne getdata($my_program_exit_status))
		{
			print fail_prefix() unless $keep_going;
			if (getdata($my_program_exit_status) eq "124") {
				print "$display_test: ERROR: Program execution timed out\n";
			} elsif (getdata($my_program_exit_status) > 128) {
				print "$display_test: ERROR: Program Execution Error (Crash)\n";
			} else {
				print "$display_test: ERROR: Program execution does not match reference exit status\n";
			}
			if (!$keep_going) {
					print "\n";
					print rerun_hint();
					print "TEST FAIL\n";
			}
			$failed = 1;
			next if $keep_going;
			exit(1);
		}
		elsif (getdata($ref_program_stdout) ne getdata($my_program_stdout))
		{
			print fail_prefix() unless $keep_going;
			print "$display_test: ERROR: Program execution does not match reference output\n";
			if (!$keep_going) {
					print "\n";
					print rerun_hint();
					print "To compare generated program output:\n\n    \$ diff " . rooted_path($ref_program_stdout) . " " . rooted_path($my_program_stdout) . "\n\n";
					print "TEST FAIL\n";
			}
			$failed = 1;
			next if $keep_going;
			exit(1);
		}
		else
		{
			$npass++;
			print "PASS\n\n" if $verbose;
		}
	}
	
	print "$tests: PASS ($npass/$suite_total)\n" unless $keep_going;
	
	if ($keep_going) {
	    if (open(my $fh, '>>', "$repo_root/.test_counts")) {
	        print $fh "$npass $suite_total\n";
	        close($fh);
	    }
	}
	
	if ($failed) {
		if ($keep_going) {
			system("touch .test_failed");
			exit(0);
		}
		exit(1);
	}
	exit(0);
