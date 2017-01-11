use strict;
use warnings;

require "$ENV{HOME}/iDGA/pl/subhub.pl";



open(my $fh_tsjoin, '>', "./TSJ.CSV") || die "$!";
print $fh_tsjoin "name,local_time,mA,aA,mB,aB,mC,aC\n";

my @names     = ();
my $M         = {};
my $invalid_1 = {};
my $invalid_2 = {};

foreach my $file (glob("*.csv")) {
	print "$file\n";
	
	open(my $fh_tsmake, '<', "$file") || die "$!";
	my $head = <$fh_tsmake>;
	
	$file =~ s/.csv$//aa;
	push @names, $file;
		
	while (<$fh_tsmake>) {
		my ($dt,
		    @data) = cut_string($_, ",");
		$dt = timestamp_nonNstrip($dt);
		
		if (@data == 0) {
			$invalid_1->{$dt} += 1;
		} else {
			$M->{$dt}->{$file} = sprintf('%.1f',
						     mean_numlist(($data[0],
								   $data[2],
								   $data[4])));
			$invalid_2->{$file} += 1;
		}
		
		print $fh_tsjoin "$file,$_";
	}
	close($fh_tsmake);
}
close($fh_tsjoin);



@names = sort { $a <=> $b } grep { $invalid_2->{$_} > 0 } @names;

open(my $fh_svd, '>', "./SVD.CSV") || die "$!";
print $fh_svd join(',', @names), "\n";

foreach my $dt (sort { $a <=> $b } keys %$M) {
	if ($invalid_1->{$dt} != ($#names + 1)) {
		my $prelude;
		my $tis_the_beginning = 1;
			
		foreach my $name (@names) {
			if ($tis_the_beginning) {
				$tis_the_beginning = 0;
			} else {
				$prelude = ",";
			}
			print $fh_svd "$prelude$M->{$dt}->{$name}";
		}
		print $fh_svd "\n";
	}
}
close($fh_svd);
