use strict;
use warnings;

require "$ENV{HOME}/iDGA/pl/subhub.pl";



my ($element,
    $field,
    $phases)  = parse_argv(@ARGV);



my $metadata_lines = 9;

my @complex_part = qw(MAG ANG_DEG);



my (@DTs,
    $data,
    @columns);

my $tis_the_beginning = 1;
print "READ:\n";

foreach my $phase (@$phases) {
	foreach my $cp (@complex_part) {
		if (-s (my $file = "${element}_${field}_${phase}_$cp.csv")) {
			open(my $fh, '<', $file) || die "$!";
			print "$file\n";
				
			my $line;
			foreach (1..$metadata_lines) {
				$line = <$fh>;
			}
			@columns = cut_string($line, ",");
				
			splice @columns, 0, 1; # all but "# timestamp"
				
			my ($dt,
			    $delete);
				
			while (<$fh>) {
				my @array = cut_string($_, ",") if ($_);
				my $DT    = timestamp_TZstrip($array[0]); # Date&Time, sans TZ info
					
				if ($DT eq $dt) { # i.e., timestamps of divergent NR iterations, which inevitably end with a *non-zero* exit code...
					$delete = 1;
				} else {
					my $i;
					foreach my $column (@columns) {
						$data->{$column}->{$phase}->{$cp}->{$DT} = $array[++$i];
					}
					push @DTs, $DT if ($tis_the_beginning);
				}
					
				$dt = $DT;
			}
			close($fh);

			$tis_the_beginning = 0 if ($tis_the_beginning);
				
			splice @DTs, -1 # all but that last timestamp at which the NR solver diverged (IF)
			  if ($delete);
		}
	}
}



make_directory("./$element/$field");

my @cn;
push @cn, "m$_", "a$_"
  foreach (@$phases);

my $column_names = join(',', @cn);

print "WRITE:\n";

foreach my $column (@columns) {
	print "column:$column\n";
	
	open(my $fh_out, '>', "./$element/$field/$column.csv") || die "$!";
	print $fh_out "local_time,$column_names\n";
	
	foreach my $DT (@DTs) {
		printf $fh_out "$DT";
		foreach my $phase (@$phases) {
			if ($data->{$column}->{$phase}->{$complex_part[0]}->{$DT} > 0) {
				printf $fh_out ",%.1f,%.1f",
				  $data->{$column}->{$phase}->{$complex_part[0]}->{$DT},
				  $data->{$column}->{$phase}->{$complex_part[1]}->{$DT};
			} else {
				printf $fh_out ",,";
			}
		}
		printf $fh_out "\n";
	}
	close($fh_out);
}



sub parse_argv {
	my ($element,
	    $field,
	    $phases);
	while (my $arg = shift) {
		if ($arg eq '-e') {
			$element = shift;
		} elsif ($arg eq '-f') {
			$field = shift;
		} elsif ($arg eq '-p') {
			$phases = shift;
		} else {
		}
	}
	if (!$element || !$field || !$phases) {
		print "USAGE: perl $0 -e element -f field -p phases\n";
		exit -1;
	}
	return($element,
	       $field,
	       [characterize_string($phases)]);
}
