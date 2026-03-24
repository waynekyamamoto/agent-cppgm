#!/usr/bin/perl

use strict;
use warnings;

if (scalar(@ARGV) != 3)
{
	die "Usage: test.pl <app> <suffix> <testlocation>";
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
	print "Running $test...\n" if $verbose;

	my $test_out = $test;
	$test_out =~ s/\.t\.1$/\.$suffix/;
	my $test_base = $test;
	$test_base =~ s/\.t\.1$/\.t/;

	chomp(my @inputs = `ls $test_base.*`);
	my $inputs_str = join(' ', @inputs);

	print $bf "$test_out.exit_status str $test_out.stdout $test_out.stdout - ./$app -o $test_out $inputs_str\n";
}

close($bf);

system("./$app --batch-file $batch_file");
unlink $batch_file;
