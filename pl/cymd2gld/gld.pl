use strict;
use warnings;
use Math::Trig qw(:pi);
use POSIX qw(ceil);



our $script_directory;
require "$script_directory/our.pl";





# CORE: Redraws the graph, removing, if present, OPEN switch links etc.:
sub redraw_graph {
	my ($ohl_links,
	    $ugl_links,
	    $xfo_links,
	    $pol2xfo_links,
	    $switch_links,
	    $from_node,
	    $to_node,
	    $link_phases,
	    $switch_device_numbers,
	    $switch_status,
	    $load_device_numbers,
	    $infinite_bus,
	    $x,
	    $y
	   ) = @_;
	my (@Nodes,
	    %gate2secy,
	    %node_phases,
	    %dn_load,
	    %nodify,
	    %linkify,
	    %it_is_ohl_ugl);
	push my @Links,
	  @$ohl_links,
	  @$ugl_links,
	  @$xfo_links;		# The principal links
	#0. By default:
	#a. Linkify principal links:
	foreach my $l (@Links) {
		$linkify{$l} = 1;
	}
	#b. Nodify nodes belonging to ohl/ugl links:
	foreach my $l (@$ohl_links,
		       @$ugl_links
		      ) {
		$it_is_ohl_ugl{$l}        = 1;
		$nodify{$from_node->{$l}} = 1 if (!exists $nodify{$from_node->{$l}});
		$nodify{$to_node->{$l}}   = 1 if (!exists $nodify{$to_node->{$l}});
		push @Nodes,
		  $from_node->{$l},
		  $to_node->{$l};
	}
	#c. Nodify loads (i.e. "to" nodes of xfo links):
	# (NOTE: to be precise, the "to" node of an xfo-link is not a load
	#        but a fabricated node that's connected to a meter,
	#        which is attached to a load [as a child-node of the meter]).
	foreach my $l (@$xfo_links) {
		$nodify{$to_node->{$l}}  = 1;
		$dn_load{$to_node->{$l}} = $load_device_numbers->{$l};
		push @Nodes,
		  $to_node->{$l};
	}
	@Nodes = unique_elements(@Nodes);
	print STDOUT "\n\n\n";
	#1. Delete open switch links:
	foreach my $l (@$switch_links) {
		if ($switch_status->{$switch_device_numbers->{$l}} eq 'OPEN') {
			$linkify{$l} = 0;
			print STDOUT "DELETION: SectionId $l: Reason: Switch DN $switch_device_numbers->{$l} OPEN.\n";
		}
	}
	print STDOUT "\n\n\n";
	#2. Delete transformer nodes, and connect poles directly to loads:
	foreach my $L (@$xfo_links) {
		$gate2secy{$to_node->{$L}} = 1;
		$nodify{$from_node->{$L}}                 = 0;
	      FIND_CORRESPONDING_POL2XFO_LINK: {
			foreach my $l (@$pol2xfo_links) {
				if ($to_node->{$l} eq $from_node->{$L}) {
					$from_node->{$L} = $from_node->{$l};
					# For legible circuit diagrams in D3:
					($x->{$to_node->{$L}},
					 $y->{$to_node->{$L}}) = move_load_away_from_pole($x->{$from_node->{$L}},
											  $y->{$from_node->{$L}},
											  $x->{$to_node->{$L}},
											  $y->{$to_node->{$L}},
											  5);
					last FIND_CORRESPONDING_POL2XFO_LINK;
				}
			}
		}	
	}
	#3. Graph Integrity:
	#a. Account for nodes that are present more than once on the *to* end of a link,
	#   as they invariably send GridLab-D (NR and FBS solvers) into a divergent loop.
	#   So fabricate 2/3 nodes ($#tos) in place of the original, and redraw the graph accordingly.
	print STDOUT "\n\n\n";
	my ($frsects,
	    $tosects) = from_to_of_links(\@Links,
					 \%linkify,
					 $from_node,
					 $to_node);
	my @NewN;
	foreach my $n (@Nodes) {
		if ($nodify{$n} && !$gate2secy{$n} && ($n ne $infinite_bus)) {
			my @frs = cut_string($frsects->{$n}, '___');
			my @tos = cut_string($tosects->{$n}, '___');
			if (@tos > 1) {
				$nodify{$n} = 0;
				my $newn;
				foreach my $t (@tos) {
					$newn              = "${n}__$link_phases->{$t}";
					$to_node->{$t}     = $newn;
					push @NewN,          $newn;
					$x->{$newn}        = $x->{$n};
					$y->{$newn}        = $y->{$n};
					$nodify{$newn}     = 1;
					print STDOUT "INSERTION: Node $n: $newn: Reason: TOS > 1.\n";
				}
				foreach my $f (@frs) {
					$from_node->{$f}   = "${n}__$link_phases->{$f}";
				}
			}
		}
	}
	push @Nodes, @NewN;
	print STDOUT "\n\n\n";
	#b. Delete (non-swing/load) nodes that are not truly connected to the rest of the graph:
	#   (There has got to be a more elegant, recursive way of doing this!)
	my ($i, $j) = (0, 1);
	until (!$j) {
		print STDOUT "\n\n\nredraw_graph(): Step 3b: Pass $i.\n\n\n";
		($frsects,
		 $tosects) = from_to_of_links(\@Links,
					      \%linkify,
					      $from_node,
					      $to_node);
		$j = 0;
		foreach my $n (@Nodes) {
			if ($nodify{$n} && !$gate2secy{$n} && ($n ne $infinite_bus)) {
				my @frs = cut_string($frsects->{$n}, '___');
				my @tos = cut_string($tosects->{$n}, '___');
				if (@frs == 0 || @tos == 0) {
					$j++;
					print STDOUT "DELETION: Node $n: Reason: '#frs'=$#frs; '#tos'=$#tos.\n";
					$nodify{$n} = 0;
					foreach my $l (@frs,
						       @tos
						      ) {
						$linkify{$l} = 0;
						print STDOUT "DELETION: SectionId $l: Reason: Above.\n";
					}
				}
			}
		}
		$i++;
	}
	print STDOUT "\n\n\n";
	#c. Delete disconnected loads:
	foreach my $l (@$xfo_links) {
		if (!$nodify{$from_node->{$l}}) {
			$nodify{$to_node->{$l}} = 0;
			print STDOUT "DELETION: Load $to_node->{$l}: Disconnected.\n";
			# (The link has already been deleted in #3b.)
		}
	}
	#4. Infer node "phases":
	foreach my $l (@Links) {
		if ($linkify{$l}) {
			my $phases                      = $link_phases->{$l};
			$node_phases{$from_node->{$l}} .= "$phases";
			$node_phases{$to_node->{$l}}   .= "$phases";
		}
	}
	foreach my $n (@Nodes) {
		$node_phases{$n} = unique_characters($node_phases{$n}) if ($nodify{$n}); # e.g AN.BN.ABCN.ABCN -> ABCN
	}
	return(\@Nodes,
	       \%gate2secy,
	       \%node_phases,
	       \%dn_load,
	       \%nodify,
	       \%linkify,
	       \%it_is_ohl_ugl);
}



# GridLab-D Model: header:
sub glm_header {
	my ($glm) = @_;
	print $glm "clock {\n";
	print $glm "\ttimezone  I__TZ;\n";
	print $glm "\tstarttime 'I__T0';\n";
	print $glm "\tstoptime  'I__T1';\n";
	print $glm "}\n\n\n\n";
	print $glm "#set relax_naming_rules=1;\n\n\n\n";
	print $glm "#set iteration_limit=6;\n\n\n\n";
	print $glm "module powerflow {\n";
	print $glm "\tsolver_method I__SM;\n";
	print $glm "}\n\n\n\n";
	print $glm "module tape;\n\n\n\n";
}



# GridLab-D Model: object: group_recorder:
sub objectify_group_recorder {
	my ($glm,
	    $class,		# e.g. "underground_line"
	    $property,
	    $complex_part, # "NONE" | "REAL" | "IMAG" | "MAG" | "ANG_DEG" | "ANG_RAD"
	    $interval	   # seconds
	   ) = @_;
	my $file = "${class}_${property}_${complex_part}.csv";
	print $glm "object group_recorder {\n";
	print $glm "\tfile         $file;\n";
	print $glm "\tgroup        \"class=$class\";\n";
	print $glm "\tproperty     $property;\n";
	print $glm "\tcomplex_part $complex_part;\n";
	print $glm "\tinterval     $interval; // Seconds\n" if ($interval);
	print $glm "}\n\n";
}



# GridLab-D Model: object: player:
sub objectify_player {
	my ($glm,
	    $property,
	    $file,		# .csv
	    $loop		# #
	   ) = @_;
	print $glm "\tobject player {\n";
	print $glm "\t\tfile     $file;\n";
	print $glm "\t\tproperty $property;\n";
	print $glm "\t\tloop     $loop;\n" if ($loop);
	print $glm "\t};\n";
}



our %UNDERGROUND_CABLE_DATABASE;
our %iPHASES;
our $UG_CABLE_FOR_2AND3PHASE_LOADS;
our $NOMINAL_VOLTAGE_PRIMARY;
our $NOMINAL_VOLTAGE_SECONDARY;
our $TRIPLEX_LINE_LENGTH;
our $iUGLCND;
our $iUGLSPG;
our $iSECGAT;
our $iSG2MET;
our $iMETER;
our $iTLCCFG;
our $iSG2MCFG;
our $iLOAD;



# GridLab-D Model: object: node / triplex_node / load / meter / triplex_meter:
sub objectify_nodes {
	my ($glm,
	    $nodify,
	    $Nodes,
	    $gate2secy,
	    $node_phases,
	    $infinite_bus,
	    $dn_load,
	    $secondary_details
	   ) = @_;
	open(my $dnph,   '>', './dn-ph.csv')  || die "$!";
	open(my $dnnon,  '>', './dn-non.csv') || die "$!";
	print $dnph  "dn,ph\n";
	print $dnnon "dn,non\n";
	my $iok  = index_of_key(\%UNDERGROUND_CABLE_DATABASE, $UG_CABLE_FOR_2AND3PHASE_LOADS); 
	my $ucon = $iUGLCND + $iok + 1;
	my $name1;
	my %property = ('A'   => 'constant_power_A',
			'B'   => 'constant_power_B',
			'C'   => 'constant_power_C',
			'1/2' => 'power_12');
	my $n = my $l = 1;
	foreach (my $i = 0; $i <= $#$Nodes; $i++) {
		if ($nodify->{$Nodes->[$i]}) {
			my $dn = $dn_load->{$Nodes->[$i]};
			my $phases = my $phases_ = $node_phases->{$Nodes->[$i]};
			$phases_ =~ s/N$//aa;
			my @phs = characterize_string($phases_); # default
			my $nominal_voltage = $NOMINAL_VOLTAGE_SECONDARY; # default
			my ($obj1,
			    $obj2, $name2,
			    $obj3, $name3,
			    $obj4, $name4,
			    $obj5, $name5);
			if ($gate2secy->{$Nodes->[$i]}) {
				$name1->{$Nodes->[$i]} = $iSECGAT + $l;
				if ($secondary_details) {
					$name2 = $iMETER  + $l;
					$name3 = $iLOAD   + $l;
					$name4 = $iSG2MET + $l;
					if ($phases_ eq 'A' || $phases_ eq 'B' || $phases_ eq 'C') {
						$phases          =~ s/N/S/aa; # e.g. 'AN' => 'AS', wherein S is GridLab-D's notation for "split-phase" 
						$nominal_voltage = ceil($NOMINAL_VOLTAGE_SECONDARY / 2);
						$obj1            = 'triplex_node';
						$obj2            = 'triplex_meter';
						$obj3            = 'triplex_node';
						$obj4            = 'triplex_line';
						$name5           = $iTLCCFG;
						push @phs, '1/2';
					} else { # (AB|BC|AC)N; ABCN
						$obj1  = 'node';
						$obj2  = 'meter';
						$obj3  = 'load';
						$obj4  = 'underground_line';
						$obj5  = 'line_configuration';
						$name5 = $iSG2MCFG + $l;
					}
				} else {
					$obj1 = 'load';
				}
				$l++;
			} else {
				$name1->{$Nodes->[$i]} = $n++;
				$nominal_voltage       = $NOMINAL_VOLTAGE_PRIMARY;
				$obj1                  = 'node';
			}
			print $glm "// NodeId: $Nodes->[$i]\n";
			print $glm "object $obj1 {\n";
			print $glm "\tname             $name1->{$Nodes->[$i]};\n";
			print $glm "\tbustype          SWING;\n" if ("$Nodes->[$i]" eq "$infinite_bus");
			print $glm "\tphases           $phases;\n";
			print $glm "\tnominal_voltage  $nominal_voltage; // Volts\n";
			if ($gate2secy->{$Nodes->[$i]} && !$secondary_details) {
				foreach my $ph (@phs) {
					objectify_player($glm,
							 $property{$ph},
							 "./l/inp_cp__${dn}__$ph.csv");
				}
			}
			print $glm "}\n\n";
			if ($gate2secy->{$Nodes->[$i]} && $secondary_details) {
				print $glm "object $obj4 {\n";
				print $glm "\tname             $name4;\n";
				print $glm "\tfrom             $name1->{$Nodes->[$i]};\n";
				print $glm "\tto               $name2;\n";
				print $glm "\tlength           $TRIPLEX_LINE_LENGTH; // feet\n";
				print $glm "\tphases           $phases;\n";
				print $glm "\tconfiguration    $name5;\n";
				print $glm "}\n\n";
				print $glm "object $obj2 {\n";
				print $glm "\tname             $name2;\n";
				print $glm "\tphases           $phases;\n";
				print $glm "\tnominal_voltage  $nominal_voltage; // Volts\n";
				print $glm "}\n\n";
				print $glm "object $obj3 {\n";
				print $glm "\tname             $name3;\n";
				print $glm "\tparent           $name2;\n";
				print $glm "\tphases           $phases;\n";
				print $glm "\tnominal_voltage  $nominal_voltage; // Volts\n";
				foreach my $ph (@phs) {
					my $p;
					if ($ph eq 'A' || $ph eq 'B' || $ph eq 'C') {
						$p = $ph;
					} else {
						$p = $phases_;
					}
					objectify_player($glm,
							 $property{$ph},
							 "./l/inp_cp__${dn}__$p.csv");
				}
				print $glm "}\n\n";
				if ($obj5) {
					my $name6 = $iUGLSPG + 1000 * $iok + $iPHASES{$phases};
					print $glm "object $obj5 {\n";
					print $glm "\tname          $name5;\n";
					print $glm "\tconductor_A   $ucon;\n" if ($phases =~ /A/);
					print $glm "\tconductor_B   $ucon;\n" if ($phases =~ /B/);
					print $glm "\tconductor_C   $ucon;\n" if ($phases =~ /C/);
					print $glm "\tconductor_N   $ucon;\n" if ($phases =~ /N/);
					print $glm "\tspacing       $name6;\n}\n\n";
				}
			}
			if ($dn) {
				print $dnph  "$dn,", join(',', characterize_string($phases)), "\n";
				print $dnnon "$dn,", $name1->{$Nodes->[$i]}, "\n";
			}
		}
	}
	return($name1);
}



our %IDMAP_OVERHEAD_CONDUCTOR;
our $iOHLCND;



# GridLab-D Model: object: overhead_line_conductor:
sub objectify_ohl_conductors {
	my ($glm,
	    $ohl_conductor_equId,
	    $ohl_conductor_diameter,
	    $ohl_conductor_GMR,
	    $ohl_conductor_R25
	   ) = @_;
	my $name;
	my $obj    = 'overhead_line_conductor';
	my @unique = unique_elements(@$ohl_conductor_equId);
	foreach (my $i = 0; $i <= $#unique; $i++) {
		$name->{$unique[$i]} = $iOHLCND + $i + 1;
		print $glm "// EquipmentId: $unique[$i]\n";
		my $ei;
		if ($ohl_conductor_diameter->{$unique[$i]}) {
			$ei = $unique[$i];
		} elsif ($IDMAP_OVERHEAD_CONDUCTOR{$unique[$i]}) {
			$ei = $IDMAP_OVERHEAD_CONDUCTOR{$unique[$i]};
		} else {
			$ei = $unique[$i];
			print STDOUT "ERROR: $obj: EI $unique[$i]\n";
		}
		print $glm "object $obj {\n";
		print $glm "\tname                  $name->{$unique[$i]};\n";
		print $glm "\tdiameter              $ohl_conductor_diameter->{$ei}; // inches\n";
		print $glm "\tgeometric_mean_radius $ohl_conductor_GMR->{$ei}; // feet\n";			
		print $glm "\tresistance            $ohl_conductor_R25->{$ei}; // Ohm/mile\n}\n\n";
	}
	return($name);
}



our $iOHL;
our $iOHLCFG;
our $iOHLSPG;



# GridLab-D Model: object: overhead_line / line_configuration:
sub objectify_ohl_configurations {
	my ($glm,
	    $linkify,
	    $ohl_links,
	    $nons,
	    $from_node,
	    $to_node,
	    $ocons,
	    $ohl_id_conductor_a,
	    $ohl_id_conductor_b,
	    $ohl_id_conductor_c,
	    $ohl_id_conductor_n,
	    $ohl_length,
	    $link_phases
	   ) = @_;
	my ($name1,
	    $cid_a,
	    $cid_b,
	    $cid_c,
	    $cid_n);
	my $obj1 = 'overhead_line';
	my $obj2 = 'line_configuration';
	my $obj3 = 'line_spacing';
	my $i    = 0;
	foreach my $l (@$ohl_links) {
		if ($linkify->{$l}) {
			$name1->{$l} = $iOHL    + $i + 1;
			my $name2    = $iOHLCFG + $i + 1;
			print $glm "// SectionId: $l\n";
			print $glm "object $obj1 {\n";
			print $glm "\tname          $name1->{$l};\n";
			print $glm "\tfrom          $nons->{$from_node->{$l}};\n";
			print $glm "\tto            $nons->{$to_node->{$l}};\n";
			print $glm "\tlength        $ohl_length->{$l}; // feet\n";
			print $glm "\tphases        $link_phases->{$l};\n";
			print $glm "\tconfiguration $name2;\n";
			print $glm "}\n\n";
			my $conductor_A;
			if ($ocons->{$ohl_id_conductor_a->{$l}}) {
				$conductor_A = $ocons->{$ohl_id_conductor_a->{$l}};
				$cid_a->{$l} = $ohl_id_conductor_a->{$l};
			} elsif ($ocons->{$IDMAP_OVERHEAD_CONDUCTOR{$ohl_id_conductor_a->{$l}}}) {
				$conductor_A = $ocons->{$IDMAP_OVERHEAD_CONDUCTOR{$ohl_id_conductor_a->{$l}}};
				$cid_a->{$l} = $IDMAP_OVERHEAD_CONDUCTOR{$ohl_id_conductor_a->{$l}};
			} else {
				$conductor_A = $ohl_id_conductor_a->{$l};
			}
			my $conductor_B;
			if ($ocons->{$ohl_id_conductor_b->{$l}}) {
				$conductor_B = $ocons->{$ohl_id_conductor_b->{$l}};
				$cid_b->{$l} = $ohl_id_conductor_b->{$l};
			} elsif ($ocons->{$IDMAP_OVERHEAD_CONDUCTOR{$ohl_id_conductor_b->{$l}}}) {
				$conductor_B = $ocons->{$IDMAP_OVERHEAD_CONDUCTOR{$ohl_id_conductor_b->{$l}}};
				$cid_b->{$l} = $IDMAP_OVERHEAD_CONDUCTOR{$ohl_id_conductor_b->{$l}};
			} else {
				$conductor_B = $ohl_id_conductor_b->{$l};
			}
			my $conductor_C;
			if ($ocons->{$ohl_id_conductor_c->{$l}}) {
				$conductor_C = $ocons->{$ohl_id_conductor_c->{$l}};
				$cid_c->{$l} = $ohl_id_conductor_c->{$l};
			} elsif ($ocons->{$IDMAP_OVERHEAD_CONDUCTOR{$ohl_id_conductor_c->{$l}}}) {
				$conductor_C = $ocons->{$IDMAP_OVERHEAD_CONDUCTOR{$ohl_id_conductor_c->{$l}}};
				$cid_c->{$l} = $IDMAP_OVERHEAD_CONDUCTOR{$ohl_id_conductor_c->{$l}};
			} else {
				$conductor_C = $ohl_id_conductor_c->{$l};
			}
			my $conductor_N;
			if ($ocons->{$ohl_id_conductor_n->{$l}}) {
				$conductor_N = $ocons->{$ohl_id_conductor_n->{$l}};
				$cid_n->{$l} = $ohl_id_conductor_n->{$l};
			} elsif ($ocons->{$IDMAP_OVERHEAD_CONDUCTOR{$ohl_id_conductor_n->{$l}}}) {
				$conductor_N = $ocons->{$IDMAP_OVERHEAD_CONDUCTOR{$ohl_id_conductor_n->{$l}}};
				$cid_n->{$l} = $IDMAP_OVERHEAD_CONDUCTOR{$ohl_id_conductor_n->{$l}};
			} else {
				$conductor_N = $ohl_id_conductor_n->{$l};
			}
			my $name3 = $iOHLSPG + $iPHASES{$link_phases->{$l}};
			print $glm "object $obj2 {\n";
			print $glm "\tname          $name2;\n";
			print $glm "\tconductor_A   $conductor_A;\n" if ($link_phases->{$l} =~ /A/);
			print $glm "\tconductor_B   $conductor_B;\n" if ($link_phases->{$l} =~ /B/);
			print $glm "\tconductor_C   $conductor_C;\n" if ($link_phases->{$l} =~ /C/);
			print $glm "\tconductor_N   $conductor_N;\n" if ($link_phases->{$l} =~ /N/);
			print $glm "\tspacing       $name3;\n}\n\n";
			$i++;
		}
	}
	return($name1,
	       $cid_a,
	       $cid_b,
	       $cid_c,
	       $cid_n);
}



# GridLab-D Model: object: line_spacing (specifically for overhead lines):
sub objectify_ohl_spacings {
	my ($glm,
	    $phases		# AN | BN |CN | ABN | ACN | BCN | ABCN
	   ) = @_;
	my $obj  = 'line_spacing';
	my $name = $iOHLSPG + $iPHASES{$phases};
	# Default A-B-C-N spatial configuration for overhead conductors --
	my %A = ("x" => -3.6, "y" => 32.0); # Coordinates (ft) of phase-A conductor
	my %B = ("x" =>  0.0, "y" => 33.0); #                           B
	my %C = ("x" =>  3.6, "y" => 32.0); #                           C
	my %N = ("x" =>  0.0, "y" => 27.9); #                           N
	# And the distances between the conductors, based on the above information:
	my %d = (ab => sprintf('%.2f', sqrt(($B{x} - $A{x}) ** 2 + ($B{y} - $A{y}) ** 2)),
		 bc => sprintf('%.2f', sqrt(($C{x} - $B{x}) ** 2 + ($C{y} - $B{y}) ** 2)),
		 ac => sprintf('%.2f', sqrt(($C{x} - $A{x}) ** 2 + ($C{y} - $A{y}) ** 2)),
		 an => sprintf('%.2f', sqrt(($N{x} - $A{x}) ** 2 + ($N{y} - $A{y}) ** 2)),
		 bn => sprintf('%.2f', sqrt(($N{x} - $B{x}) ** 2 + ($N{y} - $B{y}) ** 2)),
		 cn => sprintf('%.2f', sqrt(($N{x} - $C{x}) ** 2 + ($N{y} - $C{y}) ** 2))
		);
	print $glm "object $obj {\n";
	print $glm "\tname        $name;\n";
	if ($phases eq 'AN') {
		print $glm "\tdistance_AN $d{an}; // feet\n";
	} elsif ($phases eq 'BN') {
		print $glm "\tdistance_BN $d{bn}; // feet\n";
	} elsif ($phases eq 'CN') {
		print $glm "\tdistance_CN $d{cn}; // feet\n";
	} elsif ($phases eq 'ABN') {
		print $glm "\tdistance_AB $d{ab}; // feet\n";
		print $glm "\tdistance_AN $d{an}; // feet\n";
		print $glm "\tdistance_BN $d{bn}; // feet\n";
	} elsif ($phases eq 'ACN') {
		print $glm "\tdistance_AC $d{ac}; // feet\n";
		print $glm "\tdistance_AN $d{an}; // feet\n";
		print $glm "\tdistance_CN $d{cn}; // feet\n";
	} elsif ($phases eq 'BCN') {
		print $glm "\tdistance_BC $d{bc}; // feet\n";
		print $glm "\tdistance_BN $d{bn}; // feet\n";
		print $glm "\tdistance_CN $d{cn}; // feet\n";
	} elsif ($phases eq 'ABCN') {
		print $glm "\tdistance_AB $d{ab}; // feet\n";
		print $glm "\tdistance_BC $d{bc}; // feet\n";
		print $glm "\tdistance_AC $d{ac}; // feet\n";
		print $glm "\tdistance_AN $d{an}; // feet\n";
		print $glm "\tdistance_BN $d{bn}; // feet\n";
		print $glm "\tdistance_CN $d{cn}; // feet\n";
	} else {
		print STDOUT "EXIT: objectify_ohl_spacings(): Unknown Phases.\n";
		exit 1;
	}
	print $glm "}\n\n";
}



our %UNITS;
our %RHO;



# GridLab-D Model: object: underground_line_conductor:
sub objectify_ugl_conductors {
	my ($glm
	   ) = @_;
	my $name;
	my $obj = 'underground_line_conductor';
	my $i   = 0;
	open(my $ei_amp, '>>', './ei-amp.csv') || die "$!"; # Note '>>'
	foreach my $id (sort keys %UNDERGROUND_CABLE_DATABASE) {
		my $specs                = $UNDERGROUND_CABLE_DATABASE{$id};
		my $outer_diameter       = sprintf('%.5f', $specs->{'outer_diameter'});
		my $conductor_diameter   = sprintf('%.5f', $specs->{'conductor_diameter'});
		my $neutral_diameter     = sprintf('%.5f', $specs->{'neutral_diameter'});
		my $conductor_gmr        = sprintf('%.5f', $UNITS{'dia_gmr'} * $specs->{'conductor_diameter'} * $UNITS{'in_ft'});
		my $neutral_gmr          = sprintf('%.5f', $UNITS{'dia_gmr'} * $specs->{'neutral_diameter'}   * $UNITS{'in_ft'});
		my $conductor_resistance = sprintf('%.5f', $RHO{ALUMINUM} / area_circle($specs->{'conductor_diameter'}) / $UNITS{'in_mile'});
		my $neutral_resistance   = sprintf('%.5f', $RHO{COPPER}   / area_circle($specs->{'neutral_diameter'})   / $UNITS{'in_mile'});
		$name->{$id} = $iUGLCND + $i + 1;
		print $glm "// EquipmentId: $id\n";
		print $glm "object $obj {\n";
		print $glm "\tname                 $name->{$id};\n";
		print $glm "\touter_diameter       $outer_diameter; // inches\n";
		print $glm "\tconductor_diameter   $conductor_diameter; // inches\n";
		print $glm "\tconductor_gmr        $conductor_gmr; // feet\n";
		print $glm "\tconductor_resistance $conductor_resistance; // Ohm/mile\n";
		print $glm "\tneutral_diameter     $neutral_diameter; // inches\n";
		print $glm "\tneutral_gmr          $neutral_gmr; // feet\n";
		print $glm "\tneutral_resistance   $neutral_resistance; // Ohm/mile\n";
		print $glm "\tneutral_strands      $specs->{neutral_strands};\n}\n\n";
		objectify_ugl_spacings($glm, $specs->{outer_diameter} * $UNITS{'in_ft'}, $i, $_) foreach (qw(AN BN CN ABN ACN BCN ABCN));
		print $ei_amp "$id,$specs->{'in_duct_ampacity'}\n";
		$i++;
	}
	return($name);
}



our %IDSUB_UNDERGROUND_CABLE;
our $iUGL;
our $iUGLCFG;



# GridLab-D Model: object: underground_line / line_configuration:
sub objectify_ugl_configurations {
	my ($glm,
	    $linkify,
	    $ugl_links,
	    $nons,
	    $from_node,
	    $to_node,
	    $ucons,
	    $ugl_conductor_caId,
	    $ugl_length,
	    $link_phases,
	    $cid_a,
	    $cid_b,
	    $cid_c,
	    $cid_n
	   ) = @_;
	my $name1;
	my $obj1       = 'underground_line';
	my $obj2       = 'line_configuration';
	my $obj3       = 'line_spacing';
	my $i = my $n  = 0;
	my %k;
	$k{$_} = $n++ foreach (sort keys %$ucons);
	foreach my $l (@$ugl_links) {
		if ($linkify->{$l}) {
			$name1->{$l} = $iUGL    + $i + 1;
			my $name2    = $iUGLCFG + $i + 1;
			print $glm "// SectionId: $l\n";
			print $glm "object $obj1 {\n";
			print $glm "\tname          $name1->{$l};\n";
			print $glm "\tfrom          $nons->{$from_node->{$l}};\n";
			print $glm "\tto            $nons->{$to_node->{$l}};\n";
			print $glm "\tlength        $ugl_length->{$l}; // feet\n";
			print $glm "\tphases        $link_phases->{$l};\n";
			print $glm "\tconfiguration $name2;\n";
			print $glm "}\n\n";
			my ($cid, $kk);
			if ($ucons->{$ugl_conductor_caId->{$l}}) {
				$cid = $ucons->{$ugl_conductor_caId->{$l}};
				$kk  = $k{$ugl_conductor_caId->{$l}};
				$cid_a->{$l} = $cid_b->{$l} = $cid_c->{$l} = $cid_n->{$l} = $ugl_conductor_caId->{$l};
			} elsif ($ucons->{$IDSUB_UNDERGROUND_CABLE{$ugl_conductor_caId->{$l}}}) {
				$cid = $ucons->{$IDSUB_UNDERGROUND_CABLE{$ugl_conductor_caId->{$l}}};
				$kk  = $k{$IDSUB_UNDERGROUND_CABLE{$ugl_conductor_caId->{$l}}};
				$cid_a->{$l} = $cid_b->{$l} = $cid_c->{$l} = $cid_n->{$l} = $IDSUB_UNDERGROUND_CABLE{$ugl_conductor_caId->{$l}};
			} else {
				$cid = "${obj1}_conductor_$ugl_conductor_caId->{$l}";
				$kk  = -1;
				print STDOUT "ERROR: ${obj1}_$i: EI $ugl_conductor_caId->{$l}.\n";
			}
			my $name3 = $iUGLSPG + 1000 * $kk + $iPHASES{$link_phases->{$l}} if ($kk != -1);
			print $glm "object $obj2 {\n";
			print $glm "\tname          $name2;\n";
			print $glm "\tconductor_A   $cid;\n" if ($link_phases->{$l} =~ /A/);
			print $glm "\tconductor_B   $cid;\n" if ($link_phases->{$l} =~ /B/);
			print $glm "\tconductor_C   $cid;\n" if ($link_phases->{$l} =~ /C/);
			print $glm "\tconductor_N   $cid;\n" if ($link_phases->{$l} =~ /N/);
			print $glm "\tspacing       $name3;\n}\n\n";
			$i++;
		}
	}
	return($name1);
}



# GridLab-D Model: object: line_spacing (specifically for underground lines):
sub objectify_ugl_spacings {
	my ($glm,
	    $od,	  # outer diameter of each cable assembly [ft]
	    $i,		  # Arbitrary integer (positive)
	    $phases	  # AN | BN |CN | ABN | ACN | BCN | ABCN
	   ) = @_;
	my $obj  = 'line_spacing';
	my $name = $iUGLSPG + 1000 * $i + $iPHASES{$phases};
	# Because we do not have any spacing information for underground cables,
	# I am simply going to assume a triplex configuration (shown below):
	#
	#      B
	#    *   *
	#   *     *
	#  *       *
	# A * * * * C
	#
	# Wherein,
	# $d{ab} = $d{bc} = $d{ac} = $od.
	# Also,
	# because the neutral strands are placed uniformly around the circumference of the overall cable assembly,
	# (underneath the jacket, of course), we can estimate:
	# $d{an} = $d{bn} = $d{cn} ~= $od / 2.
	my %d = (ab => sprintf('%.5f', $od),
		 bc => sprintf('%.5f', $od),
		 ac => sprintf('%.5f', $od),
		 an => sprintf('%.5f', $od / 2),
		 bn => sprintf('%.5f', $od / 2),
		 cn => sprintf('%.5f', $od / 2));
	print $glm "object $obj {\n";
	print $glm "\tname        $name;\n";
	if ($phases eq 'AN') {
		print $glm "\tdistance_AN $d{an}; // feet\n";
	} elsif ($phases eq 'BN') {
		print $glm "\tdistance_BN $d{bn}; // feet\n";
	} elsif ($phases eq 'CN') {
		print $glm "\tdistance_CN $d{cn}; // feet\n";
	} elsif ($phases eq 'ABN') {
		print $glm "\tdistance_AB $d{ab}; // feet\n";
		print $glm "\tdistance_AN $d{an}; // feet\n";
		print $glm "\tdistance_BN $d{bn}; // feet\n";
	} elsif ($phases eq 'ACN') {
		print $glm "\tdistance_AC $d{ac}; // feet\n";
		print $glm "\tdistance_AN $d{an}; // feet\n";
		print $glm "\tdistance_CN $d{cn}; // feet\n";
	} elsif ($phases eq 'BCN') {
		print $glm "\tdistance_BC $d{bc}; // feet\n";
		print $glm "\tdistance_BN $d{bn}; // feet\n";
		print $glm "\tdistance_CN $d{cn}; // feet\n";
	} elsif ($phases eq 'ABCN') {
		print $glm "\tdistance_AB $d{ab}; // feet\n";
		print $glm "\tdistance_BC $d{bc}; // feet\n";
		print $glm "\tdistance_AC $d{ac}; // feet\n";
		print $glm "\tdistance_AN $d{an}; // feet\n";
		print $glm "\tdistance_BN $d{bn}; // feet\n";
		print $glm "\tdistance_CN $d{cn}; // feet\n";
	} else {
		print STDOUT "EXIT: objectify_ugl_spacings(): Unknown Phases.\n";
		exit 1;
	}
	print $glm "}\n\n";
}



# GridLab-D Model: object: triplex_line_conductor / triplex_line_configuration:
# (See http://gridlab-d.sourceforge.net/wiki/index.php/Power_Flow_User_Guide#Triplex_Line_Configuration)
sub objectify_triplex_line_conductor_configuration {
	my ($glm) = @_;
	print $glm "object triplex_line_configuration {\n";
	print $glm "\tname                 $iTLCCFG;\n";
	print $glm "\tconductor_1          generic_triplex_conductor;\n";
	print $glm "\tconductor_2          generic_triplex_conductor;\n";
	print $glm "\tconductor_N          generic_triplex_conductor;\n";
	print $glm "\tinsulation_thickness 0.08; // inches\n";
	print $glm "\tdiameter             0.368; // inches\n";
	print $glm "}\n\n";
	print $glm "object triplex_line_conductor {\n";
	print $glm "\tname                  generic_triplex_conductor;\n";
	print $glm "\tresistance            0.97; // Ohm/mile\n";
	print $glm "\tgeometric_mean_radius 0.0111; // feet\n";
	print $glm "}\n\n";
}



our $UTILITY_ID;
our %XFO_DEFAULT_CONNECT_TYPE;
our %MAP_CYMD_TC_GLD_CT;
our $iXFO;
our $iXFOCFG;



# GridLab-D Model: object: transformer:
sub objectify_transformers {
	my ($glm,
	    $use_transformers,
	    $linkify,
	    $xfo_links,
	    $nons,
	    $dn_load,
	    $from_node,
	    $to_node,
	    $link_phases,
	    $connected_kva,
	    $xfo_equId,
	    $xfo_rating,
	    $xfo_transformer_connection,
	    $xfo_voltage_primary,
	    $xfo_voltage_secondary,
	    $xfo_impedance,
	    $secondary_details
	   ) = @_;
	open(my $dnkva,  '>', './dn-kva.csv') || die "$!";
	print $dnkva "dn,kva\n";
	my $name1;
	my $obj1 = 'transformer';
	my $obj2 = 'configuration';
	my $i    = 0;
	foreach my $l (@$xfo_links) {
		if ($linkify->{$l}) {
			my $dnl               = $dn_load->{$to_node->{$l}};
			my $ei                = $xfo_equId->{$dnl};
			my $phases            = $link_phases->{$l};
			my $connect_type      = $XFO_DEFAULT_CONNECT_TYPE{'2/3P'}; # default
			my $primary_voltage   = $NOMINAL_VOLTAGE_PRIMARY; # default
			my $secondary_voltage = $NOMINAL_VOLTAGE_SECONDARY; # default
			my ($power_rating,
			    $impedance);
			if (!$use_transformers) {
				my $kva = sprintf('%.0f', $connected_kva->{$dnl});
				if (($UTILITY_ID eq 'GMP') && $ei) {
					if ($ei =~ /^DIST\_/aa) {
						$kva = the_greater_of($kva, transformer_equId_rating($ei));
					}
				}
				$power_rating = transformer_standard_rating($kva);
				$impedance    = transformer_impedance($power_rating);	
				if ($phases eq 'AN' || $phases eq 'BN' || $phases eq 'CN') {
					if ($secondary_details) {
						$secondary_voltage = $NOMINAL_VOLTAGE_SECONDARY / 2;
						$connect_type      = $XFO_DEFAULT_CONNECT_TYPE{'1P'};
					}
				} else { # (AB|BC|AC)N; ABCN
					$primary_voltage   = ceil($NOMINAL_VOLTAGE_PRIMARY   * sqrt(3)); # e.g. 7200 V (L->G) => 12471 V (L->L)
					$secondary_voltage = ceil($NOMINAL_VOLTAGE_SECONDARY * sqrt(3)); # e.g.  240 V (L->G) =>   416 V (L->L)
				}
			} else {
				$power_rating = $xfo_rating->{$ei};
				$impedance    = $xfo_impedance->{$ei};	
				if ($phases eq 'AN' || $phases eq 'BN' || $phases eq 'CN') {
					$primary_voltage   = ceil($xfo_voltage_primary->{$ei} / sqrt(3)); # e.g. 12470 V (L->L) =>  7200 V (L->G)
					if ($secondary_details) {
						$secondary_voltage = ceil($xfo_voltage_secondary->{$ei} / 2);
						$connect_type      = $XFO_DEFAULT_CONNECT_TYPE{'1P'}; # OXYMORONIC (with $use_transformers): got anything better?
					} else {
						$secondary_voltage = $xfo_voltage_secondary->{$ei};
					}
				} else {
					$connect_type      = $MAP_CYMD_TC_GLD_CT{$xfo_transformer_connection->{$ei}};
					$primary_voltage   = $xfo_voltage_primary->{$ei};
					$secondary_voltage = ceil($xfo_voltage_secondary->{$ei} * sqrt(3));
				}
			}
			if ($secondary_details && ($phases eq 'AN' || $phases eq 'BN' || $phases eq 'CN')) {
				$phases =~ s/N/S/aa;
			}
			$name1->{$l} = $iXFO    + $i + 1;
			my $name2    = $iXFOCFG + $i + 1;
			print $glm "// SectionId: $l\n";
			print $glm "object $obj1 {\n";
			print $glm "\tname                $name1->{$l};\n";
			print $glm "\tfrom                $nons->{$from_node->{$l}};\n";
			print $glm "\tto                  $nons->{$to_node->{$l}};\n";
			print $glm "\tphases              $phases;\n";
			print $glm "\tconfiguration       $name2;\n";
			print $glm "}\n\n";
			print $glm "// EquipmentId: $ei\n";
			print $glm "object ${obj1}_${obj2} {\n";
			print $glm "\tname                $name2;\n";
			print $glm "\tconnect_type        $connect_type;\n";
			print $glm "\tpower_rating        $power_rating; // kilo-Volt Amperes\n";
			print $glm "\tprimary_voltage     $primary_voltage; // Volts\n";
			print $glm "\tsecondary_voltage   $secondary_voltage; // Volts\n";
			print $glm "\timpedance           $impedance; // per-unit Ohm\n";
			print $glm "}\n\n";
			print $dnkva "$dnl,$power_rating\n";
			$i++;
		}
	}
	return($name1);
}



our @XFO_STANDARD_POWER_RATING;



# Miscellaneous: Returns the standard rating of a transformer that can handle the given "ConnectedKVA":
sub transformer_standard_rating {
	my ($kva) = @_;
	my $stdr;
	if (!$kva) {
		$stdr = sprintf('%.1f', $XFO_STANDARD_POWER_RATING[1]); # 1 KVA
	} elsif ($kva > $XFO_STANDARD_POWER_RATING[-1]) {
		$stdr = sprintf('%.1f', $kva);
	} else {
	      BRACKET_RATING: {
			for (my $i = 0; $i < $#XFO_STANDARD_POWER_RATING; $i++) {
				if (($kva > $XFO_STANDARD_POWER_RATING[$i]) && ($kva <= $XFO_STANDARD_POWER_RATING[$i+1])) {
					$stdr = sprintf('%.1f', $XFO_STANDARD_POWER_RATING[$i+1]);
					last BRACKET_RATING;
				}
			}
		}
	}
	return($stdr);
}



our %XFO_LOAD_LOSS;
our %XFO_DEFAULT_LOAD_LOSS;
our $XFO_REACTANCE_BY_RESISTANCE;
our $XFO_DEFAULT_IMPEDANCE;



# Miscellaneous: Computes the impedance of a transformer given its "power_rating" (KVA):
sub transformer_impedance {
	my ($power_rating) = @_;
	my ($resistance,
	    $R,
	    $X,
	    $impedance);
	if (my $load_loss = $XFO_LOAD_LOSS{$power_rating}) {
		$resistance = $load_loss->{FULL};
	} else {
		my @preset_power_ratings = sort keys %XFO_LOAD_LOSS;
		my $key;
		if ($power_rating < $preset_power_ratings[0]) {
			$key = 'BELOW_10KVA';
		} elsif ($power_rating > $preset_power_ratings[-1]) {
			$key = 'ABOVE_75KVA';
		} else {
			$key = undef;
		}
		if ($key) {
			$resistance = $XFO_DEFAULT_LOAD_LOSS{FULL}->{$key};					
		}
	}
	if ($resistance) {
		$R         = sprintf('%.5f', $resistance);
		$X         = sprintf('%.5f', $XFO_REACTANCE_BY_RESISTANCE * $resistance);
		$impedance = "${R}+${X}j";
	} else {
		$impedance = $XFO_DEFAULT_IMPEDANCE;
	}
	return($impedance);
}



# Miscellaneous: GMP-Specific HACK: Determines the rating of a transformer from its "EquipmentId" (e.g. DIST_25KVA_1P_G_120/240):
sub transformer_equId_rating {
	my ($ei) = @_;
	my ($prefix,
	    $rating,
	    $phase,
	    $circuit,
	    $voltages) = cut_string($ei, '_');
	$rating =~ s/[[:alpha:]]//gaa; # E.g. 25KVA -> 25
	$rating = 1 if (!$rating); # Accounts for cases where the rating is specified simply as KVA or MVA.
	return($rating);
}



# __INTERNAL__
sub objectify_all_group_recorders {
	my ($glm,
	    $interval,
	    $secondary_details
	   ) = @_;
	my $voltages        = ['voltage_A',
			       'voltage_B',
			       'voltage_C'
			      ];
	my $currents        = ['current_out_A',
			       'current_out_B',
			       'current_out_C'
			      ];
	my $meter         = ['measured_voltage_A',
			     'measured_voltage_B',
			     'measured_voltage_C',
			     'measured_current_A',
			     'measured_current_B',
			     'measured_current_C'
			    ];
	my $triplex_meter = ['measured_voltage_1',
			     'measured_voltage_2',
			     'measured_current_1',
			     'measured_current_2'
			    ];
	my %group_recorder;
	if ($secondary_details) {
		%group_recorder = (node             => $voltages,
				   overhead_line    => $currents,
				   underground_line => $currents,
				   meter            => $meter,
				   triplex_meter    => $triplex_meter);
	} else {
		%group_recorder = (node             => $voltages,
				   overhead_line    => $currents,
				   underground_line => $currents,
				   transformer      => $currents,
				   load             => $voltages);
	}
	print $glm "\n\n";
	foreach my $class (keys %group_recorder) {
		foreach my $property (@{$group_recorder{$class}}) {
			foreach my $complex_part (qw(MAG ANG_DEG)) {
				objectify_group_recorder($glm,
							 $class,
							 $property,
							 $complex_part,
							 $interval);
			}
		}
	}
}



# __INTERNAL__
sub move_load_away_from_pole {
	my ($xp, $yp,		# coordinates of the pole
	    $xl, $yl,		# coordinates of the load
	    $k			# delta-x gain
	   ) = @_;
	my $dx = ($xl - $xp);
	my $dy = ($yl - $yp);
	if (abs $dx > 0) {
		my $a  =  $dy / $dx;			# slope
		my $b  = ($yp * $xl - $yl * $xp) / $dx; # intercept
		$xl    =  $xp + $k * $dx;
		$yl    =  $a * $xl + $b;
	} else {
		$yl   +=  $k * $dy;
	}
	return($xl,
	       $yl);
}



# __INTERNAL__
sub from_to_of_links {
	my ($links,
	    $include,
	    $from,
	    $to
	   ) = @_;
	my (%frsects,
	    %tosects);
	foreach my $l (@$links) {
		if ($include->{$l}) {
			$frsects{$from->{$l}} .= "${l}___";
			$tosects{$to->{$l}}   .= "${l}___";
		}
	}
	return(\%frsects,
	       \%tosects);
}



# __INTERNAL__
sub complex_power {
	my ($P,			# Active   Power
	    $Q			# Reactive Power 
	   ) = @_;
	my $S;
	if ($P != undef && $Q != undef) {
		my $sign = '+' if ($Q >= 0);
		$S       = sprintf('%.3f%s%.3f%s', $P, $sign, $Q, 'j');
	}
	return($S);
}



# __INTERNAL__
sub index_of_key {
	my ($href,
	    $key
	   ) = @_;
	my $i;
      GO_FIGURE: {
		foreach my $k (sort keys %$href) {
			if ($k eq $key) {
				last GO_FIGURE;
			}
			$i++;
		}
	}
	return($i);
}



# __INTERNAL__
sub save_nodes_and_links {
	my ($nons,		# $nons
	    $gate2secy,
	    $nodify,
	    $node_phases,
	    $lons,		# {%$olons, %$ulons, %$xfoons}
	    $from_node,
	    $to_node,
	    $linkify,
	    $link_phases,
	    $it_is_ohl_ugl,
	    $x,
	    $y,
	    $cid_a,
	    $cid_b,
	    $cid_c,
	    $cid_n
	   ) = @_;
	#a. Principal nodes and links:
	open(my $nd, ">", "./nodes.csv") || die "$!";
	print $nd "name,is_loaded,ph_a,ph_b,ph_c,x,y\n";
	foreach my $n (keys %$nons) {
		if ($nodify->{$n}) {
			my $flag = 1 * $gate2secy->{$n};
			my $ph_a = ($node_phases->{$n} =~ /A/aa) ? 1 : 0;
			my $ph_b = ($node_phases->{$n} =~ /B/aa) ? 1 : 0;
			my $ph_c = ($node_phases->{$n} =~ /C/aa) ? 1 : 0;
			print $nd "$nons->{$n},$flag,$ph_a,$ph_b,$ph_c,$x->{$n},$y->{$n}\n";
		}
	}
	open(my $ln, ">", "./links.csv") || die "$!";
	print $ln "section_name,is_ohl_ugl,from_node_name,to_node_name,ph_a,ph_b,ph_c,cid_a,cid_b,cid_c,cid_n\n";
	foreach my $l (keys %$lons) {
		if ($linkify->{$l}) {
			my $flag = 1 * $it_is_ohl_ugl->{$l};
			my $ph_a = ($link_phases->{$l} =~ /A/aa) ? 1 : 0;
			my $ph_b = ($link_phases->{$l} =~ /B/aa) ? 1 : 0;
			my $ph_c = ($link_phases->{$l} =~ /C/aa) ? 1 : 0;
			print $ln "$lons->{$l},$flag,$nons->{$from_node->{$l}},$nons->{$to_node->{$l}},"
			  .       "$ph_a,$ph_b,$ph_c,$cid_a->{$l},$cid_b->{$l},$cid_c->{$l},$cid_n->{$l}\n";
		}
	}
	#b. The rank of each node:
	my (%friends);
	foreach my $l (keys %$lons) {
		if ($linkify->{$l}) {
			$friends{$from_node->{$l}} .=   "$nons->{$to_node->{$l}}___";
			$friends{$to_node->{$l}}   .= "$nons->{$from_node->{$l}}___";
		}
	}
	open(my $nn, '>', './node-nodes.csv') || die "$!";
	open(my $rk, '>', './node-rank.csv')  || die "$!";
	print $rk "name,rank\n";
	foreach my $n (keys %$nons) {
		if ($nodify->{$n}) {
			my @contacts = cut_string($friends{$n}, '___');
			my $rank     = $#contacts + 1;
			print $nn "$nons->{$n},", join(",", @contacts), "\n";
			print $rk "$nons->{$n},$rank\n";
		}
	}
	#c. The links that each node belongs to:
	my ($frsects,
	    $tosects) = from_to_of_links([keys %$lons],
					 $linkify,
					 $from_node,
					 $to_node);
	open(my $nl, '>', './node-links.json') || die "$!";
	my $init = 1;
	print $nl "[";
	foreach my $n (keys %$nons) {
		if ($nodify->{$n}) {
			my $begin;
			if ($init) {
				$begin = undef;
				$init  = 0;
			} else {
				$begin = ",\n";
			}
			print $nl "$begin" if ($begin);
			print $nl "{\n";
			print $nl "\"node\":   \"$nons->{$n}\",\n";
			my (@frl,
			    @tol);
			if (my @frs = cut_string($frsects->{$n}, '___')) {
				push @frl, "\"$lons->{$_}\"" foreach (@frs);
			}
			if (my @tos = cut_string($tosects->{$n}, '___')) {
				push @tol, "\"$lons->{$_}\"" foreach (@tos);
			}
			my $str = join(', ', @frl, @tol);
			print $nl "\"links\": [$str]\n";
			print $nl "}";
		}
	}
	print $nl "]\n";
}



# __INTERNAL__ && __UNUSED__
sub initialize_phase_values {
	my ($magnitude,
	    $notation		# 'polar' or 'rectangular'?
	   ) = @_;
	my %cn;			# complex number
	my %theta = (a =>    0,
		     b => -120,
		     c =>  120);
	foreach my $phase (sort keys %theta) {
		if ($notation eq 'polar') {
			my $m       = $magnitude;
			my $p       = $theta{$phase};
			my $sign    = '+' if ($p >= 0);
			$cn{$phase} = sprintf('%.1f%s%.1f%s', $m, $sign, $p, 'd');
		} else {
			my $r       = $magnitude * cos(pi/180 * $theta{$phase}); # real      component
			my $i       = $magnitude * sin(pi/180 * $theta{$phase}); # imaginary component
			my $sign    = '+' if ($i >= 0);
			$cn{$phase} = sprintf('%.3f%s%.3f%s', $r, $sign, $i, 'j');
		}
	}
	return(%cn);
}





##############################DO NOT TOUCH##################################
1; # To "require" this file in another, a truthy value needs to be returned.
############################################################################
