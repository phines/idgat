use strict;
use warnings;
use DBI;
use Math::Trig qw(:pi);



# Fetches specified columns from a MySQL table:
sub mysql_fetch {
	my ($dbref,		# \$DB
	    $table,		# Table
	    $cref		# List of Columns [reference]
	   ) = @_;
	my $columns = join(', ', @$cref);
	my $q       = $$dbref->prepare("select $columns from $table;");
	$q->execute();
	my $ar    = $q->fetchall_arrayref;
	$q->finish();
	return ($ar); # Reference to an array of references (each of which, in turn, points to an array).
}



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
	return(grep { !$h{$_}++ } @a); # got it?
}



# Decomposes a string into its characters:
sub characterize_string {
	my ($s) = @_;		# String
	my @c;
	foreach (my $i = 0; $i < length $s; $i++) {
		push @c, substr($s, $i, 1);
	}
	return (@c);
}



# Combines unique characters from a string into a new string:
sub unique_characters {
	my ($s) = @_;		# String
	return (join('', sort(unique_elements(characterize_string($s)))));
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



# Writes a list in a comma-separated format (to STDOUT):
sub write_list {
	my ($ar,		# Array [reference]
	    $label		# Label
	   ) = @_;
	print STDOUT "$label:\n" if ($label);
	print STDOUT "$_, " foreach (@$ar);
	print STDOUT "\n";
}



# Returns the greater of two numbers:
sub the_greater_of {
	my ($a,
	    $b) = @_;
	return($a > $b ? $a : $b);
}



# Computes the area of a circle given its diameter:
sub area_circle {
	my ($d) = @_;
	return(pi / 4 * $d**2);
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



# Parses @ARGV for main.pl:
sub parse_argv {
	my ($db_equipment,
	    $db_network,
	    $feeder_netid,
	    $infinite_bus,
	    $use_transformers,
	    $secondary_details);
	while (my $arg = shift) {
		if ($arg eq '-e') {
			$db_equipment = shift;
		} elsif ($arg eq '-n') {
			$db_network = shift;
		} elsif ($arg eq '-f') {
			$feeder_netid = shift;
		} elsif ($arg eq '-i') {
			$infinite_bus = shift;
		} elsif ($arg eq '-T') {
			$use_transformers = 1;
		} elsif ($arg eq '-S') {
			$secondary_details = 1;
		} else {
		}
	}
	if (!$db_equipment || !$db_network || !$feeder_netid || !$infinite_bus) {
		instructions_on_how_to_run_this_script();
		exit 0;
	}
	return ($db_equipment,
		$db_network,
		$feeder_netid,
		$infinite_bus,
		$use_transformers,
		$secondary_details);
	
}



sub instructions_on_how_to_run_this_script {
	print STDOUT "\n\n\n";
	print STDOUT "USAGE: perl $0 -e db_equipment -n db_network -f feeder_netid -i infinite_bus [-T] [-S]\n";
	print STDOUT "\tdb_equipment and db_network are the equipment and network databases (MySQL)\n"; 
	print STDOUT "\t\tfor the circuit (feeder) of interest.\n";
	print STDOUT "\tfeeder_netid is the NetworkId of the feeder of interest.\n"; 
	print STDOUT "\tinfinite_bus is the NodeId of the infinite bus for the above feeder.\n"; 
	print STDOUT "\t-T flag: Transformers from the equipment database are used (with a few modifications).\n";
	print STDOUT "\t\t(Otherwise, they are created on the fly,\n";
	print STDOUT "\t\t based on the 'ConnectedKVA' and 'phases' w/r/t the 'DeviceNumber'.)\n";
	print STDOUT "\t-S flag: Secondary Details?\n";
	print STDOUT "\tNote that the flags may be specified in any order.\n";
	print STDOUT "\n\n\n";
	print STDOUT "pbexec $0 -e gmp_78g1_rob_equ -n gmp_78g1_rob_net -f 78G1 -i SOURCE_78G1 2> .err.log | tee cymd2gld.log\n";
	print STDOUT "\n\n\n";
}





##############################DO NOT TOUCH##################################
1; # To "require" this file in another, a truthy value needs to be returned.
############################################################################
