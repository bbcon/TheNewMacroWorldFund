#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(rmarkdown)
  library(fs)
})

# Determine repo root based on this script's location, fall back to cwd.
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

repo_root <- path_norm(path(script_dir, "..", ".."))

# Fallback to current working dir if the computed root doesn't contain docs/index.Rmd.
candidate_rmd <- path(repo_root, "docs", "index.Rmd")
if (!file_exists(candidate_rmd)) {
  repo_root <- path_real(".")
  candidate_rmd <- path(repo_root, "docs", "index.Rmd")
}

if (!file_exists(candidate_rmd)) {
  stop("Missing Rmd at ", candidate_rmd)
}

render(input = candidate_rmd,
       output_file = "index.html",
       output_dir = path_dir(candidate_rmd),
       quiet = TRUE)

cat("Rendered ", candidate_rmd, " -> ", path(path_dir(candidate_rmd), "index.html"), "\n", sep = "")
