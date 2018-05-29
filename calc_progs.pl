#!/usr/bin/env perl

use strict;
use warnings;
use lib '.';

use CSchema;

my $schema = CSchema->connect('dbi:SQLite:migration.sqlite')
  || die "could not open database";

# go through the students and calc the data

my @students = $schema->resultset('AcademicHistory')->search ({}, {'distinct' => 1, 'select' => ['student'] });

foreach my $s (@students) {
   my $id = $s->get_column('student');

   print "$id\n";

   my @hists = $schema->resultset('AcademicHistory')->search ({'student' => $id }, {'order_by' => {-asc => 'semester'}});

   my $old_sed = -3;
   my $old_sem = -3;
   my $count = 0;

   foreach my $h (@hists) {
       my $semester = $h->get_column('semester');
       my $sed = $h->get_column('sed');

       if ($old_sed != -3) {
	   $old_sed = $sed;
	   $old_sem = $semester;
       }
       
       my $tcredit = $h->get_column('totalcredits');
       my $credits = $h->get_column('credits');
       my $admin = $h->get_column('admission');
       my $level = $h->get_column('level');

       my $cp = $schema->resultset('CalcProgram')->find_or_create (
	   {'student' => $id,
	   'sed' => $sed,
	   'semester' => $semester,
	   'source' => $admin,
	   'level' => $level,
	   'transfer_to' },
	   {});
	   
       

       print "\t$semester\n";

   }
   

}



__END__


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


