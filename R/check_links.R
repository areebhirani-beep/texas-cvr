# Check that every link in the inventory still works, then save the inventory as parquet.
# Run from the repo folder:  Rscript R/check_links.R
# Needs: install.packages("nanoparquet")

inv <- read.csv("data/tx_cvr_inventory.csv", colClasses = "character")

# First try a HEAD request with base R. Some county sites (CivicPlus "DocumentCenter" pages,
# JustFOIA) refuse HEAD, so if that fails, ask curl for the first byte only.
# --max-filesize stops curl from downloading a big file when a server ignores the byte range.
check_url <- function(url) {
  if (url == "") return(c(status = "", bytes = ""))
  h <- tryCatch(curlGetHeaders(url, timeout = 60), error = function(e) NULL)
  if (!is.null(h) && attr(h, "status") == 200) {
    len <- grep("^content-length:", h, ignore.case = TRUE, value = TRUE)
    len <- trimws(sub(".*:", "", tail(len, 1)))
    return(c(status = "200 (HEAD)", bytes = if (length(len) == 1) len else ""))
  }
  # curl exits with an error code when --max-filesize stops it early. That is expected, so the warning is hidden.
  out <- suppressWarnings(system2("curl", c("-s", "-L", "-r", "0-0", "-o", "/dev/null", "--max-filesize", "1000000",
                           "-A", shQuote("Mozilla/5.0"), "-m", "60",
                           "-w", shQuote("%{http_code}|%header{content-length}|%header{content-range}"),
                           shQuote(url)), stdout = TRUE))
  parts <- strsplit(out, "|", fixed = TRUE)[[1]]
  status <- parts[1]
  # A 206 reply says "bytes 0-0/TOTAL", so the full size is after the slash.
  bytes <- if (length(parts) >= 3 && parts[3] != "") sub(".*/", "", parts[3]) else parts[2]
  c(status = paste(status, "(GET first byte)"), bytes = if (is.na(bytes)) "" else bytes)
}

file_checks <- t(sapply(inv$file_url, check_url))
page_checks <- t(sapply(inv$source_page, check_url))

inv$file_status <- file_checks[, "status"]
inv$file_mb_now <- round(as.numeric(file_checks[, "bytes"]) / 1e6, 1)
inv$page_status <- page_checks[, "status"]
inv$size_mb <- as.numeric(inv$size_mb)

print(inv[inv$file_url != "" | inv$source_page != "",
          c("county", "election", "file_status", "file_mb_now", "page_status")], row.names = FALSE)

nanoparquet::write_parquet(inv, "data/tx_cvr_inventory.parquet")
cat("Wrote data/tx_cvr_inventory.parquet with", nrow(inv), "rows\n")
