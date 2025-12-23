#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(readr)
  library(stringr)
  library(jsonlite)
  library(purrr)
})

option_list <- list(
  optparse::make_option(c("-i", "--input-dir"), dest = "input_dir",
                        default = "logs/tactical_trades",
                        help = "Directory containing trade log markdown files."),
  optparse::make_option(c("-o", "--output"), dest = "output",
                        default = "docs/data/trades_narratives.json",
                        help = "Path where the JSON payload will be written.")
)

opts <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

if (!dir.exists(opts$input_dir)) stop("Input directory not found: ", opts$input_dir)
files <- list.files(opts$input_dir, pattern = "\\.md$", full.names = TRUE)
if (length(files) == 0) stop("No markdown files found in ", opts$input_dir)

extract_section <- function(text, section_name) {
  pattern <- paste0("##\\s+", section_name, "\\s*\\n")
  if (!str_detect(text, pattern)) return(NA_character_)
  after <- str_split(text, pattern, n = 2)[[1]][2]
  before <- str_split(after, "\\n##\\s+", n = 2)[[1]][1]
  before <- str_replace_all(before, "\n", " ")
  str_squish(before)
}

parse_md <- function(path) {
  txt <- readr::read_file(path)
  lines <- str_split(txt, "\n")[[1]]

  title_line <- lines[str_detect(lines, "^#")][1]
  title <- title_line %>% str_remove("^#\\s*") %>% str_trim()

  trade_line <- lines[str_detect(lines, regex("Trade ID", ignore_case = TRUE))][1]
  trade_id <- if (!is.na(trade_line)) trade_line %>%
    str_replace_all("[*`]", "") %>%
    str_replace(regex(".*Trade ID:\\s*", ignore_case = TRUE), "") %>%
    str_trim() else NA_character_

  rationale <- extract_section(txt, "Thesis")
  exit_line <- lines[str_detect(lines, regex("Exit rationale", ignore_case = TRUE))]
  exit_decision <- if (length(exit_line)) {
    exit_line[1] %>% str_replace(regex(".*[Ee]xit rationale:\\s*", ignore_case = TRUE), "") %>% str_trim()
  } else {
    section <- extract_section(txt, "Outcome & Review")
    ifelse(is.na(section), NA_character_, section)
  }

  list(
    trade_id = trade_id,
    title = title,
    rationale = rationale,
    exit_decision = exit_decision
  )
}

rows <- purrr::map(files, parse_md) %>% purrr::compact() %>%
  purrr::discard(~ is.null(.x$trade_id) || is.na(.x$trade_id) || .x$trade_id == "")

if (length(rows) == 0) stop("No trade_id values found in markdown files under ", opts$input_dir)

dir.create(dirname(opts$output), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(rows, opts$output, auto_unbox = TRUE, pretty = TRUE)

message("Trade narratives written to ", opts$output)
