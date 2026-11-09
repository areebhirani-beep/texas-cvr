# Summarize what votedatabase.com/cvr/ has for Texas, one row per county folder.
# Input: a crawl listing of votedatabase.com/cvr/Texas (tab separated: date, size, path).
# The listing is ~200 MB so it is not in this repo. Pass its location as the first argument:
#   Rscript R/votedatabase_summary.R path/to/vd_texas.tsv

args <- commandArgs(trailingOnly = TRUE)
listing <- if (length(args) > 0) args[1] else "raw/vd_texas.tsv"

vd <- read.delim(listing, header = FALSE, quote = "", comment.char = "",
                 col.names = c("date", "size", "path"), colClasses = "character")

# Rows marked ERR are folders the crawler could not open. In those rows the folder path
# sits in the size column, so move it over. They are counted, not summed.
vd$crawl_error <- vd$date == "ERR"
vd$path[vd$crawl_error] <- vd$size[vd$crawl_error]
vd$size[vd$crawl_error] <- NA
vd$size <- as.numeric(vd$size)

# County folder = the part after /cvr/Texas/. Files sitting directly in /cvr/Texas/ get "(top level)".
parts <- strsplit(vd$path, "/", fixed = TRUE)
vd$county <- vapply(parts, function(x) if (length(x) >= 5) x[4] else "(top level)", "")
vd$county[startsWith(vd$path, "/cvr/2022Primaries/Texas")] <- "(2022Primaries/Texas folder)"

# Years that show up in file or folder names. Long hex ids are removed first so they do not create fake years.
no_ids <- gsub("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", "", vd$path)
vd$years <- regmatches(no_ids, gregexpr("(?<![0-9])20(1[6-9]|2[0-6])(?![0-9])", no_ids, perl = TRUE))

# Year each file was uploaded to votedatabase, taken from the date column (like "9/8/2022 2:52 AM").
vd$upload_year <- sub("^[0-9]+/[0-9]+/([0-9]{4}).*$", "\\1", vd$date)

ok <- vd[!vd$crawl_error, ]
counties <- sort(unique(vd$county))

summary_rows <- lapply(counties, function(cty) {
  files <- ok[ok$county == cty, ]
  years <- sort(unique(unlist(files$years)))
  data.frame(
    county = cty,
    n_files = nrow(files),
    total_mb = round(sum(files$size, na.rm = TRUE) / 1e6, 1),
    years_in_names = paste(years, collapse = " "),
    upload_years = paste(sort(unique(files$upload_year)), collapse = " "),
    n_crawl_errors = sum(vd$crawl_error & vd$county == cty),
    notes = ""
  )
})
out <- do.call(rbind, summary_rows)

# Known problems with the files on votedatabase (checked by hand, see README).
known <- c(
  Bexar = "Bexar/CVR.csv is actually Andrews County Nov 2020 (Biden 849 matches Andrews). CVR2022.csv is Nov 2022 general.",
  Erath = "\"CVR 2022.xlsx\" is the Nov 2020 general, not 2022.",
  Tarrant = "\"Tarrant TX.csv\" is precinct results, not a CVR.",
  Burnett = "Misspelled folder: should be Burnet.",
  Guadelupe = "Misspelled folder: should be Guadalupe.",
  Hayes = "Misspelled folder: should be Hays.",
  Shackleford = "Misspelled folder: should be Shackelford.",
  Harris = "Per-ballot PDFs named <number>-cvr.pdf, so the year matches are ballot numbers, not years. My Nov 6 notes say this is the Nov 2022 general (not rechecked file by file).",
  Cass = "Per-ballot files named <number>-precinctcvr.pdf, so the year matches are ballot numbers, not years.",
  Blanco = "cvr.csv is the Nov 2022 general (per my Nov 6 notes).",
  Brazoria = "Nov 2022 general Hart CVR zip plus unzipped vDrives; the crawler could not open 67 subfolders.",
  Titus = "2022 primary CVRExport zips.",
  Montgomery = "Folder \"2015 - 2022 CVRs\" includes the 2022 primary.",
  Kerr = "2022 primary and runoff zips; the primary zip may be corrupt.",
  Nolan = "Per-ballot files named <number>c.pdf, so the year matches are ballot numbers. Ballot image zip is the 2020 general."
)
for (cty in names(known)) out$notes[out$county == cty] <- known[[cty]]

write.csv(out, "data/votedatabase_tx_summary.csv", row.names = FALSE)
cat("Wrote", nrow(out), "rows to data/votedatabase_tx_summary.csv\n")
cat("Files:", sum(out$n_files), " Total GB:", round(sum(out$total_mb) / 1000, 1), "\n")
