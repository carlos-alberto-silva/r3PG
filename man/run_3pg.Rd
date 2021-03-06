% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/3pg.R
\name{run_3pg}
\alias{run_3pg}
\title{Run the 3PG model and return model results}
\usage{
run_3pg(config, climate = NULL, output = NULL)
}
\arguments{
\item{config}{Either the path to a 3PG configuration file OR a list object
with the appropriate structure (see examples/read function).}

\item{climate}{Either the path to a 3PG climate file OR a data.frame object
with the appropriate structure (see examples/read function).}

\item{output}{Optional file path for output.}
}
\value{
A data.frame with model results.
}
\description{
Accepts climate data, species characteristics, and site configuration 
  information and returns model outputs
}
\examples{

}
\seealso{
\link[r3PG]{load_config}.
}
