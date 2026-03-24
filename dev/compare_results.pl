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

my @tests = grep { m/\.t$/ } sort split(/\s+/, `find $tests -type f`);
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
	my ($file) = @_;

	open my $fh, '<', $file or die "Cannot read $file: $!";
	local $/;
	my $data = <$fh>;
	close $fh;
	$data //= '';
	$data =~ s/\s+$//;
	return $data;
}

	for my $test (@tests)
	{
		print "\n$test: " if $verbose;
	
		my $display_test = $keep_going ? "$assignment/$test" : $test;
		my $testbase = $test;
		$testbase =~ s/\.t$//;
	
		my $reftest = "$testbase.$ref_suffix";
		my $reftest_exit_status = "$reftest.exit_status";
		my $mytest = "$testbase.$my_suffix";
		my $mytest_exit_status = "$mytest.exit_status";
	
		my $reftest_exit_status_data = getdata($reftest_exit_status);
		my $mytest_exit_status_data = getdata($mytest_exit_status);
	
		if ($reftest_exit_status_data ne $mytest_exit_status_data)
		{
			print fail_prefix() unless $keep_going;
			if ($mytest_exit_status_data eq "EXIT_TIMEOUT") {
				print "$display_test: ERROR: Test timed out\n";
			} elsif ($mytest_exit_status_data eq "EXIT_CRASH") {
				print "$display_test: ERROR: Internal Compiler Error (Crash)\n";
			} else {
				print "$display_test: ERROR: Expected $reftest_exit_status_data, got $mytest_exit_status_data\n";
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
		elsif ($reftest_exit_status_data =~ /EXIT_FAILURE/)
		{
			$npass++;
			print "PASS\n\n" if $verbose;
		}
		else
		{
			my $reftest_data = getdata($reftest);
			my $mytest_data = getdata($mytest);
	
			if ($reftest_data eq $mytest_data)
			{
				$npass++;
				print "PASS\n\n" if $verbose;
				next;
			}
	
			print fail_prefix() unless $keep_going;
			print "$display_test: ERROR: Output does not match reference implementation\n";
			if (!$keep_going) {
				print "\n";
				print "To rerun this assignment with per-test output from the repo root:\n\n    \$ cd $repo_root && VERBOSE=1 make $assignment\n\n";
				print "To see input file:\n\n    \$ cat " . rooted_path($test) . "\n\n";
				print "To see hex dump of input:\n\n    \$ xxd " . rooted_path($test) . "\n\n";
				print "To see the differences of output:\n\n    \$ diff " . rooted_path($reftest) . " " . rooted_path($mytest) . "\n\n";
				print "TEST FAIL\n";
			}
			$failed = 1;
			next if $keep_going;
			exit(1);
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
