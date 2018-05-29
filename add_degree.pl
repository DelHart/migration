#!/usr/bin/env perl

use strict;
use warnings;
use lib '.';

use Text::CSV;

our $SEMS = { 'Winter' => 0, 'Spring' => 1, 'Summer' => 2, 'Fall' => 3 };
our $CAMPUS_CACHE = {};

use CSchema;

my $schema = CSchema->connect('dbi:SQLite:migration.sqlite')
  || die "could not open database";


#Warehouse Student Key,Final Term at Degree Campus,Awarding Campus Name,SED Code,Primary Secondary Code,Primary Secondary Description,Primary Second ary ID


<STDIN>;

my $csv = Text::CSV->new( { binary => 1 } )    # should set binary attribute.
  or die "Cannot use CSV: " . Text::CSV->error_diag();

while (<STDIN>) {


    $csv->parse($_);
    my (
        $student, $term, $campus, $sed, $major_rank, $j1, $j2
	) = $csv->fields();
    
    my ($season, $year) = split ' ', $term;
    my $semester;

    # there are some unknown terms...
    if (defined ($SEMS->{$season})) {
	$semester = $year . $SEMS->{$season};
    }
    else {
	$semester = -1;
    }

    if ($sed =~ /\d+/) {
    }
    else {
	# this should not happen
	$sed = -1;
    }

    my $first = 'FALSE';
    $first = 'TRUE' if ($major_rank == 1);
	

    my $enr_obj =
	$schema->resultset('Degree')->find_or_create( { 'sed' => $sed, 'semester' => $semester, 'student' => $student } );
    $enr_obj->set_column ('first', $first);
    $enr_obj->update;
    
    }



