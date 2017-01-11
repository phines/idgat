iTimeStamp() { echo $(echo $1 | tr -d [:punct:][:space:]); } # e.g 2015-07-12 00:52:30 => 20150712005230





# TEMPLATE.glm Inputs:
TZ='EST+5EDT'            # clock            { timezone      } -> e.g. 'EST+5EDT'
T0='2015-07-01 00:07:30' # clock            { starttime     } -> e.g. '2015-07-12 00:52:30'
T1='2015-07-31 23:37:30' # clock            { stoptime      } -> e.g. '2015-07-12 23:52:30'
SM='NR'                  # module powerflow { solver_method } -> 'NR', for Newton-Raphson; 'FBS', for Forward-Backward Sweep
IL=900                   # object recorder  { interval      } -> in Seconds (e.g. 900 for 15-minute AMI data)



GRIDLABD_RUNTIME_OPTS='--bothstdout --debug'

GLM_TEMPLATE='./TEMPLATE.glm'
GLM_RUN_THIS='./gridlabd.glm'

GRIDLABD_LOG='./gridlabd.log'
GRIDLABD_YBUS='./ybus.csv'
GRIDLABD_SMI2NON='./smi2non.csv'

CLOCK_SEARCH_STRING='global_clock' # By grep'ing this phrase in GridLab-D's run log, we infer the current timestamp.





date
printf "\n\n\n"



i=1
tNOW=$T0

while (( $(iTimeStamp "$tNOW") < $(iTimeStamp "$T1") ))
do  
    sed "s/I__TZ/$TZ/; s/I__T0/$tNOW/; s/I__T1/$T1/; s/I__SM/$SM/; s/I__IL/$IL/g" $GLM_TEMPLATE \
	> $GLM_RUN_THIS
    
    gridlabd.bin $GRIDLABD_RUNTIME_OPTS $GLM_RUN_THIS \
	|& tee $GRIDLABD_LOG                          \
	    | grep -i $CLOCK_SEARCH_STRING
    
    last_string_logged=$(tail -1 $GRIDLABD_LOG \
				| awk '{print $NF}') # (NF = Number_of_Fields, a pre-defined variable in awk.)
    
    last_timestamp=$(tail -1 $GRIDLABD_LOG             \
			    | awk '{print $2, $3, $4}' \
			    | tr -d [])
    
    next_timestamp=$(date --date="$last_timestamp + $IL seconds" "+%F %T")
    
    out_dir=$i
    mkdir $out_dir
    mv                        $GRIDLABD_LOG $out_dir
    mv                       $GRIDLABD_YBUS $out_dir
    mv                    $GRIDLABD_SMI2NON $out_dir
    mv                   node_voltage_*.csv $out_dir
    mv      overhead_line_current_out_*.csv $out_dir
    mv   underground_line_current_out_*.csv $out_dir
    mv         meter_measured_voltage_*.csv $out_dir
    mv         meter_measured_current_*.csv $out_dir
    mv triplex_meter_measured_voltage_*.csv $out_dir
    mv triplex_meter_measured_current_*.csv $out_dir
    
    # Normal   Exit, last line: DEBUG [2015-07-13 00:07:30 EDT] : *** main loop ended at 1436760451; stoptime=1436760450, n_events=3, exitcode=0 ***
    # Abnormal Exit, last line: DEBUG [2015-07-12 11:52:30 EDT] : exit code 2
    if [ "$last_string_logged" != "***" ]
    then
	printf "\n\n\n$last_timestamp: ABNORMAL EXIT.\n\n\n"
    fi
    
    tNOW=$next_timestamp
    let i="$i+1"
done



printf "\n\n\n"
date



# GridLAB-D 4.0.0-5633 (trunk:M) 64-bit LINUX RELEASE
