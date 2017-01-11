# Creates an image plot of a data.frame --
# ARGS:
# DF:         the data.frame
# title:      overall plot title
# xlab, ylab: the labels for the x and y axes, respectively
# cblab:      the label to use for colorbar (appears above it)
# palette:    the ColorBrewer palette to use

image_plot <- function(DF,
		       xlab    = 'x',
		       ylab    = 'y',
		       cblab   = 'value',
		       title   = '',
		       palette = 'Spectral') {
	DF %>%
		ggplot(aes(x, y)) +
		geom_raster(aes(fill = value)) +
		ggtitle(title) +
		xlab(xlab) +
		ylab(ylab) +
		scale_x_continuous(expand = c(0, 0), limits = c(0, nr)) +
		scale_y_continuous(expand = c(0, 0), limits = c(0, nc)) +
		scale_fill_distiller(cblab, palette = palette, na.value = 'Grey') +
		theme_classic()
}



# Reassembles the "original" matrix from the u, d, and v matrices returned by svd() --
# ARGS:
# L: the list returned by invoking svd() on a matrix M
# k: the first *k* singular values to use (default: 1)

reassemble_svdout <- function(L,
			      k = 1) {
	L$u[, 1:k] %*% diag(L$d)[1:k, 1:k] %*% t(L$v[, 1:k]) # NOTE: L$u %*% diag(L$d) %*% t(L$v) ~= M
}
