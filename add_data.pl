#!/usr/bin/env perl

use strict;
use warnings;
use lib '.';

use Text::CSV;

our $SEMS = { 'Winter' => 0, 'Spring' => 1, 'Summer' => 2, 'Fall' => 3 };

use CSchema;

my $schema = CSchema->connect('dbi:SQLite:migration.sqlite')
  || die "could not open database";

# <U+FEFF>Name,CIP 2,CIP 4,Program Taxon (CIP 6),Academic Program Name,Award Name,Academic Program Name Alternate Sort Code,Current Term,Term,5 Yrs Ago,4 Yrs Ago,3 Yrs Ago,2 Yrs Ago,1 Yr Ago,Current,Five Year Enrollment  Change  ,Five Year % Change  

<STDIN>;

my $csv = Text::CSV->new( { binary => 1 } )    # should set binary attribute.
  or die "Cannot use CSV: " . Text::CSV->error_diag();

while (<STDIN>) {


    $csv->parse($_);
    my (
        $semester, $student, $program, $place
    ) = $csv->fields();

    #print "award $award ct $ct 5 $en5\n";

    my ($season, $year) = split ' ', $semester;
    my $s = $year . $SEMS->{$season};

    my $cip_obj =
	$schema->resultset('Major')->find_or_create( { 'semester' => $s, 'student' => $student, 'major' => $program } );
        $cip_obj->update;
    }


