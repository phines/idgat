use strict;
use warnings;

require "$ENV{HOME}/iDGA/pl/subhub.pl";





my ($DT_0,
    $DT_1) = parse_argv(@ARGV);



# Advanced Metering Infrastructure (AMI) MetaData:
open(my $meta_raw, '<', "$ENV{HOME}/data/raw/gmp/78g1/ami/meta_latlon.tsv") || die "$!";





my $header = <$meta_raw>;

# The AMI metadata file has 6 columns:
# 0. SP_ID      -- Service Point ID (13-digit string)
# 1. LATITUDE   -- Latitude
# 2. LONGITUDE  -- Longitude
# 3. GEN_TYPE   -- If *no* DER onsite, then "NA"; else, "PV" or some such string
# 4. FEEDER     -- Feeder ID
# 5. SP_TYPE_CD -- If residential, then "E-RES"; else if commercial, then "E-COM"; else, "INTERRES" (DER onsite)

my %type = ('E-RES'    => 'R',
	    'E-COM'    => 'C',
	    'INTERRES' => 'I'
	   );

my (%id,
    %pv,
    %FHu,			# FH: filehandle; u: usage
    %FHg,			# g:  generation
    $mp0u,			# m:  meta; p0: pass 0
    $mp0g);

my $file_mp0u = "./ami-mp0u.csv";
my $file_mp0g = "./ami-mp0g.csv";

# > 0, if it exists and is *non-empty*; else, = 0:
my $file_mp0u_exists = -s $file_mp0u;
my $file_mp0g_exists = -s $file_mp0g;

if (!$file_mp0u_exists) {
	open($mp0u, '>', $file_mp0u) || die "$!";
	print $mp0u "service_point_id,id,latitude,longitude,type\n";
}

if (!$file_mp0g_exists) {
	open($mp0g, '>', $file_mp0g) || die "$!";
	print $mp0g "service_point_id,id,latitude,longitude,type\n";
}

my $dir_out = "$ENV{HOME}/data/proc/gmp/78g1/ami/pass0";
make_directory($dir_out);

my $n = 0;

while (<$meta_raw>) {
	my @a      =  cut_string($_);
	$id{$a[0]} =  sprintf("%05d", ++$n);
	my $SPId   =  $a[0];
	$SPId      =~ s/GMP$//aa;
	print $mp0u "$SPId,$id{$a[0]},$a[1],$a[2],$type{$a[5]}\n" if (!$file_mp0u_exists);
	open(my $fhu, '>>', "$dir_out/$id{$a[0]}.csv") || die "$!"; # Note the '>>'
	$FHu{$a[0]} = $fhu;
	if ($a[3] eq 'PV') {
		print $mp0g "$SPId,$id{$a[0]}g,$a[1],$a[2],$type{$a[5]}\n" if (!$file_mp0g_exists);
		open(my $fhg, '>>', "$dir_out/$id{$a[0]}g.csv") || die "$!";
		$FHg{$a[0]} = $fhg;
		$pv{$a[0]}  = 1;
	}
}



# AMI *actual* data -- Redirect from STDIN:
$header = <STDIN>;		# Header

# The above file has 9 columns:
# 0. service_point_id  -- same as "CustomerNumber" from the CYMCUSTOMERLOAD table of the gmp_net MySQL DB, except with "GMP" appended
# 1. date              -- YYYYMMDD
# 2. time              -- hhmm (EDT, DST adjusted)
# 3. utc_offset        -- -0400 or -0500
# 4. units             -- kWh
# 5. usage_value       -- power consumption over the *preceding* 15 minutes
# 6. usage_is_estimate -- flag (is the above value an estimate (E) or actual [A]?)
# 7. gen_value         -- power generation  over the *preceding* 15 minutes (if DER onsite)
# 8. gen_is_estimate   -- flag (is the above value an estimate (E) or actual [A]?)

my $one_hour        = '006000'; # = 60 minutes
my $full_interval   = '001500'; # = 15 minutes, which is the time interval between 2 AMI readings.

my $kWh_to_kW       = $one_hour / $full_interval;

my $half_timestamps = get_half_timestamps($full_interval);

my ($Line,
    %Yesterday,
    $spid);

while (<STDIN>) {
	my $line = $_;
	if ($line ne $Line) {  # NOT a facsimilie of the previous line
		my @a = cut_string($line);
		if ("$a[1]$a[2]" >= "$DT_0" && "$a[1]$a[2]" <= "$DT_1") {
			$Yesterday{$a[0]} = yesterday($a[1]) if (!exists $Yesterday{$a[0]});
			my $date          = ($a[2] eq '0000') ? $Yesterday{$a[0]} : YYYYMMDD_format($a[1]);
			my $time          = $half_timestamps->{$a[2]};
			my $dt            = "$date $time";
			my $kW            = $a[5] * $kWh_to_kW;
			my $ae            = $a[6];
			my $fhu           = $FHu{$a[0]};
			print $fhu "$dt,$kW,$ae\n";
			if ($pv{$a[0]}) {
				$kW     = $a[7] * $kWh_to_kW * -1; # PV generation: "negative" load [with unity power factor--see gldPlayer.pl]
				$ae     = $a[8];
				my $fhg = $FHg{$a[0]};
				print $fhg "$dt,$kW,$ae\n";
			}
			$Yesterday{$a[0]} = $date;
		}
		if ($a[0] ne $spid) {
			$spid = $a[0];
			print "SPId=$spid\tnow=$a[1]\n";
		}
	}
	$Line = $line;
}



sub parse_argv {
	my ($DT_0, # date & time (YYYYMMDDhhmm) at which to BEGIN saving AMI data
	    $DT_1  #                                         END
	   ) = @_;
	while (my $arg = shift) {
		if ($arg eq '-0' || $arg eq '--begin') {
			$DT_0 = shift;
		} elsif ($arg eq '-1' || $arg eq '--end') {
			$DT_1 = shift;
		} else {
		}
	}
	$DT_0 = "180001010000" if (!$DT_0);
	$DT_1 = "270001010000" if (!$DT_1);
	return($DT_0,
	       $DT_1);
	
}





# pbexec ~/iDGA/pl/ami/pass0.pl -0 201504010100 -1 201602292345 2> /dev/null < ~/data/raw/gmp/78g1/ami/april2015_through_march2016.tsv
# pbexec ~/iDGA/pl/ami/pass0.pl -0 201603010000 -1 201604010000 2> /dev/null < ~/data/raw/gmp/78g1/ami/march2016_only_corrected_dst.tsv
