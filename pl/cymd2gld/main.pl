# Author:  PAVAN Nandan RACHERLA (Research Assistant Professor, Complex Systems Center, University of Vermont).
# EMail:   <my_first_name>.<my_last_name>@uvm.edu
# License: LICENSE -- please peruse it *before* proceeding any further!



# (Original idea from https://sourceforge.net/p/gridlab-d/code/HEAD/tree/Taxonomy_Feeders/PopulationScript/ConversionScripts/Cyme_to_GridLabD.txt).





use strict;
use warnings;
use DBI;
use File::Basename qw(dirname);



our $script_directory = dirname(__FILE__); # Please see http://stackoverflow.com/a/90721 for an indepth discussion.



require "$script_directory/misc.pl";
require "$script_directory/cymd.pl";
require "$script_directory/gld.pl";





my ($db_equipment,
    $db_network,
    $feeder_netid,
    $infinite_bus,
    $use_transformers,
    $secondary_details)             =        parse_argv(@ARGV);





my $obj_db_network                  =        DBI->connect("DBI:mysql:database=$db_network; host=localhost",
							  $ENV{USER}, "",
							  {
							   'RaiseError' => 1});



my ($nodes,
    $x,
    $y)                             =        cymd_node(\$obj_db_network,
						       'CYMNODE',
						       [
							'NodeId',
							'X',
							'Y'
						       ],
						       $feeder_netid);



my ($from_node,
    $to_node,
    $link_phases,
    $links)                         =        cymd_section(\$obj_db_network,
							  'CYMSECTION',
							  [
							   'SectionId',
							   'FromNodeId',
							   'ToNodeId',
							   'Phase'
							  ],
							  $feeder_netid);



my ($xfo_links,
    $pol2xfo_links,
    $switch_links,
    $load_device_numbers,
    $switch_device_numbers)         =        cymd_section_device(\$obj_db_network,
								 'CYMSECTIONDEVICE',
								 [
								  'SectionId',
								  'DeviceType',
								  'DeviceNumber'
								 ],
								 $feeder_netid);



my ($ohl_id_conductor_a,
    $ohl_id_conductor_b,
    $ohl_id_conductor_c,
    $ohl_id_conductor_n,
    $ohl_length,
    $ohl_conductor_equId,
    $ohl_links)                     =        cymd_overhead_by_phase(\$obj_db_network,
								    'CYMOVERHEADBYPHASE',
								    [
								     'DeviceNumber',
								     'PhaseConductorIdA',
								     'PhaseConductorIdB',
								     'PhaseConductorIdC',
								     'NeutralConductorId',
								     'Length'
								    ],
								    $feeder_netid);



my ($ugl_conductor_caId,
    $ugl_length,
    $ugl_links)                     =        cymd_underground_line(\$obj_db_network,
								   'CYMUNDERGROUNDLINE',
								   [
								    'DeviceNumber',
								    'CableId',
								    'Length'
								   ],
								   $feeder_netid);



my ($switch_status)                 =        cymd_network_switch(\$obj_db_network,
								 'CYMSWITCH',
								 [
								  'DeviceNumber',
								  'NormalStatus',
								  'ClosedPhase'
								 ],
								 $feeder_netid);



my ($xfo_equId)                     =        cymd_network_transformer(\$obj_db_network,
								      'CYMTRANSFORMER',
								      [
								       'DeviceNumber',
								       'EquipmentId'
								      ],
								      $feeder_netid);



my ($load_W_a,
    $load_W_b,
    $load_W_c,
    $load_VAR_a,
    $load_VAR_b,
    $load_VAR_c,
    $connected_kva)                 =        cymd_customer_load(\$obj_db_network,
								'CYMCUSTOMERLOAD',
								[
								 'DeviceNumber',
								 'CustomerNumber',
								 'ConsumerClassId',
								 'DeviceType',
								 'LoadValueType',
								 'Phase',
								 'LoadValue1',
								 'LoadValue2',
								 'ConnectedKVA'
								],
								$feeder_netid);



$obj_db_network->disconnect();





my ($obj_db_equipment)              =        DBI->connect("DBI:mysql:database=$db_equipment; host=localhost",
							  $ENV{USER}, "",
							  {
							   'RaiseError' => 1});



my ($ohl_conductor_diameter,
    $ohl_conductor_GMR,
    $ohl_conductor_R25)             =        cymd_equipment_conductor(\$obj_db_equipment,
								      'CYMEQCONDUCTOR',
								      [
								       'EquipmentId',
								       'Diameter',
								       'GMR',
								       'R25',
								       'FirstRating'
								      ]);



my ($xfo_rating,
    $xfo_transformer_connection,
    $xfo_voltage_primary,
    $xfo_voltage_secondary,
    $xfo_impedance)                 =        cymd_equipment_transformer(\$obj_db_equipment,
									'CYMEQTRANSFORMER',
									[
									 'EquipmentId',
									 'NominalRatingKVA',
									 'TransformerConnection',
									 'PrimaryVoltageKVLL',
									 'SecondaryVoltageKVLL',
									 'PosSeqImpedancePercent',
									 'XRRatio'
									]
								       ) if ($use_transformers);



$obj_db_equipment->disconnect();





my ($Nodes,
    $gate2secy,
    $node_phases,
    $dn_load,
    $nodify,
    $linkify,
    $it_is_ohl_ugl)                 =        redraw_graph($ohl_links,
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
							  $y);





open(my $glm, '>', './TEMPLATE.glm') || die "$!";



glm_header($glm);



my ($nons)                          =        objectify_nodes($glm,
							     $nodify,
							     $Nodes,
							     $gate2secy,
							     $node_phases,
							     $infinite_bus,
							     $dn_load,
							     $secondary_details);



my ($ocons)                         =        objectify_ohl_conductors($glm,
								      $ohl_conductor_equId,
								      $ohl_conductor_diameter,
								      $ohl_conductor_GMR,
								      $ohl_conductor_R25);

objectify_ohl_spacings($glm, $_) foreach (qw(AN BN CN ABN ACN BCN ABCN));



my ($olons,
    $cid_a,
    $cid_b,
    $cid_c,
    $cid_n)                         =        objectify_ohl_configurations($glm,
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
									  $link_phases);



my ($ucons)                         =        objectify_ugl_conductors($glm);



my ($ulons)                         =        objectify_ugl_configurations($glm,
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
									  $cid_n);



my ($xfoons)                        =        objectify_transformers($glm,
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
								    $secondary_details);



objectify_triplex_line_conductor_configuration($glm) if ($secondary_details);



objectify_all_group_recorders($glm,
			      'I__IL',
			      $secondary_details);





save_nodes_and_links($nons,
		     $gate2secy,
		     $nodify,
		     $node_phases,
		     {
		      %$olons,
		      %$ulons,
		      %$xfoons
		     },
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
		     $cid_n);





# GLOSSARY:
# nons:   node                  object names
# ocons:  overhead    conductor object names
# ucons:  underground conductor object names
# olons:  overhead    line      object names
# ulons:  underground line      object names
# xfoons: transformer           object names
