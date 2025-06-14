#' Prunes breakpoints
#' 
#' @param results result.dt A data table combining the breakpoints and distances
#' @return A data table after pruning the noisy breakpoints
#' @export
threshold_dist_values <- function(result.dt) {
  result.dt$zscores <- scale(result.dt$per_chr_dist, center = TRUE, scale = TRUE)
  result.dt <- result.dt[zscores>0,]
  result.dt$zscores <- NULL
  return(result.dt)
}

#' Assign CNV state or CNV value
#' 
#' @param seq_data Sequential data - Counts per bin
#' @param cluster Vector showing segment identity
#' @param uq Upper quantile to trim to calculate the cluster means
#' @param lq Lower quantile to trim to calculate the cluster means
#' @param is_binned If true, report the values as CNV states. If false, report as z-scores. Default = TRUE
#' @return Copy number states for the different segments
#' @export
assign_gainloss <- function(seq_data, cluster, uq=0.9, lq=0.1, is_binned=TRUE) {
  counts.normal <- seq_data / mean(seq_data)
  counts.normal[counts.normal< 0] <- 0
  qus_global <- quantile(seq_data, c(0.01, 0.98))
  # Calculate mean read counts per cluster
  cnmean <- sapply(split(counts.normal,cluster), function(x) {
    qus <- quantile(x, c(lq, uq))
    y <- x[x >= qus[1] & x <= qus[2] & x >= qus_global[1] & x <= qus_global[2]]
    if(sum(y) == 0 | length(y) == 0)
      y <- x
    mean(y)
  })
  #is_binned==TRUE is the original, default behavior of epiAneufinder
  if(is_binned) {
    # Identify clusters/segments with Z scores between -1 and 1
    cnmean_significance <- dplyr::between(scale(cnmean), -1, 1)
    # Collapse these cluster means to the genomic cluster mean to keep multiplicities low
    cnmean[cnmean_significance] <- mean(cnmean)
    cnmean.scaled <- cnmean/mean(cnmean)
    cnmean.scaled[cnmean.scaled > 2] <- 2
    if(min(cnmean.scaled) < 0){
      stop()
    }
    CN.states <- round(cnmean.scaled[as.character(cluster)])
    return(CN.states) 
  } 
  #else
  z.scores <- (cnmean - mean(cnmean)) / sd(cnmean)
  CN.score <- z.scores[as.character(cluster)]
  return(CN.score)

}

