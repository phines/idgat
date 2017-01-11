use strict;
use warnings;

require "$ENV{HOME}/iDGA/pl/subhub.pl";





my @IDs =  ('00001' .. '00959');
push @IDs, ('00284g', '00426g', '00881g');

my $YYYYMMDD_0 = '20150401';
my $YYYYMMDD_1 = '20160331';

my @skip_these_DTs = ('2016-03-13 02:07:30',
		      '2016-03-13 02:22:30',
		      '2016-03-13 02:37:30',
		      '2016-03-13 02:52:30'
		     ); # End of "Daylight Saving Time" in March: the "missing" hour (2-3am)

my %fill_these_DTs_with = ('2016-03-13 01:52:30' => '2016-03-13 02:52:30' # 2am in March when clocks are set *ahead* by an hour
			  );

my $dir_inp = "$ENV{HOME}/data/proc/gmp/78g1/ami/pass0";





my $full_interval = '001500';

my @Calendar = map { YYYYMMDD_format($_) } @{calendar($YYYYMMDD_0, $YYYYMMDD_1)};

my @Times = sort values %{get_half_timestamps($full_interval)};

my @DTs;
foreach my $date (@Calendar) {
	foreach my $time (@Times) {
		my $DT = "$date $time";
		if (!grep { $DT eq $_ } @skip_these_DTs) {
			push @DTs, $DT;
		}
	}
}



my $dir_out = "$ENV{HOME}/data/proc/gmp/78g1/ami/pass1";
make_directory($dir_out);

my (%kW,
    %qc);

foreach my $id (@IDs) {
	print "$id\n";
	
	open(my $pass0, '<', "$dir_inp/$id.csv") || die "$!";	
	while (<$pass0>) {
		my @a = cut_string($_, ",");
		# Account for *dual* entries
		# (e.g. from 1-2am in November when clocks are set *back* by an hour at 2am):
		$kW{$a[0]} = exists $kW{$a[0]} ? (($kW{$a[0]} + $a[1]) / 2)             : $a[1];
		$qc{$a[0]} = exists $qc{$a[0]} ? (unique_characters("$qc{$a[0]}$a[2]")) : $a[2];
	}

	foreach (keys %fill_these_DTs_with) {
		$kW{$_} = $kW{$fill_these_DTs_with{$_}} if (exists $kW{$fill_these_DTs_with{$_}});
		$qc{$_} = $qc{$fill_these_DTs_with{$_}} if (exists $qc{$fill_these_DTs_with{$_}});
	}

	open(my $pass1, '>', "$dir_out/$id.csv") || die "$!";
	print $pass1 "local_time,kW,qc\n";
	
	foreach my $dt (@DTs) {
		print $pass1 "$dt,";
		if (exists $kW{$dt}) {
			print $pass1 "$kW{$dt},$qc{$dt}\n";
		} else {
			print $pass1 "NA,-\n";
		}
	}
	
	%kW = %qc = ();
}
