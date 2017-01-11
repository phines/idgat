# pbexec ~/iDGA/pl/etc/ampEx.pl "/home/pavan/tmp/gld/gmp/78g1/run_2015-july-1st-31st_xfo-to-load-direct" < ./i-mean.csv 2> .err.log

use strict;
use warnings;

require "$ENV{HOME}/iDGA/pl/subhub.pl";



my $rundir = $ARGV[0] || exit -1;



my ($I, $J, $K) = (0, 2, 4); # i-mean.csv: (0, 2, 4); TSJ.CSV: (1, 3, 5)



my %ampacity;

open(my $fh_eiamp, '<', "$rundir/ei-amp.csv") || die "$!";
my $header = <$fh_eiamp>;

while (<$fh_eiamp>) {
	my ($ei, $amp) = cut_string($_, ",");
	$ampacity{$ei} = $amp;
}
close($fh_eiamp);



my $cid = {};

open(my $fh_links, '<', "$rundir/links.csv") || die "$!";
$header = <$fh_links>;

while (<$fh_links>) {
	my ($link, @data) = cut_string($_, ",");
	$cid->{$link}->{a} = $data[6];
	$cid->{$link}->{b} = $data[7];
	$cid->{$link}->{c} = $data[8];
	$cid->{$link}->{n} = $data[9];
}
close($fh_links);



open(my $fh_ampex, '>', './ampex.csv')     || die "$!";
print $fh_ampex "name,a,b,c\n";

$header = <STDIN>;

while (<STDIN>) {
	my ($link, @data) = cut_string($_, ",");
	my ($ratio_a, $ratio_b, $ratio_c);
	if ($data[$I] && ($data[$I] ne 'NA')) { # Phase-A: Magnitude
		$ratio_a = sprintf("%.3f", $data[$I] / $ampacity{$cid->{$link}->{a}}) if (exists $ampacity{$cid->{$link}->{a}});
	}
	if ($data[$J] && ($data[$J] ne 'NA')) { # Phase-B: Magnitude
		$ratio_b = sprintf("%.3f", $data[$J] / $ampacity{$cid->{$link}->{b}}) if (exists $ampacity{$cid->{$link}->{b}});
	}
	if ($data[$K] && ($data[$K] ne 'NA')) { # Phase-C: Magnitude
		$ratio_c = sprintf("%.3f", $data[$K] / $ampacity{$cid->{$link}->{c}}) if (exists $ampacity{$cid->{$link}->{c}});
	}
	printf $fh_ampex "$link,$ratio_a,$ratio_b,$ratio_c\n";
}

close($fh_ampex);
