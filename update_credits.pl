#!/usr/bin/env perl

use strict;
use warnings;
use lib '.';
use Text::CSV;

our $SEMS = { 'Winter' => 0, 'Spring' => 1, 'Summer' => 2, 'Fall' => 3 };

use CSchema;

my $schema = CSchema->connect('dbi:SQLite:migration.sqlite')
  || die "could not open database";

# Warehouse Student Key,Campus Name,Sub Campus Name Short,Academic Program Name,SED Code,Term,Student Level,Admission Status,Total Student Credit Hours,Accumulated Credit Hours
<STDIN>;

my $csv = Text::CSV->new( { binary => 1 } )    # should set binary attribute.
  or die "Cannot use CSV: " . Text::CSV->error_diag();

while (<STDIN>) {

    $csv->parse($_);
    my (
        $student, $campus, $subcampus, $prog,    $sed,
        $term,    $level,  $admit,     $credits, $accum
    ) = $csv->fields();

    $sed = -1 unless ($sed =~ m/\d+/);
    $accum = 0 unless (defined $accum);
    $accum = 0 unless ($accum =~ m/\d+/);
    $accum = 0 if ($accum eq "");


    #print "award $award ct $ct 5 $en5\n";

    my ( $season, $year ) = split ' ', $term;
    my $semester = $year . $SEMS->{$season};

    print "--$student--$sed--$semester--$credits--$accum--\n";

    my $cip_obj =
      $schema->resultset('AcademicHistory')
      ->find_or_create(
        { 'semester' => $semester, 'student' => $student, 'sed' => $sed } );
    $cip_obj->set_column( 'credits', $credits );
    $cip_obj->set_column( 'totalcredits', $accum );
    $cip_obj->set_column( 'level', $level );
    $cip_obj->set_column( 'admission', $admit );
    $cip_obj->update;
}

