#!/usr/bin/env perl

use strict;
use warnings;
use lib '.';
use Data::Dumper;
use Career;

use CSchema;

our $CAMPUS_CACHE = {};
our $CIPS         = {};
our $TODAY        = 20181;

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

# y locations
#   out unknown
#   out sisters
#   out campus
#   out cip
#   break
#   degree
#   continuing in sed, cip, campus (in 99, in major# )
#   in unknown
#   in sisters
#   in ftft

# x (sed/campus-cip/campus) semester 0 - 13 -> location
my $sankey = {};

# initialize campuses
#foreach my $campus ( keys %$CAMPUS_CACHE ) {
#    my @data = ();
#    foreach my $i ( 0 .. 13 ) {
#        push @data,
#          {
#            'out unknown' => 0,
#            'out sisters' => 0,
#            'out campus'  => 0,
#            'break'       => 0,
#            'degree'      => 0,
#            'continuing'  => 0,
#            'in unknown'  => 0,
#            'in sisters'  => 0,
#            'in ftft'     => 0
#          };
#        $sankey->{$campus} = \@data;
#    }
#}

# initialize campuses cip
#foreach my $campus ( keys %$CAMPUS_CACHE ) {
#    foreach my $cip ( keys %$CIPS ) {
#        my @data = ();
#        foreach my $i ( 0 .. 13 ) {
#            push @data,
#              {
#                'out unknown' => 0,
#                'out sisters' => 0,
#                'out campus'  => 0,
#                'break'       => 0,
#                'degree'      => 0,
#                'continuing'  => 0,
#                'in unknown'  => 0,
#                'in sisters'  => 0,
#                'in ftft'     => 0
#              };
#            $sankey->{"$campus $cip"} = \@data;
#        }
#    }
#}

# initialize sed
#foreach my $sed ( keys %$programs ) {
#    my @data = ();
#    foreach my $i ( 0 .. 13 ) {
#        push @data,
#          {
##            'out unknown' => 0,
#            'out sisters' => 0,
#            'out campus'  => 0,
#            'break'       => 0,
#            'degree'      => 0,
#            'continuing'  => 0,
#            'in unknown'  => 0,
#            'in sisters'  => 0,
#            'in ftft'     => 0
#          };
#        $sankey->{$sed} = \@data;
#    }
#}

###############################################################################
# organize student data by student

my $transcripts = {};

my @students =

  $schema->resultset('Testlist')->all();
  #$schema->resultset('AcademicHistory')
  #->search( { 'level' => { '<' => 5 }, 'student' => { '<' => 500000000 } } );

foreach my $s (@students) {
    my $student = $s->get_column('student');
    next if ( defined $transcripts->{$student} );
    my $c = new Career();
    $c->init( $schema, $student );
    $transcripts->{$student} = $c;

}    # foreach undergrad

###############################################################################
# iterate through students

# graphs for sed and cip centered views
foreach my $sid ( keys %$transcripts ) {

    my $cips_done = {};

    #    print "$sid\n";
    my $career = $transcripts->{$sid};
    if ( $career->valid() ) {
    }
    else {
	next;
    }

    my $today_loc = $career->calc_relative($TODAY);

    my $sems        = $career->get_seds();
    my $sed_keys    = {};
    my $campus_keys = {};
    my $cip_keys    = {};
    foreach my $sed (@$sems) {
        next if ( $sed == 0 );
        $sed_keys->{$sed}                               = 1;
        $cip_keys->{ $PROGRAMS->{$sed}->{'cip2'} }      = 1;
        $campus_keys->{ $PROGRAMS->{$sed}->{'campus'} } = 1;
    }

    my $floc    = $career->first_loc();
    my $lloc    = $career->last_loc();
    my $degrees = $career->complete();

    # create sed sankey data
    # the idea here is we need to create the edge data
    # the nodes will be semester:location
    foreach my $sed ( keys %$sed_keys ) {

        my $cur_campus = $PROGRAMS->{$sed}->{'campus'};
        $sankey->{"$cur_campus-$sed"} = {}
          unless ( defined $sankey->{"$cur_campus-$sed"} );
        my $cur_cip = $PROGRAMS->{$sed}->{'cip2'};
        $cur_cip = 0 unless defined $cur_cip;

        $sankey->{"$cur_campus-$cur_cip"} = {}
          unless ( defined $sankey->{"$cur_campus-$cur_cip"} );

        my $completed_degree = defined( $career->degrees()->{$sed} );
        my $completed_cip = cip_in_degree( $career->degrees(), $cur_cip );

        my $sed_curstate  = 'unknown';
        my $sed_nextstate = '';
        my $cip_curstate  = 'unknown';
        my $cip_nextstate = '';
        foreach my $i ( 0 .. 12 ) {
            my $j = $i + 1;

            # before we have data
            if ( $i < $floc ) {    # uninitialized value
                $sed_nextstate = "unknown";
                $cip_nextstate = "unknown";
            }

            elsif ( $i >= $today_loc ) {
                if ( $degrees > 0 ) {
                    $sed_nextstate = $sed_curstate;
                    $cip_nextstate = $cip_curstate;
                }
                else {
                    $sed_nextstate = "future";
                    $cip_nextstate = "future";
                }
            }

            # check to see if they graduated in the past
            elsif ( ( $degrees > 0 ) && ( $i > $lloc ) ) {
                if ($completed_degree) {
                    $sed_nextstate = "grad$degrees";
                }
                else {
                    $sed_nextstate = "other_grad$degrees";
                }
                if ($completed_cip) {
                    $cip_nextstate = "grad$degrees";
                }
                else {
                    $cip_nextstate = "other_grad$degrees";
                }
            }

            # check to see if the graduated this semester
            elsif ( ( $degrees > 0 ) && ( $i > $lloc ) ) {
                if ($completed_degree) {
                    $sed_nextstate = "grad$degrees";
                }
                else {
                    $sed_nextstate = "other_grad$degrees";
                }
                if ($completed_cip) {
                    $cip_nextstate = "grad$degrees";
                }
                else {
                    $cip_nextstate = "other_grad$degrees";
                }
            }
            else {
                # we have some codes here
                my $sem_sed    = $sems->[$i];
                my $sem_campus = $PROGRAMS->{$sem_sed}->{'campus'};
                my $sem_cip    = $PROGRAMS->{$sem_sed}->{'cip2'};
                if ( $sem_sed == $sed ) {
                    $sed_nextstate = "continuing";
                }
                elsif ( $sem_sed == 0 ) {
                    $sed_nextstate = "offcampus";
                }
                elsif ( $sem_sed < 0 ) {
                    $sed_nextstate = "undecided";
                }
                elsif ( $cur_campus eq $sem_campus ) {
                    $sed_nextstate = "othermajor";
                }
                else {
                    $sed_nextstate = "othercampus";
                }

                if ( $sem_sed == 0 ) {
                    $cip_nextstate = "offcampus";
                }
                elsif ( $sem_cip == $cur_cip ) {
                    $cip_nextstate = "continuing";
                }
                elsif ( $sem_sed < 0 ) {
                    $cip_nextstate = "undecided";
                }
                elsif ( $cur_campus eq $sem_campus ) {
                    $cip_nextstate = "othercip";
                }
                else {
                    $cip_nextstate = "othercampus";
                }
            }

            my $is = $i;
            $is = '0' . $i if ( $i < 10 );
            my $js = $j;
            $js = '0' . $j if ( $j < 10 );

            inc_edge( $sankey->{"$cur_campus-$sed"},
                "$is:$sed_curstate", "$js:$sed_nextstate" );
            $sed_curstate = $sed_nextstate;

            inc_edge( $sankey->{"$cur_campus-$cur_cip"},
                "$is:$cip_curstate", "$js:$cip_nextstate" )
              unless ( defined $cips_done->{$cur_cip} );
            $cip_curstate = $cip_nextstate;

        }    # foreach semester

        # make sure we do not count a cip more than once
        $cips_done->{$cur_cip} = 1;

    }    # foreach major they were in
}    # foreach student

# create cip sankey data

# create campus sankey data
foreach my $sid ( keys %$transcripts ) {

    #    print "$sid\n";
    my $career = $transcripts->{$sid};
    if ( $career->valid() ) {
    }
    else {
	next;
    }

    my $today_loc = $career->calc_relative($TODAY);

    my $sems        = $career->get_seds();
    my $campus_keys = {};
    foreach my $sed (@$sems) {
        next if ( $sed == 0 );
        $campus_keys->{ $PROGRAMS->{$sed}->{'campus'} } = 1;
    }

    my $floc    = $career->first_loc();
    my $lloc    = $career->last_loc();
    my $degrees = $career->complete();

    # create sed sankey data
    # the idea here is we need to create the edge data
    # the nodes will be semester:location
    foreach my $cur_campus ( keys %$campus_keys ) {

        $sankey->{"$cur_campus-all"} = {}
          unless ( defined $sankey->{"$cur_campus-all"} );

        my $completed_degree = '';

        # check to see if they completed at this campus
        my $degree_hash = $career->degrees();
	my $today_loc = $career->calc_relative($TODAY);
        foreach my $sed ( keys %$degree_hash ) {
            $completed_degree = 1
              if ( (defined $PROGRAMS->{$sed}->{'campus'}) && ($PROGRAMS->{$sed}->{'campus'} eq $cur_campus ))
              ;    # uninitialized value
        }

        my $curstate  = 'unknown';
        my $nextstate = '';

        foreach my $i ( 0 .. 12 ) {
            my $j = $i + 1;

            # before we have data
            if ( $i < $floc ) {
                $nextstate = "unknown";
            }

            elsif ( $i >= $today_loc ) {
                if ( $degrees > 0 ) {
                    $nextstate = $curstate;
                }
                else {
                    $nextstate = "future";
                }
            }

            # check to see if they graduated in the past
            elsif ( ( $degrees > 0 ) && ( $i > $lloc ) ) {
                if ($completed_degree) {
                    $nextstate = "grad$degrees";
                }
                else {
                    $nextstate = "other_grad$degrees";
                }
            }

            # check to see if the graduated this semester
            elsif ( ( $degrees > 0 ) && ( $i > $lloc ) ) {
                if ($completed_degree) {
                    $nextstate = "grad$degrees";
                }
                else {
                    $nextstate = "other_grad$degrees";
                }
            }
            else {
                # we have some codes here
                my $sem_sed    = $sems->[$i];
                my $sem_campus = $PROGRAMS->{$sem_sed}->{'campus'};
                my $sem_cip    = $PROGRAMS->{$sem_sed}->{'cip2'};

                if ( $sem_sed == 0 ) {
                    $nextstate = "offcampus";
                }
                elsif ( $sem_campus ne $cur_campus ) {
                    $nextstate = "othercampus";
                }
                elsif ( $sem_sed < 0 ) {
                    $nextstate = "undecided";
                }
                else {
                    $nextstate = "major:" . $career->get_major_rank($sem_sed);
                }

            }

            my $is = $i;
            $is = '0' . $i if ( $i < 10 );
            my $js = $j;
            $js = '0' . $j if ( $j < 10 );

            inc_edge( $sankey->{"$cur_campus-all"},
                "$is:$curstate", "$js:$nextstate" );
            $curstate = $nextstate;

        }    # foreach semester
    }    # foreach major they were in

}    # foreach student

foreach my $gkey ( sort keys %$sankey ) {
    my $graph = $sankey->{$gkey};
    my $gstr  = $gkey;
    $gstr =~ s/-/,/;
    foreach my $fkey ( sort keys %$graph ) {
        my $from    = $graph->{$fkey};
        my $fromstr = $fkey;
        $fromstr =~ s/:/,/;
        foreach my $dkey ( sort keys %$from ) {
            my $deststr = $dkey;
            $deststr =~ s/:/,/;
            print $gstr . ","
              . $fromstr . ","
              . $deststr . ","
              . $from->{$dkey} . "\n";
        }
    }
}

###############################################################################

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

sub inc_edge {
    my $graph = shift;
    my $from  = shift;
    my $to    = shift;

    my $count = $graph->{$from}->{$to};
    $count = 0 unless ( defined $count );
    $graph->{$from}->{$to} = $count + 1;

}    # inc_edge

sub cip_in_degree {
    my $degrees = shift;
    my $cip     = shift;

    foreach my $sed ( sort keys %$degrees ) {
        return 1
          if ( (defined $PROGRAMS->{$sed}->{'cip2'}) && ($PROGRAMS->{$sed}->{'cip2'} == $cip ));    # uninitialized value
    }
    return '';
}    # cip_in_degree

__END__
