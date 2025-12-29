#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(rmarkdown)
  library(fs)
})

args <- commandArgs(trailingOnly = FALSE)
script_path <- grep("^--file=", args, value = TRUE)
script_dir <- tryCatch(
  if (length(script_path)) {
    path_dir(path_real(sub("^--file=", "", script_path[1])))
  } else {
    path_real(".")
  },
  error = function(e) path_real(".")
)

find_rmd <- function() {
  # try relative to script dir (repo layout scripts/R/../..)
  candidates <- c(
    path_norm(path(script_dir, "..", "..", "docs", "index.Rmd")),
    path_norm(path(script_dir, "..", "docs", "index.Rmd")),
    path_norm(path(script_dir, "docs", "index.Rmd")),
    path_norm(path(path_real("."), "docs", "index.Rmd"))
  )
  existing <- candidates[file_exists(candidates)]
  if (length(existing)) return(existing[1])

  # walk up from cwd to find docs/index.Rmd
  cur <- path_real(".")
  for (i in 1:5) {
    candidate <- path(cur, "docs", "index.Rmd")
    if (file_exists(candidate)) return(candidate)
    cur <- path_dir(cur)
    if (cur == path_dir(cur)) break
  }
  NA_character_
}

candidate_rmd <- find_rmd()
if (is.na(candidate_rmd) || !file_exists(candidate_rmd)) {
  stop("Missing Rmd: could not find docs/index.Rmd from script_dir=", script_dir, " or cwd=", path_real("."))
}

render(input = candidate_rmd,
       output_file = "index.html",
       output_dir = path_dir(candidate_rmd),
       quiet = TRUE)

cat("Rendered ", candidate_rmd, " -> ", path(path_dir(candidate_rmd), "index.html"), "\n", sep = "")
