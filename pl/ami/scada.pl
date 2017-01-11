use strict;
use warnings;

require "$ENV{HOME}/iDGA/pl/subhub.pl";





my ($f_id,
    $YYYYMMDD_0,
    $YYYYMMDD_1) = parse_argv(@ARGV);



my $full_interval = '001500';

my @Calendar = map { YYYYMMDD_format($_) } @{calendar($YYYYMMDD_0, timestamp_nonNstrip(yesterday($YYYYMMDD_1)))};

my @Times = sort(get_full_timestamps($full_interval));

my $half_timestamps = get_half_timestamps($full_interval);

my %MM = (JAN => "01",
	  FEB => "02",
	  MAR => "03",
	  APR => "04",
	  MAY => "05",
	  JUN => "06",
	  JUL => "07",
	  AUG => "08",
	  SEP => "09",
	  OCT => "10",
	  NOV => "11",
	  DEC => "12");





my (%KW,			# Column: "KW"
    %KVAR,			# Column: "KVAR"
    %IA,			# Column: "A_AMPS"
    %IB,			# Column: "B_AMPS"
    %IC,			# Column: "C_AMPS"
    %VA,			# Column: "A_KV"
    %VB,			# Column: "B_KV"
    %VC,			# Column: "C_KV"
    %V				# Column: "BUS_KV"
   );

my $head = <STDIN>;

while (<STDIN>) {
	my ($datetime,
	    $feeder,
	    @data)                = cut_string($_, ",");
	if ($feeder eq $f_id) {
		my ($dd_MON_YYYY,
		    $hh_mm_ss)    = cut_string($datetime,    " ");
		my ($dd,
		    $MON,
		    $YYYY)        = cut_string($dd_MON_YYYY, "-");
		my $dt            = "$YYYY-$MM{$MON}-$dd $hh_mm_ss";
		my $dtnumeric     = timestamp_nonNstrip($dt);
		if (($dtnumeric >= "${YYYYMMDD_0}000000") && ($dtnumeric <= "${YYYYMMDD_1}000000")) {
			$KW{$dt}   = $data[0];
			$KVAR{$dt} = $data[1];
			$IA{$dt}   = $data[2];
			$IB{$dt}   = $data[3];
			$IC{$dt}   = $data[4];
			$VA{$dt}   = $data[5];
			$VB{$dt}   = $data[6];
			$VC{$dt}   = $data[7];
			$V{$dt}    = $data[8];
		}
	}
}



open(my $fh_out, '>', 'out.csv') || die "$!";
print $fh_out "local_time,P,Q,ia,ib,ic,va,vb,vc,vBus\n";

my $i = 0;
foreach my $Date (@Calendar) {
	my $j = 0;
	foreach my $Time (@Times) {
		my $DT        = "$Date $Time";
		my $half_time = $half_timestamps->{substr(timestamp_nonNstrip($Time), 0, 4)};
		my $time      = $Times[$j-1];
		my $date;
		if ($j) {
			$date = $Date;
		} else {
			$date = $Calendar[$i-1]
			  if ($i > 0); # necessary because $Calendar[-1] is the last day in the calendar!
		}
		my $dt      = "$date $time";
		my $half_dt = "$date $half_time"; # (It's safe to use $date for $half_dt too with this 15-minute interval data.)
		my $kw      = sprintf("%.1f", ($KW{$dt}   + $KW{$DT})   / 2) if ($KW{$dt}   && $KW{$DT});
		my $kvar    = sprintf("%.1f", ($KVAR{$dt} + $KVAR{$DT}) / 2) if ($KVAR{$dt} && $KVAR{$DT});
		my $ia      = sprintf("%.1f", ($IA{$dt}   + $IA{$DT})   / 2) if ($IA{$dt}   && $IA{$DT});
		my $ib      = sprintf("%.1f", ($IB{$dt}   + $IB{$DT})   / 2) if ($IB{$dt}   && $IB{$DT});
		my $ic      = sprintf("%.1f", ($IC{$dt}   + $IC{$DT})   / 2) if ($IC{$dt}   && $IC{$DT});
		my $va      = sprintf("%.1f", ($VA{$dt}   + $VA{$DT})   / 2) if ($VA{$dt}   && $VA{$DT});
		my $vb      = sprintf("%.1f", ($VB{$dt}   + $VB{$DT})   / 2) if ($VB{$dt}   && $VB{$DT});
		my $vc      = sprintf("%.1f", ($VC{$dt}   + $VC{$DT})   / 2) if ($VC{$dt}   && $VC{$DT});
		my $v       = sprintf("%.1f", ($V{$dt}    + $V{$DT})    / 2) if ($V{$dt}    && $V{$DT});
		print $fh_out "$half_dt,$kw,$kvar,$ia,$ib,$ic,$va,$vb,$vc,$v\n" if ($date);
		$j++;
	}
	$i++;
}

close($fh_out);



sub parse_argv {
	my ($f_id,  # FeederId, whose SCADA data is of interest to us.
	    $YYYYMMDD_0, # YYYYMMDD [0Z] at which to BEGIN saving SCADA data.
	    $YYYYMMDD_1 #                                          END
	   ) = @_;
	while (my $arg = shift) {
		if ($arg eq '-f' || $arg eq '--feeder') {
			$f_id = shift;
		} elsif ($arg eq '-0' || $arg eq '--begin') {
			$YYYYMMDD_0 = shift;
		} elsif ($arg eq '-1' || $arg eq '--end') {
			$YYYYMMDD_1 = shift;
		} else {
		}
	}
	if (!$f_id) {
		print STDOUT "pbexec $0 -f f_id -0 YYYYMMDD_0 -1 YYYYMMDD_1 2> .err.log\n";
		exit -1;
	}
	$YYYYMMDD_0 = "18000101" if (!$YYYYMMDD_0);
	$YYYYMMDD_1 = "27000101" if (!$YYYYMMDD_1);
	return($f_id,
	       $YYYYMMDD_0,
	       $YYYYMMDD_1
	      );
}





# pbexec ~/iDGA/pl/ami/scada.pl -f '"78G1"' -0 '20150701' -1 '20150801' 2> .err.log < ~/data/raw/gmp/78g1/scada/april2015_through_march2016.txt
