#!/usr/bin/env perl

use strict;
use warnings;
use lib '.';
use Data::Dumper;

use CSchema;

my $schema = CSchema->connect('dbi:SQLite:migration.sqlite')
  || die "could not open database";

# mapping student -> sed -> flag
my $degrees = {};
load_degrees ($schema, $degrees);

my $programs = {};
load_programs ($schema, $programs);

my $current = {}; # student to major

my $migrations = {}; # from -> to : all recent

my @students = $schema->resultset('AcademicHistory')->search ({}, {'order_by' => 'student,semester,sed'});

# student -> semester -> sed
my $transcripts = {};

my $prev_student = 0;
my $prev_sem = 0;

foreach my $s (@students) {
    my $semester = $s->get_column('semester');
    my $student = $s->get_column('student');
    my $sed = $s->get_column('sed');

    my $t = $transcripts->{$student}->{$semester};
    if (!defined $t) {
	$transcripts->{$student}->{$semester} = {};
	$t = $transcripts->{$student}->{$semester};
    }
    $t->{$sed} = 1;

} # load transcript

foreach my $student (keys %$transcripts) {

    # iterate through the semesters
    my @semesters = sort { $a <=> $b } keys %{$transcripts->{$student}};
    my $sed = 0;

    foreach my $semester (@semesters) {

	my @seds = keys %{$transcripts->{$student}->{$semester}};
	my $c = $seds[0];
	$sed = $c if ($sed == 0);  # if this is the first semester
	my $continuing = $transcripts->{$student}->{$semester}->{$sed};
	if (! defined $continuing){
	    my $from = $migrations->{$sed};
	    if (!defined $from) {
		$migrations->{$sed} = {};
		$from = $migrations->{$sed};
	    }
	    my $count = $from->{$c}->{'count'};
	    if (!defined $count) {
		$from->{$c} = {'list' => [], 'count' => 0, 'recent' => 0};
		$count = 0;
	    }
	    $count++;
	    $from->{$c}->{'count'} = $count;
	    $from->{$c}->{'recent'} = $from->{$c}->{'recent'} + 1 if ($semester > 20122);
	    push @{$from->{$c}->{'list'}}, $student;
	    
	    $sed = $c;
	}

    } # foreach semester

} # foreach student

my $sums = {};
my $rsums = {};

#print Dumper $programs;

my @progs = sort { $programs->{$a}->{'campus'} cmp $programs->{$b}->{'campus'} || $programs->{$a}->{'name'} cmp $programs->{$b}->{'name'} } keys %$programs;
foreach my $p (@progs) {
    $sums->{$p} = {'into' => 0, 'out' => 0};
    $rsums->{$p} = {'into' => 0, 'out' => 0};
}

    
foreach my $p (@progs) {
    foreach my $q (@progs) {
	my $count = $migrations->{$p}->{$q};
	if (defined $count) {
	    $count = $migrations->{$p}->{$q}->{'count'};
	    my $recent = $migrations->{$p}->{$q}->{'recent'};
	    print "$p,$programs->{$p}->{'name'},$programs->{$p}->{'kind'},$programs->{$p}->{'campus'},$q,$programs->{$q}->{'name'},$programs->{$q}->{'kind'},$programs->{$q}->{'campus'},$count,$recent\n";
#	    foreach my $s (@{$migrations->{$m}->{$n}->{'list'}}) {
#		print "\t$s\n";
#	    }
	    $rsums->{$p}->{'out'} += $recent;
	    $rsums->{$q}->{'into'} += $recent;
	    $sums->{$p}->{'out'} += $count;
	    $sums->{$q}->{'into'} += $count;
	}
    }
}
    
foreach my $p (@progs) {
    print "$p,$programs->{$p}->{'name'},$programs->{$p}->{'kind'},$programs->{$p}->{'campus'}," . $sums->{$p}->{'into'} . ',' . $sums->{$p}->{'out'} . 
     "," . $rsums->{$p}->{'into'} . ',' . $rsums->{$p}->{'out'} . "\n";
}


sub load_degrees {
    my $s = shift;
    my $d = shift;

    my @degrees = $s->resultset('Degree')->all();
    foreach my $d (@degrees) {
	my $student = $d->get_column('student');
	my $sed = $d->get_column('sed');
	$d->{$student}->{$sed} = 1;
    }
    

} # load_degrees

sub load_programs {
    my $s = shift;
    my $progs = shift;

    my @programs = $s->resultset('Program')->all();
    foreach my $p (@programs) {
	my %data = $p->get_columns();
	my $campus;
	#if ($data{'sed'} > 0) {
	    $campus = $p->campus()->get_column('name');
	#}
	#else {
	#    $campus = 'not in a program';
	#}
	my $name = $data{'name'};
	$name =~ s/,//g;
	$progs->{$data{'sed'}} = {
	    'name' => $data{'name'},
	    'cip2' => $data{'cip2'},
	    'kind' => $data{'kind'},
	    'campus' => $campus,
	};
    }
    
} # load_programs
