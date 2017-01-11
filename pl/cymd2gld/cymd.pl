use strict;
use warnings;



our $script_directory;
require "$script_directory/our.pl";





# CYMD: Process table CYMNODE:
sub cymd_node {
	my ($obj_db,	   # \$obj_db_network
	    $table,	   # Table
	    $columns,	   # List of Columns [reference]
	    $feeder_netid  # The "NetworkId" of the feeder of interest
	   ) = @_;
	my (@nodes,
	    %x,
	    %y);
	push @$columns, 'NetworkId';
	write_list($columns, $table);
	foreach my $ar (@{mysql_fetch($obj_db,
				      $table,
				      $columns)}) {
		if ($ar->[-1] eq $feeder_netid) {
			push @nodes,   $ar->[0];
			$x{$ar->[0]} = $ar->[1];
			$y{$ar->[0]} = $ar->[2];
			write_list($ar);
		}
	}
	return(\@nodes,
	       \%x,
	       \%y);
}



our %LOOKUP_TABLE_PHASES;



# CYMD: Process table CYMSECTION:
sub cymd_section {
	my ($obj_db,	   # \$obj_db_network
	    $table,	   # Table
	    $columns,	   # List of Columns [reference]
	    $feeder_netid  # The "NetworkId" of the feeder of interest
	   ) = @_;
	my (%from_node,
	    %to_node,
	    %link_phases,
	    @links);
	push @$columns, 'NetworkId';
	write_list($columns, $table);
	foreach my $ar (@{mysql_fetch($obj_db,
				      $table,
				      $columns)}) {
		if ($ar->[-1] eq $feeder_netid) {
			my $si            = $ar->[0];
			my $from          = $ar->[1];
			my $to            = $ar->[2];
			my $phase         = $LOOKUP_TABLE_PHASES{$ar->[3]};
			$from_node{$si}   = $from;
			$to_node{$si}     = $to;
			$link_phases{$si} = $phase;
			push @links,        $si;
			write_list($ar);
		}
	}
	return(\%from_node,
	       \%to_node,
	       \%link_phases,
	       \@links);
}



our %DEVICE_TYPE;



# CYMD: Process table CYMSECTIONDEVICE:
sub cymd_section_device {
	my ($obj_db,	   # \$obj_db_network
	    $table,	   # Table
	    $columns,	   # List of Columns [reference]
	    $feeder_netid  # The "NetworkId" of the feeder of interest
	   ) = @_;
	my (@xfo_links,
	    @pol2xfo_links,
	    @switch_links,
	    %load_device_numbers,
	    %switch_device_numbers);
	push @$columns, 'NetworkId';
	write_list($columns, $table);
	open(my $dts, '>', './dts-ignored.log') || die "$!";
	foreach my $ar (@{mysql_fetch($obj_db,
				      $table,
				      $columns)}) {
		if ($ar->[-1] eq $feeder_netid) {
			my $si = $ar->[0];
			my $dt = $ar->[1];
			my $dn = $ar->[2];
			if (($dt eq $DEVICE_TYPE{spot_load}) || ($dt eq $DEVICE_TYPE{distributed_load})) {
				$load_device_numbers{$si} = $dn; # The DN of the transformer and load are almost always identical.
				push @xfo_links,            $si; # The true transformer link is the one from xfo->load, not pole->xfo, as labeled.
			} elsif ($dt eq $DEVICE_TYPE{transformer}) {
				push @pol2xfo_links,        $si;
			} elsif ($dt eq $DEVICE_TYPE{switch}) {
				push @switch_links,         $si;
				$switch_device_numbers{$si} = $dn;
			} elsif ($dt eq $DEVICE_TYPE{overhead_line_conductor} || $dt eq $DEVICE_TYPE{underground_line_conductor}) {
				# Handled elsewhere.
			} else {
				print $dts "At SI $si: Ignored DT $dt.\n";
			}
			write_list($ar);
		}
	}
	return(\@xfo_links,
	       \@pol2xfo_links,
	       \@switch_links,
	       \%load_device_numbers,
	       \%switch_device_numbers);
}



our %UNITS;



# CYMD: Process table CYMOVERHEADBYPHASE:
sub cymd_overhead_by_phase {
	my ($obj_db,	   # \$obj_db_network
	    $table,	   # Table
	    $columns,	   # List of Columns [reference]
	    $feeder_netid  # The "NetworkId" of the feeder of interest
	   ) = @_;
	my (%ohl_id_conductor_a,
	    %ohl_id_conductor_b,
	    %ohl_id_conductor_c,
	    %ohl_id_conductor_n,
	    %ohl_length,
	    @ohl_conductor_equId,
	    @ohl_links);
	push @$columns, 'NetworkId';
	write_list($columns, $table);
	foreach my $ar (@{mysql_fetch($obj_db,
				      $table,
				      $columns)}) {
		if ($ar->[-1] eq $feeder_netid) {
			my $dn                   = $ar->[0];
			$ohl_id_conductor_a{$dn} = $ar->[1];
			$ohl_id_conductor_b{$dn} = $ar->[2];
			$ohl_id_conductor_c{$dn} = $ar->[3];
			$ohl_id_conductor_n{$dn} = $ar->[4];
			$ohl_length{$dn}   = sprintf('%.2f', $ar->[5] * $UNITS{'m_ft'});
			# Save the EquipmentIds of all the phase/neutral conductors (and resolve duplicates later):
			push @ohl_conductor_equId, $ohl_id_conductor_a{$dn};
			push @ohl_conductor_equId, $ohl_id_conductor_b{$dn};
			push @ohl_conductor_equId, $ohl_id_conductor_c{$dn};
			push @ohl_conductor_equId, $ohl_id_conductor_n{$dn};
			push @ohl_links,           $dn;
			write_list($ar);
		}
	}
	return(\%ohl_id_conductor_a,
	       \%ohl_id_conductor_b,
	       \%ohl_id_conductor_c,
	       \%ohl_id_conductor_n,
	       \%ohl_length,
	       \@ohl_conductor_equId,
	       \@ohl_links);
}



# CYMD: Process table CYMUNDERGROUNDLINE:
sub cymd_underground_line {
	my ($obj_db,	   # \$obj_db_network
	    $table,	   # Table
	    $columns,	   # List of Columns [reference]
	    $feeder_netid  # The "NetworkId" of the feeder of interest
	   ) = @_;
	my (%ugl_conductor_caId,
	    %ugl_length,
	    @ugl_links);
	push @$columns, 'NetworkId';
	write_list($columns, $table);
	foreach my $ar (@{mysql_fetch($obj_db,
				      $table,
				      $columns)}) {
		if ($ar->[-1] eq $feeder_netid) {
			my $dn                   = $ar->[0];
			$ugl_conductor_caId{$dn} = $ar->[1];
			$ugl_length{$dn}         = sprintf('%.2f', $ar->[2] * $UNITS{'m_ft'});
			push @ugl_links,           $dn;
			write_list($ar);
		}
	}
	return(\%ugl_conductor_caId,
	       \%ugl_length,
	       \@ugl_links);
}



# CYMD: Process table CYMSWITCH:
sub cymd_network_switch {
	my ($obj_db,	   # \$obj_db_network
	    $table,	   # Table
	    $columns,	   # List of Columns [reference]
	    $feeder_netid  # The "NetworkId" of the feeder of interest
	   ) = @_;
	my (%switch_status);
	push @$columns, 'NetworkId';
	write_list($columns, $table);
	foreach my $ar (@{mysql_fetch($obj_db,
				      $table,
				      $columns)}) {
		if ($ar->[-1] eq $feeder_netid) {
			my $device_number =  $ar->[0];
			my $status        =  $ar->[1];
			if ($status == 1) {
				$switch_status{$device_number} =  'CLOSED';
			} elsif ($status == 0) {
				$switch_status{$device_number} =  'OPEN';
			} else {
				print STDOUT "ERROR: Switch: DN $device_number: Unknown 'NormalStatus' $status.\n";
			}
			write_list($ar);
		}
	}
	return(\%switch_status);
}



our $UTILITY_ID;



# CYMD: Process table CYMTRANSFORMER:
sub cymd_network_transformer {
	my ($obj_db,	   # \$obj_db_network
	    $table,	   # Table
	    $columns,	   # List of Columns [reference]
	    $feeder_netid  # The "NetworkId" of the feeder of interest
	   ) = @_;
	my (%xfo_equId);
	push @$columns, 'NetworkId';
	write_list($columns, $table);
	foreach my $ar (@{mysql_fetch($obj_db,
				      $table,
				      $columns)}) {
		if ($ar->[-1] eq $feeder_netid) {
			my $device_number          =  $ar->[0];
			$device_number             =~ s/XFO/L/aa if ($UTILITY_ID eq 'GMP'); # Map the transformer's DN to that of the corresponding load.
			$xfo_equId{$device_number} =  $ar->[1];
			write_list($ar);
		}
	}
	return(\%xfo_equId);
}



our %CYMD_LOAD_VALUE_TYPE;
our $CYMD_DISTRIBUTED_LOAD;



# CYMD: Process table CYMCUSTOMERLOAD:
sub cymd_customer_load {
	my ($obj_db,	   # \$obj_db_network
	    $table,	   # Table
	    $columns,	   # List of Columns [reference]
	    $feeder_netid  # The "NetworkId" of the feeder of interest
	   ) = @_;
	my ($dn,
	    $kva_sum,
	    @cn,
	    @ccId,
	    %load_W_a,
	    %load_W_b,
	    %load_W_c,
	    %load_VAR_a,
	    %load_VAR_b,
	    %load_VAR_c,
	    %connected_kva);
	push @$columns, 'NetworkId';
	write_list($columns, $table);
	open(my $dncn,  '>', './cn-dn.csv')  || die "$!";
	open(my $dnrci, '>', './dn-rci.csv') || die "$!";
	print $dncn  "cn,dn\n";
	print $dnrci "dn,type\n";
	foreach my $ar (@{mysql_fetch($obj_db,
				      $table,
				      $columns)}) {
		if ($ar->[-1] eq $feeder_netid) {
			if ($dn ne $ar->[0]) { # Multiple customers are behind the same DeviceNumber, so this signals the change.
				if ($dn && (@cn   != 0)) {
					my @ucn = unique_elements(@cn);
					print $dncn "$_,$dn\n" foreach (@ucn);
				}
				if ($dn && (@ccId != 0)) {
					my $cucjccId = unique_characters(join('', @ccId));
					print $dnrci "$dn,$cucjccId\n";
				}
				$connected_kva{$dn} = $kva_sum;
				@cn                 = ();
				@ccId               = ();
				$kva_sum            = 0;
				$dn                 = $ar->[0];
			}
			my ($kw, $kvar);
			if ($ar->[4] eq $CYMD_LOAD_VALUE_TYPE{KW_KVAR}) {
				$kw   = $ar->[6];
				$kvar = $ar->[7];
			} elsif ($ar->[4] eq $CYMD_LOAD_VALUE_TYPE{KVA_PF}) {
				my $pf = $ar->[7] / 100; # /100 converts a Percent to a Fraction.
				$kw    = $ar->[6] * $pf;
				$kvar  = $ar->[6] * sqrt(1 - $pf**2);
				if ($pf < 0) {
					$kw   *= -1;
					$kvar *= -1;
				}
			} elsif ($ar->[4] eq $CYMD_LOAD_VALUE_TYPE{KW_PF}) {
				my $pf = $ar->[7] / 100;
				$kw    = $ar->[6];
				if ($pf > 0) {
					$kvar = ($ar->[6] / $pf) * sqrt(1 - $pf**2);
				} else {
					$kvar = 0;
				}
			}
			if ($kw && $kvar) {
				my $w   = $kw   * 1000;
				my $var = $kvar * 1000;
				if ($ar->[5] eq 1) {
					$load_W_a{$dn}   += $w;
					$load_VAR_a{$dn} += $var;
				} elsif ($ar->[5] eq 2) {
					$load_W_b{$dn}   += $w;
					$load_VAR_b{$dn} += $var;
				} elsif ($ar->[5] eq 3) {
					$load_W_c{$dn}   += $w;
					$load_VAR_c{$dn} += $var;
				}
			}
			push @cn,          $ar->[1];
			push @ccId, substr($ar->[2], 0, 1);
			$kva_sum +=        $ar->[8];
			print STDOUT "At DN $dn, CN $ar->[1]: DT = $CYMD_DISTRIBUTED_LOAD" if ($ar->[3] eq $CYMD_DISTRIBUTED_LOAD);
			write_list($ar);
		}
	}
	return(\%load_W_a,
	       \%load_W_b,
	       \%load_W_c,
	       \%load_VAR_a,
	       \%load_VAR_b,
	       \%load_VAR_c,
	       \%connected_kva);
}



# CYMD: Process table CYMEQCONDUCTOR:
sub cymd_equipment_conductor {
	my ($obj_db,		# \$obj_db_equipment
	    $table,		# Table
	    $columns		# List of Columns [reference]
	   ) = @_;
	my (%ohl_conductor_diameter,
	    %ohl_conductor_GMR,
	    %ohl_conductor_R25);
	write_list($columns, $table);
	open(my $ohl_dgr25, '>', './ohl-dia-gmr-r25.glm') || die "$!";
	open(my $ei_amp,    '>', './ei-amp.csv')          || die "$!";
	print $ei_amp "equid,ampacity\n";
	foreach my $ar (@{mysql_fetch($obj_db,
				      $table,
				      $columns)}) {
		my $ei                       = $ar->[0];
		$ohl_conductor_diameter{$ei} = sprintf('%.5f', $ar->[1]);
		$ohl_conductor_GMR{$ei}      = sprintf('%.5f', $ar->[2] * $UNITS{'in_ft'});
		$ohl_conductor_R25{$ei}      = sprintf('%.5f', $ar->[3] * $UNITS{'by1000ft_by1mile'});
		write_list($ar);
		# The equipment IDs from this table do not match exactly those from CYMOVERHEADBYPHASE.
		# So, let us save these (to ./ohl-dia-gmr-r25.glm) as overhead_line_conductor objects,
		# which we can then manually inspect.
		print $ohl_dgr25 "// CYMEQCONDUCTOR EquipmentId => $ei\n";
		print $ohl_dgr25 "object overhead_line_conductor {\n";
		print $ohl_dgr25 "\tdiameter              $ohl_conductor_diameter{$ei};\n";
		print $ohl_dgr25 "\tgeometric_mean_radius $ohl_conductor_GMR{$ei};\n";			
		print $ohl_dgr25 "\tresistance            $ohl_conductor_R25{$ei};\n}\n\n";
		# Save also their "FirstRating" (ampacity):
		print $ei_amp "$ei,$ar->[4]\n";
	}
	return(\%ohl_conductor_diameter,
	       \%ohl_conductor_GMR,
	       \%ohl_conductor_R25);
}



# CYMD: Process table CYMEQTRANSFORMER:
sub cymd_equipment_transformer {
	my ($obj_db,		# \$obj_db_equipment
	    $table,		# Table
	    $columns		# List of Columns [reference]
	   ) = @_;
	my (%xfo_rating,
	    %xfo_transformer_connection,
	    %xfo_voltage_primary,
	    %xfo_voltage_secondary,
	    %xfo_impedance);
	write_list($columns, $table);
	foreach my $ar (@{mysql_fetch($obj_db,
				      $table,
				      $columns)}) {
		my $ei                           = $ar->[0];
		$xfo_rating{$ei}                 = $ar->[1];
		$xfo_transformer_connection{$ei} = $ar->[2];
		$xfo_voltage_primary{$ei}        = $ar->[3] * 1000; # *1000 converts Kilo[Unit] to [Unit]
		$xfo_voltage_secondary{$ei}      = $ar->[4] * 1000;
		my $psip                         = $ar->[5];
		my $xrr                          = $ar->[6];
		if ($psip && $xrr) {
			# Impedance ($Z) Calculation:
			# For this I am going to use "PosSeqImpedancePercent" ($psip = $ar->[5]) & "XRRatio" ($xrr = $ar->[6]).
			# Say:
			# $R    = Resistance
			# $X    = Reactance
			# Now:
			# $Z**2 = $R**2 + $X**2
			# $eta  = $X / $R
			# So:
			# $R    = $Z / sqrt(1 + $eta**2)
			# $X    = $eta * $R
			# Now:
			# $Z    = $psip / 100 [per unit of the transformer KVA: Ohm; the /100 is because it's specified as a %]
			# $eta  = $xrr
			# So:
			# $R    = ($psip / 100) / sqrt(1 + $xrr**2)
			# $X    = $xrr * $R
			# $Z    = $R + ${X}j
			my $R = sprintf('%.5f', ($psip / 100) / sqrt(1 + $xrr**2));
			my $X = sprintf('%.5f', $xrr * $R);
			$xfo_impedance{$ei} = "${R}+${X}j";
		}
		write_list($ar);
	}
	return(\%xfo_rating,
	       \%xfo_transformer_connection,
	       \%xfo_voltage_primary,
	       \%xfo_voltage_secondary,
	       \%xfo_impedance);
}





##############################DO NOT TOUCH##################################
1; # To "require" this file in another, a truthy value needs to be returned.
############################################################################
