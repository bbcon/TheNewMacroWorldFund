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
  str_trim(before)
}

extract_label_value <- function(lines, label_regex) {
  pattern <- regex(paste0("^\\s*[-*]\\s*(?:\\*\\*)?", label_regex, "(?:\\*\\*)?\\s*:\\s*"),
                   ignore_case = TRUE)
  match <- lines[str_detect(lines, pattern)]
  if (!length(match)) return(NA_character_)
  str_trim(str_replace(match[1], pattern, ""))
}

parse_md <- function(path) {
  txt <- readr::read_file(path)
  lines <- str_split(txt, "\n")[[1]]

  title_line <- lines[str_detect(lines, "^#")][1]
  title <- title_line %>% str_remove("^#\\s*") %>% str_trim()

  trade_line <- extract_label_value(lines, "Trade ID")
  trade_id <- ifelse(is.na(trade_line), NA_character_, trade_line %>% str_replace_all("[*`]", "") %>% str_trim())

  entry_line <- extract_label_value(lines, "Entry Date")
  entry_date <- ifelse(is.na(entry_line), NA_character_, entry_line %>% str_replace_all("[*`]", "") %>% str_trim())

  exit_line <- extract_label_value(lines, "Exit Date")
  exit_date <- ifelse(is.na(exit_line), NA_character_, exit_line %>% str_replace_all("[*`]", "") %>% str_trim())

  rationale <- extract_section(txt, "Thesis")
  exit_decision <- extract_label_value(lines, "Exit rationale")
  exit_decision <- if (!is.na(exit_decision)) {
    exit_decision
  } else {
    section <- extract_section(txt, "Outcome & Review")
    ifelse(is.na(section), NA_character_, section)
  }

  key_takeaways <- extract_label_value(lines, "Key takeaways")
  learning_outcomes <- extract_label_value(lines, "Learning outcome[s]?")

  list(
    trade_id = trade_id,
    title = title,
    rationale = rationale,
    exit_decision = exit_decision,
    entry_date = entry_date,
    exit_date = exit_date,
    key_takeaways = key_takeaways,
    learning_outcomes = learning_outcomes
  )
}

rows <- purrr::map(files, parse_md) %>% purrr::compact() %>%
  purrr::discard(~ is.null(.x$trade_id) || is.na(.x$trade_id) || .x$trade_id == "")

if (length(rows) == 0) stop("No trade_id values found in markdown files under ", opts$input_dir)

dir.create(dirname(opts$output), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(rows, opts$output, auto_unbox = TRUE, pretty = TRUE)

message("Trade narratives written to ", opts$output)
