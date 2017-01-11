library(ggplot2)
library(dplyr)
library(lubridate)



input_basedir    <- '~/tmp/gld/gmp/78g1/run_2015-july-1st-31st_xfo-to-load-direct/1'
input_subdirs    <- c('node/voltage',
		      'load/voltage',
		      'underground_line/current_out',
		      'overhead_line/current_out',
		      'transformer/current_out')
input_colClasses <- c('integer', 'character', rep('numeric', 6))
input_tz         <- 'America/New_York'



for (dir in paste(input_basedir, '/', input_subdirs, sep = '')) {
	file <- paste(dir, '/', 'TSJ.CSV', sep = '')

	df <- read.csv(file,
		       nrows      = as.integer(system(paste("wc -l", file, "|", "awk '{print $1}'")), intern = TRUE) - 1,
		       colClasses = input_colClasses,
		       header     = TRUE) %>%
		mutate(local_time = force_tz(ymd_hms(local_time, tz = input_tz)))

	save(df, file = paste(dir, '/', 'TSJ.BIN', sep = ''), compress = 'bzip2')

	write.csv(df %>%
		  	group_by(name) %>%
		  	summarize_at(vars(mA, aA, mB, aB, mC, aC),
				     funs(mean, sd),
				     na.rm = TRUE),
		  file      = paste(dir, '/', 'STATS.CSV', sep = ''),
		  row.names = FALSE,
		  quote     = FALSE)
}
