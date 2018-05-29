#!/usr/bin/env perl

use strict;
use warnings;
use lib '.';
use Data::Dumper;
use Career;
use Chart::Gnuplot;

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

our $major_categories = {semester => -1, unknown => 0,
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
			 future => 13,
 };

our $cip_categories = {semester => -1, unknown => 0,
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
			 future => 13,
 };

our $campus_categories = {semester => -1, unknown => 0,
 undecided => 1,
 'major:1' => 2,
 'major:2' => 3,
 'major:3' => 4,
 'major:4' => 5,
 'major:5' => 6,
 'major:6' => 7,
 'major:7' => 8,
 grad1 => 9,
 grad2 => 10,
 grad3 => 11,
 grad4 => 12,
 grad5 => 13,
 other_grad1 => 14,
 other_grad2 => 15,
 other_grad3 => 16,
 other_grad4 => 17,
 othercampus => 18,
 offcampus => 19,
			 future => 20,
 };
my @camp_cats = sort { $campus_categories->{$a} <=> $campus_categories->{$b} } keys %$campus_categories;

my $file = undef;

open $file, '>', "$DIR/categories.html" || die "could not open categories.html for writing";
print_header ($file);

# iterate through the campuses
# each one will write out part of the data_hash data structure
foreach my $campus (keys %$CAMPUS_CACHE) {
    print $file ' "' . "$campus-all" . '" : { "title" : "' . $campus . '",' . "\n";
    print $file "\t 'data' : [\n";
    my @headers = @camp_cats;
    map { $_ = "'$_'"; } @headers;
    print $file "[ ";
    print $file join ', ', @headers;
    print $file "],\n";

    my $data_table = [];
    foreach my $i (1 .. 13) {
	push @$data_table, [ $i, ('0') x $#camp_cats ];
    }
    # now get the data

    my @rows = $schema->resultset('PopCategory')->search ({ 'campus'=>$CAMPUS_CACHE->{$campus}, 'sed' => 0 });
    foreach my $row (@rows) {
	my $category = $row->get_column ('dst_cat');
	my $count = $row->get_column ('count');
	my $semester = $row->get_column ('dst_sem');
	my $r = $semester - 1; # semesters go from 1 - 13, data goes from 0 - 12
	my $c = $campus_categories->{$category} + 1; # categories are offset by 1 to account for the header
	$data_table->[$r]->[$c] = $count;
    }

    # now print the data
    my $ostr = '';
    foreach my $ar (@$data_table) {
	my $istr = join ', ', @$ar;
	$ostr .= "[ $istr ],\n";
    }
    print $file substr ($ostr, 0, -2);
    print $file "\n";
    
    print $file "\t] },\n";
}



# iterate through the seds


    
#    print $file "[ '$src_sem:$src_loc', '$dest_sem:$dest_loc', $count ]\n";
#       [ 'Brazil', 'Portugal', 5 ],

print_footer ($file);
close $file;


    sub print_header {
	my $file = shift;

print $file <<HEADER;
<html>
  <head>
    <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
    <script type="text/javascript">
      google.charts.load('current', {'packages':['corechart']});
      google.charts.setOnLoadCallback(drawChart);

function drawChart (which) {
         if (typeof which == 'undefined') {
	     which = "Plattsburgh-all";
	 }

	var data_hash = {
HEADER

} # print_header


sub print_footer {
    my $file = shift;
    
    print $file <<FOOTER;
    }; // data_hash data structure



    var data = google.visualization.arrayToDataTable (data_hash[which]['data']);

// Set chart options
    var options = {
          title: data_hash[which].title,
          hAxis: {title: 'Semester',  titleTextStyle: {color: '#333'}, ticks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 ] },
          vAxis: {minValue: 0},
          isStacked: 'percent'
        };

        var chart = new google.visualization.AreaChart(document.getElementById('chart_div'));
        chart.draw(data, options);
      } // draw

    function changeVis () {
    var school = document.getElementById('selector').value;
    drawChart (school);
} // changeVis
    </script>
  </head>
  <body>
    <div id="chart_div" style="width: 100%; height: 500px;"></div>
    <form>
    <select id='selector' onchange="changeVis()">
    <option value="Plattsburgh-all">Plattsburgh</option>
    <option value="Cortland-all">Cortland</option>
    <option value="Geneseo-all">Geneseo</option>
    <option value="New Paltz-all">New Paltz</option>
    <option value="Oneonta-all">Oneonta</option>
    <option value="Oswego-all">Oswego</option>
    </select>
  </body>
</html>
FOOTER
    
} # print_footer





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



