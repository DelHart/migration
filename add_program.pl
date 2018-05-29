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


# fetch all of the campus keys
my @campus = $schema->resultset('Campus')->all();
foreach my $c (@campus) {
    my $name = $c->get_column('name');
    my $id = $c->get_column('campus');
    $CAMPUS_CACHE->{$name} = $id;
}


#<U+FEFF>Academic Program Name,SED Code,Award Name,Award Level Description,Award Level Sort Code,CIP6 Code,Term,Campus Name,Sub-Campus Name (Medium),Home Institution Student Count,Distinct Home Institution Student Count,Total Student Credit Hours

<STDIN>;

my $csv = Text::CSV->new( { binary => 1 } )    # should set binary attribute.
  or die "Cannot use CSV: " . Text::CSV->error_diag();

while (<STDIN>) {


    $csv->parse($_);
    my (
        $name, $sed, $kind, $level, $j1, $cip6, $semester, $campus, $j3, $students, $students2, $credits
	) = $csv->fields();
    
    if ($students != $students2) {print $_;}
    
    my ($season, $year) = split ' ', $semester;
    my $s = $year . $SEMS->{$season};

    if ($sed =~ /\d+/) {
    }
    else {
	$sed = -1;
    }

    my $cip2 = substr ($cip6, 0, 2);
    
    my $cip_obj =
	$schema->resultset('Program')->find_or_create( { 'sed' => $sed });
    $cip_obj->set_column ('name', $name);
    $cip_obj->set_column ('level', $level);
    $cip_obj->set_column ('kind', $kind);
    $cip_obj->set_column ('campus', $CAMPUS_CACHE->{$campus});
    $cip_obj->set_column ('cip2', $cip2);
    $cip_obj->set_column ('cip6', $cip6);
    $cip_obj->update;

    my $enr_obj =
	$schema->resultset('Enrollment')->find_or_create( { 'sed' => $sed, 'semester' => $s, 'students' => $students, 'credits' => $credits } );
    $enr_obj->update;
    
    }



