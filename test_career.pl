#!/usr/bin/env perl

use strict;
use warnings;
use lib '.';
use Data::Dumper;
use Test::More;

use CSchema;
# select * from academic_history where student = 78 or student=362 or student=200 or student=91553 or student = 15512 or student=90493 or student = 16287 or student=26183 or student=38487 or student=416 or student = 871 order by student,semester

use_ok ('Career');

my $career = new Career ();

my $schema = CSchema->connect('dbi:SQLite:migration.sqlite')
  || die "could not open database";

$career->init ($schema, 78);
my $seds = $career->get_seds ();
is_deeply ($seds, [ 0, 0, 0, 0, 3931, 3931, 3931, 3931, 0,0,0,0,0], 'student 78');
is ($career->complete(), 1, 'num degrees');
is ($career->valid(), '', 'is valid');
is ($career->first_loc(), 4, "first loc");
is ($career->last_loc(), 7, "last loc");

# some graduate 
$career = new Career ();
$career->init ($schema, 362);
$seds = $career->get_seds ();
is_deeply ($seds, [ 0, 3873, 3873, 19291, 19291, 19291,19291,0,0,0,0,0,0], 'student 362');
is ($career->complete(), 2, 'num degrees');
is ($career->valid(), '', 'is valid');
is ($career->first_loc(), 1, "first loc");
is ($career->last_loc(), 6, "last loc");

# taking extra class at end
$career = new Career ();
$career->init ($schema, 200);
$seds = $career->get_seds ();
is_deeply ($seds, [ 0, 0, 0, 0, 20322, 20322, 20322, 20322, 20322,0,0,0,0], 'student 200');
is ($career->complete(), 1, 'num degrees');
is ($career->valid(), '', 'is valid');
is ($career->first_loc(), 4, "first loc");
is ($career->last_loc(), 8, "last loc");

# change of major
$career = new Career ();
$career->init ($schema, 91553);
$seds = $career->get_seds ();
is_deeply ($seds, [ 29561, 29561, 29561, 0, 85146,85146,85146,85146,85145,85146,85146,0,0], 'student 91553');
is ($career->complete(), 1, 'num degrees');
is ($career->valid(), 1, 'is valid');
is ($career->first_loc(), 0, "first loc");
is ($career->last_loc(), 10, "last loc");

# change of major
# delayed credits transferred in
$career = new Career ();
$career->init ($schema, 15512);
$seds = $career->get_seds ();
is_deeply ($seds, [ 0, 0, 3675, 3675, 3675, 12275, 12275,12275, 0, 0, 0, 0, 0], 'student 15512');
is ($career->complete(), 1, 'num degrees');
is ($career->valid(), 1, 'is valid');
is ($career->first_loc(), 2, "first loc");
is ($career->last_loc(), 7, "last loc");

# cross registered
$career = new Career ();
$career->init ($schema, 90493);
$seds = $career->get_seds ();
is_deeply ($seds, [ 0, 0, 0, 29963, 29963, 29963, 29963, 29963,29963,0,0,0,0], 'student 90493');
is ($career->complete(), 1, 'num degrees');
is ($career->valid(), 1, 'is valid');
is ($career->first_loc(), 3, "first loc");
is ($career->last_loc(), 8, "last loc");

# change of major
# delayed transfer
$career = new Career ();
$career->init ($schema, 16287);
$seds = $career->get_seds ();
is_deeply ($seds, [ 0, 0, -5, -5, 3679, 3679, 3677,0, 3677, 0, 0,0,0], 'student 16287');
is ($career->complete(), 1, 'num degrees');
is ($career->valid(), 1, 'is valid');
is ($career->first_loc(), 2, "first loc");
is ($career->last_loc(), 8, "last loc");

# cross registered
$career = new Career ();
$career->init ($schema, 26183);
$seds = $career->get_seds ();
is_deeply ($seds, [ 0, 0, 3679, 3679, 3679, 3679, 3679,3679,0, 0,0,0,0], 'student 26183');
is ($career->complete(), 1, 'num degrees');
is ($career->valid(), '', 'is valid');
is ($career->first_loc(), 2, "first loc");
is ($career->last_loc(), 7, "last loc");

# change of major
# delayed transfer
$career = new Career ();
$career->init ($schema, 38487);
$seds = $career->get_seds ();
is_deeply ($seds, [ 0, 0, 3640, 3640, 12229, 3640, 3640,3640, 0, 0, 0, 0, 0], 'student 38487');
is ($career->complete(), 1, 'num degrees');
is ($career->valid(), 1, 'is valid');
is ($career->first_loc(), 2, "first loc");
is ($career->last_loc(), 7, "last loc");

#  graduate only
$career = new Career ();
$career->init ($schema, 416);
$seds = $career->get_seds ();
is_deeply ($seds, [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,0,0], 'student 416');
is ($career->complete(), 0, 'num degrees');
is ($career->valid(), '', 'is valid');
is ($career->first_loc(), -1, "first loc");
is ($career->last_loc(), -1, "last loc");

#  undergrad starting 20023
$career = new Career ();
$career->init ($schema, 871);
$seds = $career->get_seds ();
is_deeply ($seds, [ 3890, 3890, 3890, 3890, 3890, 3890, 3890, 3890, 0, 0, 0,0,0], 'student 871');
is ($career->complete(), 1, 'num degrees');
is ($career->valid(), 1, 'is valid');
is ($career->first_loc(), 0, "first loc");
is ($career->last_loc(), 7, "last loc");



done_testing();
