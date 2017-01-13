library(ggplot2)
library(dplyr)
library(lubridate)



gld <- read.csv("~/tmp/gld/gmp/78g1/run_2015-july-1st-31st_xfo-to-load-direct/1/underground_line/current_out/60071.csv", header = T) %>%
	mutate(local_time = force_tz(ymd_hms(local_time, tz = 'America/New_York')))

scada <- read.csv("~/data/proc/gmp/78g1/scada/2015-july-1st-31st.csv", header = T) %>%
	mutate(local_time = force_tz(ymd_hms(local_time, tz = 'America/New_York')))

lineplot_colors <- c("iDGA" = "FireBrick",
		     "SCADA" = "NavyBlue") # "Named" character! (11/07/2016)

x_gld <- gld$local_time
x_scada <- scada$local_time

y_gld.3phase_ave <- (gld$mA + gld$mB + gld$mC) / 3
y_scada.3phase_ave <- (scada$ia + scada$ib + scada$ic) / 3



## http://stackoverflow.com/questions/17148679/construct-a-manual-legend-for-a-complicated-plot
## Note how we've "aesthetically" mapped the (x,y) data to a particular color via aes(x, y, color)
ggplot() +
	geom_line(data = data.frame(x = x_gld,  y = y_gld.3phase_ave), aes(x = x_gld, y = y_gld.3phase_ave, color = "iDGA")) +
	geom_line(data = data.frame(x = x_scada, y = y_scada.3phase_ave), aes(x = x_scada, y = y_scada.3phase_ave, color = "SCADA")) +
	scale_colour_manual(name = "", values = lineplot_colors) +
	ggtitle(paste("Mean Error (iDGA minus SCADA) = ", sprintf("%.1f", mean(y_gld.3phase_ave - y_scada.3phase_ave, na.rm = T)), sep = "")) +
	xlab("Time") +
	ylab("3-Phase-Average Current (Amperes)") +
	theme_bw() +
	theme(panel.grid.major.x = element_blank(), panel.grid.minor.x = element_blank()) +
	theme(panel.grid.major.y = element_blank(), panel.grid.minor.y = element_blank())



data.frame(x = y_gld.3phase_ave, y = y_scada.3phase_ave) %>%
	ggplot(aes(x = y_gld.3phase_ave, y = y_scada.3phase_ave)) +
	geom_point() +
	ggtitle(paste("3-Phase-Average Current (Amperes): Rsquared = ", sprintf("%.3f", cor(x = y_gld.3phase_ave, y = y_scada.3phase_ave)), sep = "")) +
	xlab("iDGA") +
	ylab("SCADA") +
	theme_bw() +
	theme(panel.grid.major.x = element_blank(), panel.grid.minor.x = element_blank()) +
	theme(panel.grid.major.y = element_blank(), panel.grid.minor.y = element_blank())



read.csv('~/tmp/gld/gmp/78g1/inp_cp__{device_number}__{phase}.csv', colClasses = c('character', 'complex'), header = F) %>%
	mutate(V1 = force_tz(ymd_hms(V1, tz = 'America/New_York')), V2 = Re(V2) / 1000.) %>%
	ggplot(aes(V1, V2)) +
	geom_line() +
	ggtitle("Sample Mixed Residential/Commercial Load") +
	xlab("Local Time") +
	ylab("Active Power (kW)") +
	theme_bw() +
	theme(panel.grid.major.x = element_blank(), panel.grid.minor.x = element_blank()) +
	theme(panel.grid.major.y = element_blank(), panel.grid.minor.y = element_blank())



data.frame(x = 1:373, y = LS_nl$d) %>%
	ggplot(aes(x, y)) +
	geom_line() +
	xlab("Index") +
	ylab("Singular Value") +
	scale_x_continuous(expand = c(0, 0)) +
	scale_y_continuous(expand = c(0, 0)) +
	theme_bw() +
	theme(panel.grid.major.x = element_blank(), panel.grid.minor.x = element_blank()) +
	theme(panel.grid.major.y = element_blank(), panel.grid.minor.y = element_blank())
