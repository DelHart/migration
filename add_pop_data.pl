#!/usr/bin/env perl

use strict;
use warnings;
use lib '.';
use Data::Dumper;
use Career;
use Text::CSV;

use CSchema;

my $schema = CSchema->connect('dbi:SQLite:migration.sqlite')
  || die "could not open database";

my $csv = Text::CSV->new( { binary => 1 } )    # should set binary attribute.
  or die "Cannot use CSV: " . Text::CSV->error_diag();
	my $comma = '';

while (<STDIN>) {


    $csv->parse($_);
    my (
        $campus, $sed, $src_sem, $src_loc, $dest_sem, $dest_loc, $count
    ) = $csv->fields();

    my $row = $schema->resultset('Population')->find_or_create ({ 'campus' => $campus, 'sed'=>$sed, 'src_sem' => $src_sem, 'src_cat' => $src_loc, 'dst_cat' => $dest_loc});
    $row->set_column ('dst_sem', $dest_sem);
    $row->set_column ('count', $count);
    $row->update;


}
