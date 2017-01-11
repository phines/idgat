library(dplyr)
library(tidyr)



# DATA PRE-REQUISITE: No NAs in the data.frame, as svd() shall fail.

M <- read.csv("~/tmp/gld/gmp/78g1/run_2015-july-1st-31st_xfo-to-load-direct/1/node/voltage/SVD.CSV", header = TRUE) %>%
	select(which(colSums(.) / nrow(.) != 7200)) %>% # (removes the "infinite" bus)
	t()



nr <- nrow(M)
nc <- ncol(M)

M_mu <- M %>%
	apply(2, mean) %>%
	rep(each = nr) %>%
	matrix(ncol = nc, dimnames = dimnames(M))

M_sd <- M %>%
	apply(2, sd) %>%
	rep(each = nr) %>%
	matrix(ncol = nc, dimnames = dimnames(M))



L_svd <- ((M - M_mu) / M_sd) %>% # Centered & Normalized (equivalent to scale(M, center = T, scale = T))
	svd()



k  <- 37

(M - ((L_svd %>% mylibs$reassemble_svdout(k = k)) * M_sd + M_mu)) %>%
	as.data.frame() %>%
	gather() %>%
	mutate(x = rep((0:(nr-1) + 1:nr) / 2, times = nc),
	       y = rep((0:(nc-1) + 1:nc) / 2, each  = nr)) %>%
	mylibs$image_plot(
		xlab    = 'node',
		ylab    = 'time',
		cblab   = 'Volts',
		title   = paste('Actual minus SVD ', '(k = ', k, ')', sep = ''),
		palette = 'RdBu')
