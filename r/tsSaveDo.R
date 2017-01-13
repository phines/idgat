library(ggplot2)
library(dplyr)
library(lubridate)

input_basedir <- '~/tmp/gld/gmp/78g1/run_2015-july-1st-31st_xfo-to-load-direct/1'

input_subdirs <- c('node/voltage',
		   'load/voltage',
		   'underground_line/current_out',
		   'overhead_line/current_out',
		   'transformer/current_out')

bin <- TRUE # TRUE, if the data-frame is already in R binary format

for (dir in paste(input_basedir, '/', input_subdirs, sep = '')) {
	file <- paste(dir, '/', 'TSJ.CSV', sep = '')

	if (bin) {
		load(file = paste(dir, '/', 'TSJ.BIN', sep = ''))
	} else {
		df <- read.csv(file,
			       nrows = as.integer(system(paste("wc -l", file, "|", "awk '{print $1}'")), intern = T) - 1,
			       colClasses = c('integer', 'character', rep('numeric', 6)),
			       header = T) %>%
			mutate(local_time = force_tz(ymd_hms(local_time, tz = 'America/New_York')))

		save(df, file = paste(dir, '/', 'TSJ.BIN', sep = ''), compress = 'bzip2')
	}

	write.csv(df %>% group_by(name) %>% summarize_at(vars(mA, aA, mB, aB, mC, aC), funs(mean), na.rm = T),
		  file = paste(dir, '/', 'MEAN.CSV', sep = ''), row.names = F, quote = F)
}
