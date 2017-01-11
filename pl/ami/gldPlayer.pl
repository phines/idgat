use strict;
use warnings;

require "$ENV{HOME}/iDGA/pl/subhub.pl";





my $dir_inp = "$ENV{HOME}/data/proc/gmp/78g1/ami/pass1"; # -fake
my $na      = 'NA';

my $file_scada = "$ENV{HOME}/data/proc/gmp/78g1/scada/2015-july-1st-31st.csv";

my $kW_losses = 15;		# percent

my %pf = (C  => 85,		# Commercial
	  CR => 90,		# Commercial / Residential
	  R  => 95		# Residential
	 );			# power factors (percent)





my (%P_scada,
    %Q_scada,			# currently unused 
    @DTs);

my $i_scada = {};

open(my $scada, '<', $file_scada) || die "$!";
my $header = <$scada>;

while (<$scada>) {
	my @a                  = cut_string($_, ",");
	$P_scada{$a[0]}        =  $a[1];
	$Q_scada{$a[0]}        =  $a[2];
	$i_scada->{$a[0]}->{A} =  $a[3];
	$i_scada->{$a[0]}->{B} =  $a[4];
	$i_scada->{$a[0]}->{C} =  $a[5];
	push @DTs,                $a[0]; # Date&Time
}

close($scada);



my ($mp0,			# p0: pass 0
    %id_p0,
    @spid_p0);

open($mp0, '<', './ami-mp0u.csv') || die "$!"; # m: meta; u: usage
$header = <$mp0>;

while (<$mp0>) {
	my @a           = cut_string($_, ",");
	push @spid_p0,    $a[0];
	$id_p0{$a[0]}   = $a[1];
}

close($mp0);



my (@cn_cndn,			# CYMD "CustomerNumber" (all)
    %DN);

open(my $cymd2gld_cndn, '<', './cn-dn.csv') || die "$!"; # "CustomerNumber" => "DeviceNumber"
$header = <$cymd2gld_cndn>;

while (<$cymd2gld_cndn>) {
	my @a        = cut_string($_, ",");
	push @cn_cndn, $a[0];
	$DN{$a[0]}   = $a[1];
}

close($cymd2gld_cndn);


my %cnstr; # "CustomerNumber" string for a "DeviceNumber" (delimiter: ___)

foreach my $cn (@cn_cndn) {
	if (grep { $cn eq $_ } @spid_p0) {
		$cnstr{$DN{$cn}} .= "${cn}___";
	} else {
		print "CYMD CN $cn: No AMI Match.\n";
	}
}
print "\n\n\n\n";



my (@dns,
    $Phases,
    %nPhases);

open(my $cymd2gld_dnph, '<', './dn-ph.csv') || die "$!"; # "DeviceNumber" => Phases
$header = <$cymd2gld_dnph>;

while (<$cymd2gld_dnph>) {
	my ($dn,
	    @phs)      = cut_string($_, ",");
	push @dns,       $dn;
	splice @phs, -1, 1;	# rm N/S
	$Phases->{$dn} = [@phs];
	$nPhases{$dn}  = $#phs + 1;
}

close($cymd2gld_dnph);



my %ck;

open(my $cymd2gld_dnkva, '<', './dn-kva.csv') || die "$!"; # "DeviceNumber" => greater_of("ConnectedKVA", "NominalRatingKVA")
$header = <$cymd2gld_dnkva>;

while (<$cymd2gld_dnkva>) {
	my @a      = cut_string($_, ",");
	$ck{$a[0]} = $a[1];
}

close($cymd2gld_dnkva);



my %rci;

open(my $cymd2gld_dnrci, '<', './dn-rci.csv') || die "$!"; # "DeviceNumber" => "RCI"
$header = <$cymd2gld_dnrci>;

while (<$cymd2gld_dnrci>) {
	my @a       = cut_string($_, ",");
	$rci{$a[0]} = $a[1];
}

close($cymd2gld_dnrci);



my $dir_out = "l";
make_directory($dir_out);

my $P_ami        = {};
my $file_handles = {};

foreach my $dn (@dns) {	
	my @cs = cut_string($cnstr{$dn}, '___');
	
	if (my $nc = $#cs + 1) {
		print "$dn:\t";
		
		foreach my $cn (@cs) {
			print "$cn; ";

			if (-s (my $input_file = "$dir_inp/$id_p0{$cn}.csv")) {
				open(my $pass1, '<', $input_file) || die "$!";
				my $header = <$pass1>;
				
				while (<$pass1>) {
					my @a = cut_string($_, ",");
					if ($a[1] ne $na) {
						$P_ami->{$a[0]}->{$dn} += $a[1]; # *active* power
					}
				}
				close($pass1);
			}
		}
		print "\n\n\n\n";
	}
	
	foreach my $ph (@{$Phases->{$dn}}) {
		open(my $fh, '>', "$dir_out/inp_cp__${dn}__${ph}.csv") || die "$!";
		$file_handles->{$dn}->{$ph} = $fh;
	}
}



foreach my $DT (@DTs) {
	my $Ptotal_ami = 0;
	my $ck_total   = 0;
	my @null       = ();
	
	foreach my $dn (@dns) {
		if (exists $P_ami->{$DT}->{$dn}) {
			$Ptotal_ami += $P_ami->{$DT}->{$dn};
		} else {
			$ck_total += $ck{$dn};
			push @null, $dn;
		}
	}

	my $P_after_losses = (1 - $kW_losses/100) * abs($P_scada{$DT});

	if ($P_after_losses >= $Ptotal_ami) {
		my $diff = $P_after_losses - $Ptotal_ami;
		printf "%s\tdiff=%.1f\n", $DT, $diff;
		foreach my $dev_null (@null) {
			$P_ami->{$DT}->{$dev_null} = ($ck{$dev_null} / $ck_total) * $diff;
			printf "%s\tp=%.1f\n", $dev_null, $P_ami->{$DT}->{$dev_null};
		}
		print "\n\n\n\n";
	} else {
		print "$DT\tWARNING\tPtotal_ami > P_scada!\n\n\n\n";
	}
	
	my %i_scada_total   = ();
	
	# PRE-compute (surely, there's a more sophisticated [combinatorial] of doing this):
	$i_scada_total{A}   = $i_scada->{$DT}->{A};
	$i_scada_total{B}   =                        $i_scada->{$DT}->{B};
	$i_scada_total{C}   =                                               $i_scada->{$DT}->{C};
	$i_scada_total{AB}  = $i_scada->{$DT}->{A} + $i_scada->{$DT}->{B};
	$i_scada_total{BC}  =                        $i_scada->{$DT}->{B} + $i_scada->{$DT}->{C};
	$i_scada_total{AC}  = $i_scada->{$DT}->{A}                        + $i_scada->{$DT}->{C};
	$i_scada_total{ABC} = $i_scada->{$DT}->{A} + $i_scada->{$DT}->{B} + $i_scada->{$DT}->{C};
	
	foreach my $dn (@dns) {
		if (my $P = $P_ami->{$DT}->{$dn} * 1000) { # *1000: kW to W
			my %weights = ();
			
			foreach my $phase (@{$Phases->{$dn}}) {
				my $phases = join('', @{$Phases->{$dn}});
				if ($i_scada_total{$phases}) {
					$weights{$phase} = $i_scada->{$DT}->{$phase} / $i_scada_total{$phases};
				} else {
					$weights{$phase} = 1 / $nPhases{$dn};
				}
			}
			
			foreach my $phase (@{$Phases->{$dn}}) {
				my $p  = $P * $weights{$phase};
				my $q  = reactive_power($p, $pf{$rci{$dn}});
				my $cp = complex_power($p, $q);
				my $fh = $file_handles->{$dn}->{$phase};
				print $fh "$DT,$cp\n";
			}
		}
	}
}
