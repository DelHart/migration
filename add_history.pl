#!/usr/bin/env perl

use strict;
use warnings;
use lib '.';

use Text::CSV;

our $SEMS = { 'Winter' => 0, 'Spring' => 1, 'Summer' => 2, 'Fall' => 3 };
our $LEVELS = {};
our $ADMITS = {};
our $CAMPUS_CACHE = {};

use CSchema;

my $schema = CSchema->connect('dbi:SQLite:migration.sqlite')
  || die "could not open database";


# fetch all of the campus keys
my @campus = $schema->resultset('Campus')->all();
foreach my $c (@campus) {
    my $name = $c->get_column('name');
    my $id = $c->get_column('campus');
    $CAMPUS_CACHE->{$name} = $id;
}


# get the level and admit codes
my @levels = $schema->resultset('Level')->all();
foreach my $l (@levels) {
    my $name = $l->get_column('name');
    my $id = $l->get_column('level');
    $LEVELS->{$name} = $id;
}

my @admits = $schema->resultset('Admission')->all();
foreach my $a (@admits) {
    my $name = $a->get_column('name');
    my $id = $a->get_column('admission');
    $ADMITS->{$name} = $id;
}

#Warehouse Student Key;Campus Name;Sub Campus Name Short;Academic Program Name;SED Code;Term;Student Level;Admission Status;Total Student Credit Hours;Accumulated Credit Hours

<STDIN>;

my $csv = Text::CSV->new( { binary => 1 } )    # should set binary attribute.
  or die "Cannot use CSV: " . Text::CSV->error_diag();

my $old_student = '';
my $old_sed = '';
my $old_prog = '';
my $old_semester = '';

while (<STDIN>) {


    $csv->parse($_);
    my (
        $student, $campus, $j2, $program, $sed, $semester, $level, $admin, $credit, $tcredit
    ) = $csv->fields();

    $student = $old_student if ($student eq '');
    $sed = $old_sed if ($sed eq '');
    $program = $old_prog if ($program eq '');
    $semester = $old_semester if ($semester eq '');

    $old_student = $student;
    $old_sed = $sed;
    $old_prog = $program;
    $old_semester = $semester;

    $tcredit = 0 if ($tcredit eq '');

    if ($sed eq 'N/A') {
	my $campus_id = $CAMPUS_CACHE->{$campus};
	if ($program eq 'In Program But Major Not Chosen') {
	    $sed = -1 * $campus_id;
	} 
	elsif ($program eq 'Not In a Program') {
	    $sed = -10 * $campus_id;
	}
    }

	    
    die "student $student, $campus, $j2, program $program, sed $sed, semester $semester, level $level, admin $admin, credit $credit, total $tcredit\n" unless ($sed =~ m/\d+/);

#    print "student $student, $j1, $j2, program $program, sed $sed, semester $semester, level $level, admin $admin, credit $credit, total $tcredit\n";
    
    my ($season, $year) = split ' ', $semester;
    my $s = $year . $SEMS->{$season};

    $credit =~ m/(\d+?)(\.\d)?$/m;
    my $c = $1;

    my $lnum = $LEVELS->{$level};
    my $anum = $ADMITS->{$admin};


    my $cip_obj =
	$schema->resultset('AcademicHistory')->find_or_create( { 'semester' => $s, 'student' => $student, 'sed' => $sed} );
    $cip_obj->set_column ('level', $lnum);
    $cip_obj->set_column ('admission', $anum);
    $cip_obj->set_column ('credits', $c);
    $cip_obj->set_column ('totalcredits', $tcredit);
        $cip_obj->update;
    }


