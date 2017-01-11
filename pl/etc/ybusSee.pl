use strict;
use warnings;

require "$ENV{HOME}/iDGA/pl/subhub.pl";



my ($I,
    $J) =  parse_argv(@ARGV);



my ($NONs,			# node object names (@TEMPLATE.glm)
    $smi);			# sparse matrix index

open(my $fh_s2n, '<', 'smi2non.csv') || die "$!";
my $head = <$fh_s2n>;

while (<$fh_s2n>) {
	my ($smi0,
	    $smi1,
	    $non)  = cut_string($_, ",");
	my @indices = ($smi0 .. $smi1);
	foreach my $i (@indices) {
		$NONs->[$i] = $non; # many-to-one
	}
	$smi->{$non} = [@indices]; # one-to-many
}
close($fh_s2n);



# To understand the contents and structure of GridLab-D's "Y-Bus" matrix, please read the following paper:
# "Three-phase power flow calculations using the current injection method," by Garcia et al. [2000], DOI:10.1109/59.867133.



my ($ybus);

$head = <STDIN>;
while (<STDIN>) {
	my ($i,
	    $j,
	    $value) = cut_string($_, ",");
	$ybus->[$i]->[$j] = $value;
}



push my @smii, @{$smi->{$I}};
push my @smij, @{$smi->{$J}};



foreach my $i (@smii) {
	my @row;
	foreach my $j (@smij) {
		push @row, $ybus->[$i]->[$j];
	}
	print join(',', @row), "\n";
}



sub parse_argv {
	my ($I,
	    $J);
	while (my $arg = shift) {
		if ($arg eq '-i') {
			$I = shift;
		} elsif ($arg eq '-j') {
			$J = shift;
		} else {
		}
	}
	if (!$I || !$J) {
		print "USAGE: perl $0 -i I -j J\n";
		exit -1;
	}
	return($I,
	       $J);	
}
