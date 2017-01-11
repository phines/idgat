library(dplyr)
library(Matrix)
library(MASS)



input_file       <- '~/tmp/gld/gmp/78g1/run_2015-july-1st-31st_xfo-to-load-direct/nam.csv'
input_colClasses <- c("integer", "integer", "integer", "integer", "integer", "character")
output_file      <- '~/tmp/gld/gmp/78g1/run_2015-july-1st-31st_xfo-to-load-direct/node-cluster.csv'

how_many_clusters_to_group_the_data_into <- 10 # @k-means

use_eds <- TRUE # Use Electrical Distances? (default: pseudo-inverse of the Laplacian of the "Y-bus")



df <- read.csv(input_file, colClasses = input_colClasses, header = TRUE) %>% as.tbl()

Y   <- NULL
Z   <- NULL
PSZ <- NULL

# Derive the *positive-sequence* representation of the nodal admittance/impedance matrix:
for (str in df[["admittance"]]) {
	v <- -eval(parse(text = str))
	m <- matrix(v, nrow = sqrt(length(v)), byrow = TRUE)
	M <- 1 / m
	Y <- c(Y, lst(m))
	Z <- c(Z, lst(M))
	if (length(v) == 9) { # 3-phase link: Bergen & Vittal (2nd ed), page 473
		z0s <- (M[1,1] + M[2,2] + M[3,3]) / 3 # eq 12.39(1)
		z0m <- (M[2,3] + M[3,1] + M[1,2]) / 3 # eq 12.40(1)
	} else if (length(v) == 4) { # 2-phase link: FUHGEDDABOUTIT!
		z0s <- (M[1,1] + M[2,2]) / 2
		z0m <- (M[2,1] + M[1,2]) / 2
	} else if (length(v) == 1) { # 1-phase link: straightforward
		z0s <- M[1,1]
		z0m <- 0
	}
	psz <- z0s - z0m
	PSZ <- c(PSZ, psz)
}

dimnames(Y)   <- NULL
dimnames(Z)   <- NULL
dimnames(PSZ) <- NULL

DF <- df %>% dplyr::select(-admittance) %>% mutate(Y = Y, Z = Z, PSZ = PSZ, PSY = 1/PSZ)



# Adjacency Matrix (populated with PSYs instead of 1s):
# (Sadly, the Matrix package isn't equipped to store complex elements;
#  so we'll have to store the real and imaginary parts of PSY separately.)
AM_real <- sparseMatrix(i = DF$from_node, j = DF$to_node, x = Re(DF$PSY))
AM_imag <- sparseMatrix(i = DF$from_node, j = DF$to_node, x = Im(DF$PSY))

N = nrow(AM_real) # = ncol(AM_real)

# Degree Matrix:
DM_real <- Diagonal(x = rowSums(AM_real))
DM_imag <- Diagonal(x = rowSums(AM_imag))

# Laplacian Matrix:
LM_real <- DM_real - AM_real
LM_imag <- DM_imag - AM_imag

# Moore-Penrose generalized inverse of LM:
LM.ginv <- ginv(X = as.matrix(LM_real) + as.matrix(LM_imag) * 1i)



if (use_eds) {
	# Electrical Distance Matrix:
	# (Equation 1 from
	#  "Multi-Attribute Partitioning of Power Networks Based on Electrical Distance,"
	#  Cotilla-Sanchez et al., IEEE Trans. Power Systems, Vol. 28, No. 4, November 2103.)
	EDM <- matrix(0+0i, nrow = N, ncol = N)
	for (i in 1:N) {
		for(j in 1:N) {
			EDM[i,j] <- LM.ginv[i,i] - LM.ginv[i,j] - LM.ginv[j,i] + LM.ginv[j,j]
		}
	}
}



# K-Means Clustering on the Real & Imaginary components of LM.ginv (or EDM):
set.seed(9)
KM <- kmeans(x       = if (use_eds) cbind(Re(EDM), Im(EDM)) else cbind(Re(LM.ginv), Im(LM.ginv)),
	     centers = how_many_clusters_to_group_the_data_into,
	     nstart  = ceiling(0.1*N) # (i.e., use as many random sets as ~ 10% of the data)
)



# Save/Report:
write.csv(data.frame(cluster = KM$cluster), file = output_file, quote = F)
KM$size
KM$cluster
round(KM$betweenss / KM$totss, digits = 2)
