use strict;
use warnings;
use File::Path qw(make_path);
use Math::Trig qw(:pi);





# Cuts a string on a specified delimiter:
sub cut_string {
	my ($s,		       # String
	    $d) = @_;	       # Delimiter (e.g. ',')
	$d =  "\\s+" if (!$d); # i.e., the default delimiter is whitespace(s)
	$s =~ s/^\s+//aa;      # Remove leading  whitespace characters
	$s =~ s/\s+$//aa;      #        trailing
	my @a = split(/$d/, $s);
	return(@a);
}



# Finds unique elements in a list:
# (Inspired by findUnique() at
#  https://sourceforge.net/p/gridlab-d/code/HEAD/tree/Taxonomy_Feeders/PopulationScript/ConversionScripts/Cyme_to_GridLabD.txt
# )
sub unique_elements {
	my (@a) = @_;
	my %h;
	return(grep { !$h{$_}++ } @a);
}



# Finds the intersection of two lists:
# (Inspired by the answer given by "chromatic" at
#  http://www.perlmonks.org/?node_id=2461
# )
sub intersection_of {
	my ($a,			# Reference to List 1
	    $b			#                   2
	   ) = @_;
	my %c = map { $_ => 1 } @$a;
	return(grep { $c{$_}  } @$b);
}



# Decomposes a string into its characters:
sub characterize_string {
	my ($s) = @_;		# String
	my @c;
	foreach (my $i = 0; $i < length $s; $i++) {
		push @c, substr($s, $i, 1);
	}
	return(@c);
}



# Combines unique characters from a string into a new string:
sub unique_characters {
	my ($s) = @_;		# String
	return(join('', sort(unique_elements(characterize_string($s)))));
}



# Computes the mean of a (numerical) list:
sub mean_numlist {
	my (@list) = @_;
	my ($sum,
	    $n);
	foreach (@list) {
		if ($_) {
			$sum += $_;
			$n   += 1;
		}
	}
	return($sum / $n) if ($n);
}



# Returns the greater of two numbers:
sub the_greater_of {
	my ($a,
	    $b) = @_;
	return($a > $b ? $a : $b);
}



# Rounds an integer $i to its next $j'th value:
sub round_upto {
	my ($i,
	    $j
	   ) = @_;
	$i += $j - ($i % $j);
	return($i);
}



# Computes the area of a circle given its diameter:
sub area_circle {
	my ($d) = @_;
	return(pi / 4 * $d**2);
}



# Returns the magnitude and angle of a complex number specified in rectangular notation:
sub magnitude_angle {
	my ($real,
	    $imaginary) = @_;
	my ($magnitude,
	    $angle);
	my $epsilon = 1E-9;
	if ($real && $imaginary) {
		if ((abs $real < $epsilon) && (abs $imaginary < $epsilon)) {
			$magnitude = $angle = 0;
		} else {
			$magnitude = sqrt($real**2 + $imaginary**2);
			$angle     = atan2($imaginary, $real) * 180 / pi;
		}
	} else {
		$magnitude = $angle = 'NA';
	}
	return($magnitude, $angle);
}



# Wrapper for make_path():
sub make_directory {
	my ($dir) = @_;
	if (-d $dir) {
		# All is well!
	} elsif (-f $dir) {
		printf STDOUT "ERROR: $dir exists but is a file: Not sure how to proceed: Exit -1.\n";
		exit -1;
	} else {
		make_path($dir, { error => \my $msg });
		file_path_error_messages($msg);
	}
}



# Prints error messages, if any, from the invocation of File::Path's make_path() and remove_tree():
sub file_path_error_messages {
	my ($error) = @_;
	if (@$error) {
		foreach (@$error) {
			my ($file,
			    $message) = %$_;
			printf STDOUT "$message\n";
		}
	} else {
	}
}



# Strips a timestamp of all non-numeric characters (e.g. '2016-03-31 23:52:30 EDT' => '20160331235230'):
sub timestamp_nonNstrip {
	my ($timestamp) = @_;
	$timestamp =~ s/[[:alpha:][:punct:][:space:]]//aag;
	return($timestamp);
}



# Strips the (trailing) time zone from a timestamp (e.g. '2016-03-31 23:52:30 EDT' => '2016-03-31 23:52:30'):
sub timestamp_TZstrip {
	my ($timestamp) = @_;
	$timestamp =~ s/[[:alpha:]]//aag;
	$timestamp =~ s/\s+$//aa;
	return($timestamp);
}



# This beautiful "bit" (pun intended) of CS logic is from http://stackoverflow.com/a/11595914:
sub is_it_a_leap_year {
	my ($year) = @_;
	return(($year & 3) == 0 && (($year % 25) != 0 || ($year & 15) == 0));
}



# Returns all dates *from* YYYYMMDD_0 *through* YYYYMMDD_1:
sub calendar {
	my ($YYYYMMDD_0,
	    $YYYYMMDD_1) = @_;
	my @dates;
	my @monthly_days = (0,	# N/A
			    31,	# Jan
			    28,	# Feb (non-leap year)
			    31,	# Mar
			    30,	# Apr
			    31,	# May
			    30,	# Jun
			    31,	# Jul
			    31,	# Aug
			    30,	# Sep
			    31,	# Oct
			    30,	# Nov
			    31	# Dec
			   );
	my $yyyy  = substr($YYYYMMDD_0, 0, 4);
	my $mm    = substr($YYYYMMDD_0, 4, 2);
	my $dd    = substr($YYYYMMDD_0, 6, 2);
	my $today = $YYYYMMDD_0;
	until ($today > $YYYYMMDD_1) {
		push @dates, $today;
		if (++$dd > (($mm == 2 && is_it_a_leap_year($yyyy)) ? 29 : $monthly_days[$mm])) {
			$dd = 1;
			if ($mm == 12) {
				$yyyy += 1;
				$mm    = 1;
			} else {
				$mm   += 1;
			}
		}
		$today = sprintf("%04s%02s%02s", $yyyy, $mm, $dd);
	}
	return(\@dates);
}



# Returns tomorrow's date, given today's in "YYYYMMDD":
sub tomorrow {
	my ($YYYYMMDD) = @_;
	my $YYYY = substr($YYYYMMDD, 0, 4);
	my $MM   = substr($YYYYMMDD, 4, 2);
	my $DD   = substr($YYYYMMDD, 6, 2);
	my @monthly_days = (0,	# N/A
			    31,	# Jan
			    28,	# Feb (non-leap year)
			    31,	# Mar
			    30,	# Apr
			    31,	# May
			    30,	# Jun
			    31,	# Jul
			    31,	# Aug
			    30,	# Sep
			    31,	# Oct
			    30,	# Nov
			    31	# Dec
			   );
	my %next_month_MMDD = ('01' => '02-01',
			       '02' => '03-01',
			       '03' => '04-01',
			       '04' => '05-01',
			       '05' => '06-01',
			       '06' => '07-01',
			       '07' => '08-01',
			       '08' => '09-01',
			       '09' => '10-01',
			       '10' => '11-01',
			       '11' => '12-01',
			       '12' => '01-01'
			      );
	if (("$MM$DD" eq '0228') && is_it_a_leap_year($YYYY)) {
		return("$YYYY-02-29");
	} elsif ($DD >= $monthly_days[$MM]) { # >= accounts for 02-29 (leap)
		$YYYY++ if ($MM eq '12');
		return(sprintf("%04s-%05s", $YYYY, $next_month_MMDD{$MM}));
	} else {
		return(sprintf("%04s-%02s-%02s", $YYYY, $MM, ++$DD));
	}
}



# Returns yesterday's date, given today's in "YYYYMMDD":
sub yesterday {
	my ($YYYYMMDD) = @_;
	my $YYYY = substr($YYYYMMDD, 0, 4);
	my $MM   = substr($YYYYMMDD, 4, 2);
	my $DD   = substr($YYYYMMDD, 6, 2);
	my %previous_month_MMDD = ('01' => '12-31',
				   '02' => '01-31',
				   '03' => '02-28',
				   '04' => '03-31',
				   '05' => '04-30',
				   '06' => '05-31',
				   '07' => '06-30',
				   '08' => '07-31',
				   '09' => '08-31',
				   '10' => '09-30',
				   '11' => '10-31',
				   '12' => '11-30'
				  );
	if (("$MM$DD" eq '0301') && is_it_a_leap_year($YYYY)) {
		return("$YYYY-02-29");
	} elsif ($DD eq '01') {
		$YYYY-- if ($MM eq '01');
		return(sprintf("%04s-%05s", $YYYY, $previous_month_MMDD{$MM}));
	} else {
		return(sprintf("%04s-%02s-%02s", $YYYY, $MM, --$DD));
	}
}



# Returns the time in "hh:mm:ss" format, given "hhmmss":
sub hhmmss_format {
	my ($hhmmss) = @_;
	my $hh = substr($hhmmss, 0, 2);
	my $mm = substr($hhmmss, 2, 2);
	my $ss = substr($hhmmss, 4, 2);
	return("$hh:$mm:$ss");
}



# Returns the date in "YYYY-MM-DD" format, given "YYYYMMDD":
sub YYYYMMDD_format {
	my ($YYYYMMDD) = @_;
	my $YYYY = substr($YYYYMMDD, 0, 4);
	my $MM   = substr($YYYYMMDD, 4, 2);
	my $DD   = substr($YYYYMMDD, 6, 2);
	return("$YYYY-$MM-$DD");
}



# __INTERNAL__
# Get *implied* timestamps for a day's worth of AMI data --
# For example, "time = 0100, usage_value = 0.01 KWh,"
# means the energy used *between* 00:45am and 01:00am is 0.01 KWh.
# Hence, the rate of energy consumption (i.e. power) = 0.01 KWh / (1h / 4) = 0.04 KW,
# with the timestamp *midway* between 00:45am and 01:00am,
# i.e. 00h:52m:30s.
sub get_half_timestamps {
	my ($full_interval) = @_; # "hhmmss" format (e.g. '001500' for 15 minutes)
	my (%timestamp);
	my $ONE_HOUR = 60;	# minutes
	my @HH       = ("00" .. "23");
	my @MM;
	my $dmm = substr($full_interval, 2, 2);
	my $mm  = 0;
	while ($mm < $ONE_HOUR) {
		push @MM, sprintf("%02d", $mm);
		$mm += $dmm;
	}
	my $half_interval = sprintf("%06s", hhmm_subtraction_friendly($full_interval) / 2);
	foreach my $hh (@HH) {
		foreach my $mm (@MM) {
			$timestamp{"$hh$mm"} = hhmmss_format(sprintf("%06s", hhmm_subtraction_friendly("$hh$mm") - $half_interval));
		}
	}
	return(\%timestamp);
}



# __INTERNAL__
# Unlike get_half_timestamps(), return "full" timestamps:
sub get_full_timestamps {
	my ($full_interval) = @_;
	my (@timestamps);
	my $ONE_HOUR = 60;	# minutes
	my @HH       = ("00" .. "23");
	my @MM;
	my $dmm = substr($full_interval, 2, 2);
	my $mm  = 0;
	while ($mm < $ONE_HOUR) {
		push @MM, sprintf("%02d", $mm);
		$mm += $dmm;
	}
	foreach my $hh (@HH) {
		foreach my $mm (@MM) {
			push @timestamps, "$hh:$mm:00";
		}
	}
	return(@timestamps);
}



# __INTERNAL__
# Given a time string in "hhmm" format (e.g. 0045), as in GMP's raw AMI data,
# make it subtraction friendly (i.e. 004460) for use *only* with get_half_timestamps():
sub hhmm_subtraction_friendly {
	my ($hhmm) = @_;
	return('235960') if ($hhmm eq '0000');
	my $hh = substr($hhmm, 0, 2);
	my $mm = substr($hhmm, 2, 2);
	my $ss = '60';
	if ($mm eq '00') {
		$hh -= '01';
		$mm  = '59';
	} else {
		$mm -= '01';
	}
	return("$hh$mm$ss");
}



# __INTERNAL__
sub reactive_power {
	my ($active_power,
	    $power_factor
	   ) = @_;
	my $powf = $power_factor / 100;	  # percent to fraction
	my $appp = $active_power / $powf; # apparent power
	return($appp * sqrt(1 - $powf**2));
}



# __INTERNAL__
sub complex_power {
	my ($P,			# active   power
	    $Q			# reactive power 
	   ) = @_;
	my $S;
	if ($P && $Q) {
		my $plus = '+' if ($Q >= 0);
		$S       = sprintf('%.3f%s%.3f%s', $P, $plus, $Q, 'j');
	}
	return($S);
}





##############################DO NOT TOUCH##################################
1; # To "require" this file in another, a truthy value needs to be returned.
############################################################################
