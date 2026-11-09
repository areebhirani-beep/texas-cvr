# One full example: Cooke County, Nov 5 2024 general election CVR.
# Downloads the county's xlsx (2.6 MB), cleans the column names, saves it as parquet,
# and checks the presidential totals against the county's official canvass.
# Run from the repo folder:  Rscript R/cooke_2024.R
# Needs: install.packages(c("readxl", "nanoparquet"))

url <- "https://newtools.cira.state.tx.us/upload/page/3107/docs/2024/November5/Cast_Vote_Record_November_5_2024.xlsx"
xlsx <- "raw/cooke_2024_general.xlsx"

dir.create("raw", showWarnings = FALSE)
if (!file.exists(xlsx)) download.file(url, xlsx, mode = "wb")

# One sheet, one row per ballot, one column per contest. Read everything as text
# so readxl does not guess types. The 35th column has no header in the county file.
cvr <- readxl::read_excel(xlsx, col_types = "text", .name_repair = "minimal")

# Clean column names: lower case, anything that is not a letter or number becomes "_".
# "President/Vice President (132)" becomes "president_vice_president_132".
nm <- tolower(names(cvr))
nm <- gsub("[^a-z0-9]+", "_", nm)
nm <- gsub("^_|_$", "", nm)
nm[nm == ""] <- paste0("unnamed_col_", which(nm == ""))
names(cvr) <- nm

cvr$county <- "Cooke"
cvr$election <- "2024-11 general"

dir.create("data", showWarnings = FALSE)
nanoparquet::write_parquet(cvr, "data/cooke_2024_general.parquet")

cat("Ballots (rows):", nrow(cvr), "\n")
cat("Columns:", ncol(cvr), "\n\n")

# Presidential totals. A blank cell shows up as NA; in this file those line up with write-ins.
pres_col <- grep("^president", names(cvr), value = TRUE)
if (length(pres_col) == 1) {
  totals <- table(cvr[[pres_col]], useNA = "ifany")
  print(sort(totals, decreasing = TRUE))

  # Official totals from the county's Final Official Summary Results (Nov 13 2024):
  # newtools.cira.state.tx.us/upload/page/3107/docs/2024/November5/CookeCountyFinalOfficialSummaryResultsGeneral_November_5_2024.pdf
  official <- c("REP Donald J. Trump/JD Vance (1)" = 16975,
                "DEM Kamala D. Harris/Tim Walz (2)" = 3310,
                "LIB Chase Oliver/Mike ter Maat (3)" = 107,
                "GRN Jill Stein/Rudolph Ware (4)" = 40,
                "undervote" = 62)
  check <- data.frame(choice = names(official),
                      cvr = as.numeric(totals[names(official)]),
                      official = official, row.names = NULL)
  check$match <- check$cvr == check$official
  cat("\nCVR vs official canvass:\n")
  print(check, row.names = FALSE)
}
