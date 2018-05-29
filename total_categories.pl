#!/usr/bin/env perl

use strict;
use warnings;
use lib '.';
use Data::Dumper;
use Career;
use Text::CSV;

use CSchema;

our $CAMPUS_CACHE = {};
our $CIPS         = {};
our $TODAY = 20181;

my $schema = CSchema->connect('dbi:SQLite:migration.sqlite')
  || die "could not open database";

# mapping student -> sed -> flag
# fetch all of the campus keys
my @campus = $schema->resultset('Campus')->all();
foreach my $c (@campus) {
    my $name = $c->get_column('name');
    my $id   = $c->get_column('campus');
    $CAMPUS_CACHE->{$name} = $id;
}

our $PROGRAMS = {};
load_programs( $schema, $PROGRAMS );

our $UNKNOWN = 1;
our $DIR = "./categories";

# the idea is to read in the csv file and then create graphs
my $csv = Text::CSV->new( { binary => 1 } )    # should set binary attribute.
  or die "Cannot use CSV: " . Text::CSV->error_diag();
	my $comma = '';

our $major_categories = {unknown => 0,
 undecided => 0,
 continuing => 1,
 grad1 => 2,
 grad2 => 3,
 grad3 => 4,
 grad4 => 5,
 othermajor => 6,
 other_grad1 => 7,
 other_grad2 => 8,
 other_grad3 => 9,
 other_grad4 => 10,
 othercampus => 11,
 offcampus => 12,
 };

our $cip_categories = {unknown => 0,
 continuing => 1,
 grad1 => 2,
 grad2 => 3,
 grad3 => 4,
 grad4 => 5,
 othercip => 6,
 other_grad1 => 7,
 other_grad2 => 8,
 other_grad3 => 9,
 other_grad4 => 10,
 othercampus => 11,
 offcampus => 12,
 };

our $campus_categories = {unknown => 0,
 undecided => 1,
 major1 => 2,
 major2 => 3,
 major3 => 4,
 major4 => 5,
 major5 => 6,
 major6 => 7,
 major7 => 8,
 grad1 => 9,
 grad2 => 10,
 grad3 => 11,
 grad4 => 12,
 other_grad1 => 13,
 other_grad2 => 14,
 other_grad3 => 15,
 other_grad4 => 16,
 othercampus => 17,
 offcampus => 18,
 };

my $file = undef;
my $charts = {};

while (<STDIN>) {


    $csv->parse($_);
    my (
        $campus, $sed, $src_sem, $src_loc, $dest_sem, $dest_loc, $count
    ) = $csv->fields();

    if (!defined $charts->{"$campus-$sed"} ) {
	if (defined $file) {
	    print_footer ($file);
	    close $file;
	}
	my $label = "label";
	if ($sed eq 'all') {
	    $label = 'all';
	}
	elsif ($sed < 0) {
	    $label = "undecided";
	}
	elsif (defined $PROGRAMS->{$sed}->{'name'}) {
	    $label = $PROGRAMS->{$sed}->{'name'} . " " . $PROGRAMS->{$sed}->{'kind'};
	    $label =~ s/\//-/g;
	}
	else {
	    $label = "CIP $sed";
	}
	open $file, '>', "$DIR/$campus-$label.html" || die "could not open $campus-sed for writing";
	$charts->{"$campus-$sed"} = $file;
	print_header ($file);
    }
    
    print $file "[ '$src_sem:$src_loc', '$dest_sem:$dest_loc', $count ]\n";
#       [ 'Brazil', 'Portugal', 5 ],

}
print_footer ($file);
close $file;


sub load_programs {
    my $s     = shift;
    my $progs = shift;

    my @programs =
      $s->resultset('Program')->search( {} );
    foreach my $p (@programs) {
        my %data = $p->get_columns();
        my $campus;
        $campus = $p->campus()->get_column('name');

        $progs->{ $data{'sed'} } = {
            'name'   => $data{'name'},
            'cip2'   => $data{'cip2'},
            'kind'   => $data{'kind'},
            'campus' => $campus,
        };

        $CIPS->{ $data{'cip2'} } = 1;
    }

}    # load_programs

__END__


    sub print_footer {
	my $file = shift;

	print $file <<FOOTER;
    ]);

    // Set chart options
    var options = {
      width: 2400,
    };

    // Instantiate and draw our chart, passing in some options.
    var chart = new google.visualization.Sankey(document.getElementById('sankey_multiple'));
    chart.draw(data, options);
   }
</script>
</body>
</html>
FOOTER

    } # print_footer





    sub print_header {
	my $file = shift;

print $file <<HEADER;
<html>
<body>
 <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>

<div id="sankey_multiple" style="width: 2400px; height: 700px;"></div>

<script type="text/javascript">
  google.charts.load("current", {packages:["sankey"]});
  google.charts.setOnLoadCallback(drawChart);
   function drawChart() {
    var data = new google.visualization.DataTable();
    data.addColumn('string', 'From');
    data.addColumn('string', 'To');
    data.addColumn('number', 'Weight');
    data.addRows([
HEADER

		 } # print_header



