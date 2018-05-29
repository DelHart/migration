package Career;
use Data::Dumper;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $locs  = [];
    foreach my $i ( 0 .. 12 ) {
        my $data = {
            'semester' => 0,
            'sed'      => 0,
	    'total'    => 0,
        };
        push @$locs, $data;
    }
    return bless {
        'loc'            => $locs,
	'majors'         => {},
	'num_majors'         => 0,
        'first_semester' => 0,
        'last_sed'       => 0,
        'first_loc'      => -1,
        'last_loc'       => -1,
        'early'          => 0,
        'complete'       => 0,
	'degrees'         => {},
    }, $class;
}

sub init {
    my $self       = shift;
    my $schema     = shift;
    my $student_id = shift;

    my @records =
      $schema->resultset('AcademicHistory')
      ->search( { 'student' => $student_id, 'level' => { '<' => '5' } },
        { 'order_by' => 'semester ASC' } );

    # print Dumper $self->{'loc'};

    foreach my $r (@records) {
        my $semester   = $r->get_column('semester');
        my $credits    = $r->get_column('credits');
        my $totalcreds = $r->get_column('totalcredits');
        my $level      = $r->get_column('level');
        my $sed        = $r->get_column('sed');

        if ( $self->{'first_semester'} == 0 ) {
	    $self->{'first_loc'} = 0;
            $self->{'first_semester'} = $semester;
            if ( $totalcreds > 14 ) {
                my $t  = $totalcreds;
                my $fs = $semester;
                while ( $t > 14 ) {

                    # decrement semester
                    $self->{'first_loc'} = $self->{'first_loc'} + 1;
                    $fs                  = prev_semester($fs);
                    $t                   = $t - 15;
                }
                $self->{'first_semester'} = $fs;
            }
            else {
  # need to check to see if there was credits transferred in the second semester
		if (defined $records[1]) {
                my $second_semester_total =
                  $records[1]->get_column('totalcredits');
                my $late_transfers =
                  $second_semester_total - $totalcreds - $credits;
                my $fs = $semester;
                while ( $late_transfers > 14 ) {

                    # decrement semester
                    $self->{'first_loc'} = $self->{'first_loc'} + 1;
                    $fs                  = prev_semester($fs);
                    $late_transfers      = $late_transfers - 15;
                }
                $self->{'first_semester'} = $fs;

		}
            }    # if there are late transfer credits
        }    # if this is the first semester

        my $relative_semester = $self->calc_relative($semester);

        #	print "$self->{'first_semester'} $semester $relative_semester \n";

        my $loc = $self->{'loc'}->[$relative_semester];
	next unless (defined $loc);

# only change if it is not defined or if the semesters are different or if the credits are different
# print "$loc->{'sed'} -- $loc->{'semester'} -- $credits\n";
        if (
            ( $loc->{'sed'} == 0 )
            || (   ( $loc->{'semester'} != 0 )
                && ( $loc->{'semester'} < $semester ) )
            || ( $credits == 0 ) && ( $totalcreds == 0 )
          )
        {
 # ignore if total credits is equal to 0, probably jus taking some extra classes
            if ( $level > 0 ) {
                $loc->{'sed'}       = $sed;
                $self->{'last_sed'} = $sed;
            }
        }
        $loc->{'semester'} = $semester;
        $loc->{'total'}    = $totalcreds;

    }

    # now check to see if they got a degree
    my @degrees =
      $schema->resultset('Degree')->search( { 'student' => $student_id } );
    foreach my $d (@degrees) {
        my $dsed = $d->get_column('sed');
	$self->{'degrees'}->{$dsed} = 1;
        if ( $dsed == $self->{'last_sed'} ) {
            $self->{'complete'} = $#degrees + 1;
	    $self->{'last_semester'} = $d->get_column('semester');
	    $self->{'last_loc'} = $self->calc_relative ($self->{'last_semester'});
        }
    }

    # rank majors
    $self->rank_majors();

}    # init

sub get_seds {
    my $self = shift;
    my @seds = ();
    foreach my $i ( 0 .. 12 ) {
        push @seds, $self->{'loc'}->[$i]->{'sed'};
    }
    return \@seds;
}    # get_seds

sub calc_relative {
    my $self = shift;
    my $sem  = shift;

    my $diff = $sem - $self->{'first_semester'};
    return 0 if ( $diff == 0 );

    $diff += 4;
    my $years = int $diff / 10;
    $years--;    # due to the adding of 4 semesters
    my $terms = $diff % 10;
    $terms = int( ( $terms + 1 ) / 2 ) + $years * 2;

    #    print "\t diff $diff years $years $terms\n";
    return $terms;
}    # calc_relative

sub complete {
    my $self = shift;
    return $self->{'complete'};
}

sub degrees {
    my $self = shift;
    return $self->{'degrees'};
}

sub first_loc {
    my $self = shift;
    return $self->{'first_loc'};
}

sub last_loc {
    my $self = shift;
    return $self->{'last_loc'};
}

sub valid {
    my $self  = shift;

    return '' if ($self->{'first_semester'} == 0);   # no records

    my $start = $self->calc_relative(20023);
    return 1 if ( $start < 0 ) ;   # data is in range
    return ( $self->{'loc'}->[$start]->{'total'} == 0 ); # check to see if they were a fresh or transfer in 20023
    
}    # valid

sub prev_semester {
    my $sem    = shift;
    my $year   = int( $sem / 10 );
    my $season = $sem % 10;

    $season = $season - 2;
    if ( $season < 0 ) {
        $year   = $year - 1;
        $season = $season + 4;
    }
    return $year * 10 + $season;
}    # prev_semester

sub rank_majors {
    my $self = shift;

    foreach my $l (@{$self->{'loc'}}) {
	my $s = $l->{'sed'};
	if (! defined ($self->{'majors'}->{$s})) {
	    $self->{'num_majors'} += 1;
	    $self->{'majors'}->{$s} = $self->{'num_majors'};
	}
    }

} # rank_majors

sub get_major_rank {
    my $self = shift;
    my $sed  = shift;

    return $self->{'majors'}->{$sed};
    
} # get_major_rank

1;
