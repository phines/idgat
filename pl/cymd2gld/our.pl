use strict;
use warnings;





our $UTILITY_ID                     =        'GMP';





our $NOMINAL_VOLTAGE_PRIMARY        =        7200.0; # Line-to-Ground (V)
our $NOMINAL_VOLTAGE_SECONDARY      =         240.0; # Ditto



our %LOOKUP_TABLE_PHASES            =        ('1'                       =>       'AN',
					      '2'                       =>       'BN',
					      '3'                       =>       'CN',
					      '4'                       =>       'ABN',
					      '5'                       =>       'ACN',
					      '6'                       =>       'BCN',
					      '7'                       =>       'ABCN'
					     ); # (The keys are CYMEDIST's, whereas the values are in GridLab-D format.)



# Underground cable specifications:
# (Assuming:
#  1. Southwire, LLC, as the manufacturer.
#  2. Aluminum phase conductor / Copper neutral.
# )
our %UNDERGROUND_CABLE_DATABASE     =        ('1/0-15KV_AAC_URD'        =>       {outer_diameter     => 1.0560, # inches
										  conductor_diameter => 0.3520, # inches
										  neutral_diameter   => 0.0641, # (14 AWG; inches)
										  neutral_strands    => 16, # (full neutral)
										  in_duct_ampacity   => 155
										 },
					      '1/0-35KV_AAC_URD'        =>       {outer_diameter     => 1.4130,
										  conductor_diameter => 0.3520,
										  neutral_diameter   => 0.0641,
										  neutral_strands    => 16, # (full neutral)
										  in_duct_ampacity   => 149
										 },
					      '#2-15KV_AAC_URD'         =>       {outer_diameter     => 0.9860,
										  conductor_diameter => 0.2830,
										  neutral_diameter   => 0.0641,
										  neutral_strands    => 10, # (full neutral)
										  in_duct_ampacity   => 119
										 },
					      '350-15KV_AAC_URD'        =>       {outer_diameter     => 1.3960,
										  conductor_diameter => 0.6610,
										  neutral_diameter   => 0.0641,
										  neutral_strands    => 6, # (1/3 neutral)
										  in_duct_ampacity   => 319
										 },
					      '500-15KV_AAC_URD'        =>       {outer_diameter     => 1.5210,
										  conductor_diameter => 0.7890,
										  neutral_diameter   => 0.0641,
										  neutral_strands    => 8, # (1/3 neutral)
										  in_duct_ampacity   => 384
										 },
					      '750-15KV_AAC_URD'        =>       {outer_diameter     => 1.7980,
										  conductor_diameter => 0.9680,
										  neutral_diameter   => 0.0808, # (12 AWG)
										  neutral_strands    => 8, # (1/3 neutral)
										  in_duct_ampacity   => 468
										 },
					      '1000-15KV_AAC_URD'       =>       {outer_diameter     => 1.9880,
										  conductor_diameter => 1.1170,
										  neutral_diameter   => 0.1019, # (10 AWG)
										  neutral_strands    => 7, # (1/3 neutral)
										  in_duct_ampacity   => 542
										 });



# Substitutions for unknown underground Cables:
our %IDSUB_UNDERGROUND_CABLE        =        ('1/0-15KV_AL_URD'         =>        '1/0-15KV_AAC_URD',
					      '336-NULL_26/7ACSR_URD'   =>        '350-15KV_AAC_URD',
					      '999-NULL_NULL_URD'       =>       '1000-15KV_AAC_URD',
					      'DEFAULT'                 =>        '750-15KV_AAC_URD');



# Mapping between phase/neutral conductor IDs from CYMOVERHEADBYPHASE (db_network) and CYMEQCONDUCTOR (db_equipment):
our %IDMAP_OVERHEAD_CONDUCTOR       =        ('1/0AAC'                  =>       '1/0_AAC',
					      '1/0AAAC'                 =>       '1/0_AAAC',
					      '1/0AAC_SPCR_15'          =>       '1/0_AAC_SPCR_15',
					      '1/06/1ACSR'              =>       '1/0_6/1ACSR',
					      '1/0ACSR'                 =>       '1/0_6/1ACSR',
					      '#2AAC'                   =>       '#2_AAC',
					      '#2AAAC'                  =>       '#2_AAAC',
					      '#2ACSR'                  =>       '#2_6/1ACSR',
					      '3/0AAAC'                 =>       '3/0_AAAC',
					      '#3CU'                    =>       '#3_CU',
					      '4/0AAAC'                 =>       '4/0_AAAC',
					      '4/0CU'                   =>       '4/0_CU',
					      '#4CU'                    =>       '#4_CU',
					      '#46/1ACSR'               =>       '#4_6/1ACSR',
					      '#4ACSR'                  =>       '#4_6/1ACSR',
					      '#6CU'                    =>       '#6_CU',
					      '#6SCP'                   =>       '#6_ASCP', # Dubious
					      '33626/7ACSR'             =>       '336_26/7ACSR',
					      '477-18/1ACSR'            =>       '477_18/1ACSR',
					      'NULLNULL'                =>       'NONE' # Dubious
					     );



our %CYMD_LOAD_VALUE_TYPE           =        ('KW_KVAR'                 =>       0,
					      'KVA_PF'                  =>       1,
					      'KW_PF'                   =>       2
					     ); # CYMD "LoadValueType" (0-2) field from the CYMCUSTOMERLOAD table.



our $CYMD_DISTRIBUTED_LOAD          =        21; # CYMD "DeviceType" field from the CYMCUSTOMERLOAD table for distributed loads.



# Catalog of CYMEDIST's "DeviceType"s:
our %DEVICE_TYPE                    =        (underground_line_conductor=>       1,
					      overhead_line_conductor   =>       3,
					      regulator                 =>       4,
					      transformer               =>       5,
					      recloser                  =>       10,
					      sectionalizer             =>       12,
					      switch                    =>       13,
					      fuse                      =>       14,
					      series_reactor            =>       16,
					      shunt_capacitor           =>       17,
					      spot_load                 =>       20,
					      distributed_load          =>       21
					     ); # (The values are CYMEDIST's, whereas the keys are merely for my own ease of recall.)



# Mapping between CYMDIST's "TransformerConnection" and GridLab-D's "connect_type":
our %MAP_CYMD_TC_GLD_CT             =        ('0'                       =>       'WYE_WYE',
					      '1'                       =>       'DELTA_GWYE',
					      '2'                       =>       'DELTA_DELTA');



# Default transformer "connect_type" for 1-, 2-, and 3-phase links:
our %XFO_DEFAULT_CONNECT_TYPE       =        ('1P'                      =>        'SINGLE_PHASE_CENTER_TAPPED',
					      '2/3P'                    =>        'WYE_WYE');



our $XFO_DEFAULT_IMPEDANCE          =        '0.01000+0.06000j'; # (i.e. R = 1% and X = 6% pu Ohm)



# The next 4 items are based on Yousu Chen's "Cyme_to_GridLabD.txt" (see comment at the very beginning of main.pl) --



our @XFO_STANDARD_POWER_RATING      =        (0,
					      1,
					      5,
					      10,
					      15,
					      25,
					      30,
					      37.5,
					      50,
					      75,
					      87.5,
					      100,
					      112.5,
					      125,
					      137.5,
					      150,
					      162.5,
					      175,
					      187.5,
					      200,
					      225,
					      250,
					      262.5,
					      300,
					      337.5,
					      400,
					      412.5,
					      450,
					      500,
					      750,
					      1000,
					      1250,
					      1500,
					      2000,
					      2500,
					      3000,
					      4000,
					      5000
					     ); # KVA



# Transformer {none,full}-load-loss (%, e.g. 0.01 means 1%) as a function of its rating (KVA):
our %XFO_LOAD_LOSS                  =        ('10.0'                    =>       {
										  NONE => 0.00380,
										  FULL => 0.02610
										 },
					      '15.0'                    =>       {
										  NONE => 0.00320,
										  FULL => 0.02160
										 },
					      '25.0'                    =>       {
										  NONE => 0.00244,
										  FULL => 0.01924
										 },
					      '30.0'                    =>       {
										  NONE => 0.00253,
										  FULL => 0.01773
										 },
					      '37.5'                    =>       {
										  NONE => 0.00267,
										  FULL => 0.01547
										 },
					      '45.0'                    =>       {
										  NONE => 0.00267,
										  FULL => 0.01451
										 },
					      '50.0'                    =>       {
										  NONE => 0.00267,
										  FULL => 0.01354
										 },
					      '75.0'                    =>       {
										  NONE => 0.00229,
										  FULL => 0.01557
										 });



# As above, except for rating < 10 KVA or > 75 KVA:
our %XFO_DEFAULT_LOAD_LOSS          =        ('NONE'                    =>       {
										  BELOW_10KVA => 0.00220,
										  ABOVE_75KVA => 0.00400
										 },
					      'FULL'                    =>       {
										  BELOW_10KVA => 0.01500,
										  ABOVE_75KVA => 0.02800
										 });



our $XFO_REACTANCE_BY_RESISTANCE    =        4.5; # Ratio



our %RHO                            =       (ALUMINUM                   =>       1.11023682e-06,
					     COPPER                     =>       6.61417680e-07
					    ); # Resistivity: Ohm Inches (at 20 degC ambient temperature)



our %UNITS                          =        ('in_ft'                   =>       1. / 12., # Inches -> Feet
					      'm_ft'                    =>       1. / 0.3048, # Meters -> Feet
					      'in_mile'                 =>       1. / 63360, # Inch -> Mile
					      'by1000ft_by1mile'        =>       0.189394, # Divided by 1000 Feet -> Divided by 1 Mile
					      'dia_gmr'                 =>       0.3894 # Diameter to GMR (Pam Allen's cable spreadsheet)
					     );



# __INTERNAL__
our $iSECGAT                        =        10000;
our $iOHLCND                        =        20000;
our $iOHL                           =        30000;
our $iOHLCFG                        =        40000;
our $iUGLCND                        =        50000;
our $iUGL                           =        60000;
our $iUGLCFG                        =        70000;
our $iXFO                           =        80000;
our $iXFOCFG                        =        90000;
our $iOHLSPG                        =       100000;
our $iUGLSPG                        =       110000;
our $iSG2MET                        =       200000;
our $iMETER                         =       210000;
our $iSG2MCFG                       =       220000;
our $iLOAD                          =       300000;
our $iTLCCFG                        =       999999;



# __INTERNAL__
our %iPHASES                        =        (AN                        =>       1,
					      BN                        =>       2,
					      CN                        =>       3,
					      ABN                       =>       4,
					      ACN                       =>       5,
					      BCN                       =>       6,
					      ABCN                      =>       7);



# __INTERNAL__
our $UG_CABLE_FOR_2AND3PHASE_LOADS  =        '1/0-15KV_AAC_URD';



# __INTERNAL__
our $TRIPLEX_LINE_LENGTH            =        45; # Feet





##############################DO NOT TOUCH##################################
1; # To "require" this file in another, a truthy value needs to be returned.
############################################################################
