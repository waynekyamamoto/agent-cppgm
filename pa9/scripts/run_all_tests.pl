#!/usr/bin/perl

use strict;
use warnings;

if (scalar(@ARGV) != 3)
{
	die "Usage: run_all_tests.pl <app> <suffix>";
}

my $app = $ARGV[0];
my $suffix = $ARGV[1];
my $tests = $ARGV[2];
my $verbose = $ENV{VERBOSE} || $ENV{CPPGM_TEST_VERBOSE};
my $keep_going = $ENV{KEEP_GOING};

my @tests = grep { m/\.t\.1$/ } sort split(/\s+/, `find $tests -type f`);
my $ntests = scalar(@tests);

if (!$verbose && !$keep_going)
{
	print "$tests: running $ntests test";
	print "s" if $ntests != 1;
	print "\n";
}

my $batch_file = "$tests.batch.txt";
open(my $bf, '>', $batch_file) or die "Could not open $batch_file";

for my $test (@tests)
{
	my $test_base = $test;
	$test_base =~ s/\.t\.1$//;

	chomp(my @inputs = `ls $test_base.t.*`);
	my $inputs_str = join(' ', @inputs);

	print $bf "$test_base.$suffix.impl.exit_status num $test_base.$suffix.impl.stdout $test_base.$suffix.impl.stderr - ./$app -o $test_base.$suffix.program $inputs_str\n";
}

close($bf);

system("./$app --batch-file $batch_file");
unlink $batch_file;

for my $test (@tests)
{
	print "Running $test...\n" if $verbose;

	my $test_base = $test;
	$test_base =~ s/\.t\.1$//;

	my $impl_exit_status = 1;
	if (open(my $fh, '<', "$test_base.$suffix.impl.exit_status")) {
		$impl_exit_status = <$fh>;
		chomp($impl_exit_status);
		close($fh);
	}

	if ($impl_exit_status eq "0") {
		system("timeout 600 ./$test_base.$suffix.program < $test_base.stdin 1> $test_base.$suffix.program.stdout 2> $test_base.$suffix.program.stderr; echo \$? > $test_base.$suffix.program.exit_status");
	}
}
