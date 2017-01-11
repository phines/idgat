use strict;
use warnings;

require "$ENV{HOME}/iDGA/pl/subhub.pl";



my ($cim,
    $isn) = parse_argv(@ARGV);



my @names   = ();
my $Friends = {};

open(my $fh_nn, '<', 'node-nodes.csv') || die "$!";

while (<$fh_nn>) {
	my ($name,
	    @friends) = cut_string($_, ",");
	push @names, $name;
	$Friends->{$name} = [sort { $a <=> $b } @friends];
}
close($fh_nn);



my $keeper = {};

open(my $fh_n, '<', 'nodes.csv') || die "$!";
my $head = <$fh_n>;

while (<$fh_n>) {
	my ($non,
	    $is_loaded,
	    @spam) = cut_string($_, ",");
	if ($isn) {
		$keeper->{$non} = 1;
	} else {
		$keeper->{$non} = !$is_loaded;
	}
}
close($fh_n);



my $ph_a = {};
my $ph_b = {};
my $ph_c = {};

open(my $fh_l, '<', 'links.csv') || die "$!";
$head = <$fh_l>;

while (<$fh_l>) {
	my ($section,
	    $is_ohl_ugl,
	    $from_node,
	    $to_node,
	    $in_a,
	    $in_b,
	    $in_c,
	    @spam) = cut_string($_, ",");
	$ph_a->{$from_node}->{$to_node} = $ph_a->{$to_node}->{$from_node} = $in_a;
	$ph_b->{$from_node}->{$to_node} = $ph_b->{$to_node}->{$from_node} = $in_b;
	$ph_c->{$from_node}->{$to_node} = $ph_c->{$to_node}->{$from_node} = $in_c;
}
close($fh_l);



my $smi = {};			# sparse matrix index

open(my $fh_s2n, '<', 'smi2non.csv') || die "$!";
$head = <$fh_s2n>;

while (<$fh_s2n>) {
	my ($i0,
	    $i1,
	    $non) = cut_string($_, ",");
	my @indices  = ($i0 .. $i1);
	$smi->{$non} = [@indices]; # one-to-many
}
close($fh_s2n);



# To understand the contents and structure of GridLab-D's "Y-Bus" matrix, please read the following paper:
# "Three-phase power flow calculations using the current injection method," by Garcia et al. [2000], DOI:10.1109/59.867133.

my $Y = [];

$head = <STDIN>;

while (<STDIN>) {
	my ($i,
	    $j,
	    $value) = cut_string($_, ",");
	$Y->[$i]->[$j] = $value;
}



open(my $fh_nam, '>', 'nam.csv') || die "$!";
print $fh_nam "from_node,to_node,ph_a,ph_b,ph_c,admittance\n";

foreach my $name (sort { $a <=> $b } @names) {
	if ($keeper->{$name}) {
		my @i = @{$smi->{$name}};
		my $m = ($#i + 1) / 2;
		my @o = splice @i, 0, $m;
		foreach my $friend (@{$Friends->{$name}}) {
			if ($keeper->{$friend}) {
				my @j = @{$smi->{$friend}};
				my $n = ($#j + 1) / 2;
				my @y = ();
				foreach my $k (@o) {
					foreach my $l (0 .. $n-1) {
						my $ReZ = $Y->[$k]->[$j[0]+$l+$n];
						my $ImZ = $Y->[$k]->[$j[0]+$l];
						if ($ReZ && $ImZ) {
							my $sign = '+' if ($ImZ >= 0);
							push @y, sprintf("%.5f%s%.5f%s", $ReZ, $sign, $ImZ, $cim);
						}
					}
				}
				my $yStr = join(',', @y);
				if ($cim eq 'j') {
					$yStr = "[$yStr]";
				} else {
					$yStr = "\"c($yStr)\"";
				}
				print $fh_nam "$name,$friend,$ph_a->{$name}->{$friend},$ph_b->{$name}->{$friend},$ph_c->{$name}->{$friend},$yStr\n";
			}
		}
	}
}

close($fh_nam);



sub parse_argv {
	my ($cim,
	    $isn);
	while (my $arg = shift) {
		if ($arg eq '-i') {
			$cim = 'i';
		} elsif ($arg eq '-j') {
			$cim = 'j';
		} elsif ($arg eq '-isn') { # INCLUDE Secondary Nodes
			$isn = 1;
		} else {
		}
	}
	$cim = 'i' if (!$cim);
	return($cim,
	       $isn);
}
