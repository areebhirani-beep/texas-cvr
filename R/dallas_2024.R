# Dallas County, Nov 5 2024 general election CVR.
# 1. Downloads the 9 county xlsx files (~277 MB) into raw/ and writes data/dallas_2024_manifest.csv
# 2. Writes the vote file in the Harvard Dataverse doi:10.7910/DVN/PQQ3KV layout:
#      out/cvrs/state=TEXAS/county_name=DALLAS/part-0.parquet
# 3. Writes a choice-level metadata file in the layout of Dataverse file 11602209
#    (APSR_item_choice_info, doi:10.7910/DVN/QHGLJS): out/dallas_2024_item_choice_info.tab
# 4. Checks the totals against the official canvass (data/dallas_2024_canvass.csv)
#    and writes data/dallas_2024_validation.csv
# See docs/FORMAT_NOTES.md for the format details and every judgment call.
# Run from the repo folder:  Rscript R/dallas_2024.R   (needs readxl, nanoparquet; ~3 min, ~8 GB RAM)

base <- paste0("https://www.dallascounty.org/elections/Election%20Specific%20Record/2024/",
               "November%20General/6.%20Canvass/Logs%20and%20CVRs/Cast%20Vote%20Records/CVR%20Redacted/")
files <- c("CVR Records.xlsx", paste0("CVR Records - ", 1:8, ".xlsx"))
raw_dir <- "raw/dallas_2024_general"
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("out", showWarnings = FALSE)

# ---- 1. download + manifest -------------------------------------------------
urls <- paste0(base, gsub(" ", "%20", files))
paths <- file.path(raw_dir, files)
for (i in seq_along(files)) if (!file.exists(paths[i])) download.file(urls[i], paths[i], mode = "wb")
sha <- sapply(paths, function(p) sub(" .*", "", system2("shasum", c("-a", "256", shQuote(p)), stdout = TRUE)))
manifest <- data.frame(file = files, url = urls, bytes = file.size(paths), sha256 = unname(sha),
                       downloaded = format(file.mtime(paths), "%Y-%m-%d"))
write.csv(manifest, "data/dallas_2024_manifest.csv", row.names = FALSE)

# ---- 2. read ----------------------------------------------------------------
# Every file has the same 103 columns: Cast Vote Record, Ballot Status, Precinct,
# Ballot Style, then 99 contest columns. Columns 100-102 have no header; they are
# the extra vote-for slots of "University Hills Municipal District Directors" (col 99).
cvr <- do.call(rbind, lapply(paths, readxl::read_excel, col_types = "text", .name_repair = "minimal"))
hdr <- names(cvr)
hdr[100:102] <- hdr[99]
cvr <- cvr[order(as.integer(cvr[[1]])), ]
n_rows <- nrow(cvr)

# A row is one scanned sheet. Hand-marked paper ballots have 2 sheets; the second
# sheet only holds the last City of Dallas props etc. It has no President, no
# Sheriff and no statewide judges (all of which are on every ballot's first sheet).
# The two sheets of one ballot cannot be linked (sheets were scanned in separate
# batches), so sheet 2 stays a separate cvr_id, like PQQ3KV's "unmerged fragments".
sheet2 <- is.na(cvr[[5]]) & is.na(cvr[["Sheriff (4794)"]]) & is.na(cvr[["Justice, Supreme Court, Place 2 (4677)"]])

# ---- contest table (one row per contest column) -------------------------------
contest_cols <- 5:103
title <- trimws(sub("\\s*\\(\\d+\\)$", "", hdr[contest_cols]))
ct <- data.frame(column = contest_cols, title = title, stringsAsFactors = FALSE)
num <- function(s) sub(".*?(\\d+).*", "\\1", s)  # first number in a string
ct$item <- NA; ct$dist <- "."; ct$place <- "."; ct$level <- "S"; ct$nonpartisan <- 0L
ct$measure <- 0L; ct$unexp_term <- 0L; ct$office <- NA; ct$district <- NA
for (i in seq_len(nrow(ct))) {
  t <- ct$title[i]
  if (grepl("^President", t)) { ct[i, c("item", "level", "office", "district")] <- c("US_PRES", "N", "US PRESIDENT", "FEDERAL")
  } else if (grepl("^United States Senator", t)) { ct[i, c("item", "level", "office", "district")] <- c("US_SEN", "N", "US SENATE", "TEXAS")
  } else if (grepl("^United States Representative", t)) { ct[i, c("item", "dist", "level", "office")] <- c("US_REP", num(t), "N", "US HOUSE")
  } else if (grepl("^State Senator", t)) { ct[i, c("item", "dist", "office")] <- c("ST_SEN", num(t), "STATE SENATE")
  } else if (grepl("^State Representative", t)) { ct[i, c("item", "dist", "office")] <- c("ST_REP", num(t), "STATE HOUSE")
  } else if (grepl("^Railroad", t)) { ct$item[i] <- "ST_RR_COMMISS"
  } else if (grepl("^Justice, Supreme Court", t)) { ct[i, c("item", "dist")] <- c("SUPREME COURT JUSTICE", num(t))
  } else if (grepl("^Presiding Judge, Court of Criminal", t)) { ct$item[i] <- "CRIMINAL APPEALS PRESIDING JUDGE"
  } else if (grepl("^Judge, Court of Criminal Appeals", t)) { ct[i, c("item", "dist")] <- c("CRIMINAL APPEALS JUDGE", num(t))
  } else if (grepl("^Member, State Board of Education", t)) { ct[i, c("item", "dist")] <- c("ST_BOE", num(t)); ct$unexp_term[i] <- as.integer(grepl("Unexpired", t))
  } else if (grepl("^Chief Justice, 5th Court", t)) { ct[i, c("item", "dist")] <- c("APPEALS CHIEF JUSTICE", "5")
  } else if (grepl("^Justice, 5th Court", t)) { ct[i, c("item", "dist")] <- c("APPEALS JUSTICE", paste0("5,", sub(".*Place (\\d+).*", "\\1", t)))
  } else if (grepl("^District Judge", t)) { ct[i, c("item", "dist")] <- c("DIST JUDGE", num(t))
  } else if (grepl("^Criminal District Judge", t)) { ct[i, c("item", "dist", "place")] <- c("CRIM DIST JUDGE", num(t), "DALLAS COUNTY")
  } else if (grepl("^Sheriff", t)) { ct[i, c("item", "place", "level")] <- c("CO_SHERIFF", "DALLAS COUNTY", "L")
  } else if (grepl("^County Tax", t)) { ct[i, c("item", "place", "level")] <- c("CO_TAX_ASSESSOR", "DALLAS COUNTY", "L")
  } else if (grepl("^County Commissioner", t)) { ct[i, c("item", "dist", "place", "level")] <- c("CO_COMMISSIONER", num(t), "DALLAS COUNTY", "L")
  } else if (grepl("Propositi?on", t)) {
    letter <- sub(".*Propositi?on\\s+([A-Z])$", "\\1", t)
    who <- trimws(sub("Propositi?on.*", "", sub("^Ci?t?y of ", "", t)))
    who <- sub(" ISD$", " INDEP SCHOOL DIST", sub("Municipal District", "MUNICIPAL DIST", who))
    ct[i, c("item", "place", "level")] <- c(paste0(toupper(who), ", PROP ", letter), toupper(who), "L")
    ct$nonpartisan[i] <- NA; ct$measure[i] <- 1L
  } else if (grepl("Council", t)) {
    who <- toupper(sub(" For .*", "", t))
    ct[i, c("item", "dist", "place", "level")] <- c(paste(who, "COUNCIL"), num(t), who, "L"); ct$nonpartisan[i] <- 1L
  } else if (grepl("^University Hills Municipal District Directors", t)) {
    ct[i, c("item", "place", "level")] <- c("UNIVERSITY HILLS MUNICIPAL DIST DIR", "UNIVERSITY HILLS MUNICIPAL DIST", "L"); ct$nonpartisan[i] <- 1L
  }
}
stopifnot(!anyNA(ct$item))
# PQQ3KV only defines office/district for its six offices. For every other contest
# we use the metadata item name as office (so office == item links the two files)
# and the metadata dist as district (NA when there is none).
ct$office[is.na(ct$office)] <- ct$item[is.na(ct$office)]
ct$district <- ifelse(!is.na(ct$district), ct$district,
                      ifelse(ct$dist != ".", ifelse(ct$item %in% c("US_REP", "ST_SEN", "ST_REP"), sprintf("%03d", suppressWarnings(as.integer(ct$dist))), ct$dist), NA))
ct$contest <- match(paste(ct$item, ct$dist), unique(paste(ct$item, ct$dist)))  # cols 99-102 share one
ct$magnitude <- ave(ct$column, ct$contest, FUN = length)  # vote-for N = number of columns

# ---- long table: one row per ballot x contest choice -------------------------
# Value conventions in the county file:
#   NA            contest not on this sheet, EXCEPT in the 3 contests with declared
#                 write-in candidates (President, US Senate, Railroad Commissioner),
#                 where a blank on a first sheet is a write-in vote (see FORMAT_NOTES)
#   "undervote", "overvote", "Write-in", "No image found", or the candidate name
writein_cols <- which(hdr %in% c("President and Vice President", "United States Senator (4653)", "Railroad Commissioner (4674)"))
long <- lapply(seq_len(nrow(ct)), function(k) {
  j <- ct$column[k]; v <- cvr[[j]]
  if (j %in% writein_cols) v[is.na(v) & !sheet2] <- "Write-in"
  keep <- which(!is.na(v))
  data.frame(row = keep, k = k, raw = v[keep], stringsAsFactors = FALSE)
})
long <- do.call(rbind, long)
long <- long[order(long$row, long$k), ]   # ballot by ballot, contests in ballot order

# choice table: one row per contest x raw value
ch <- unique(long[, c("k", "raw")])
ch$contest <- ct$contest[ch$k]
canv <- read.csv("data/dallas_2024_canvass.csv", na.strings = "", stringsAsFactors = FALSE)
party_short <- c(REP = "REP", DEM = "DEM", LIB = "LBT", GRE = "GRN")
party_long <- c(REP = "REPUBLICAN", DEM = "DEMOCRAT", LIB = "LIBERTARIAN", GRE = "GREEN")
p <- canv$party[match(paste(ct$column[ch$k], ch$raw), paste(canv$column, canv$candidate_cvr))]
ch$party <- unname(party_short[p]); ch$party_detailed <- unname(party_long[p])
ch$party_detailed[ch$raw == "Write-in"] <- "WRITEIN"
clean <- function(s) {
  s <- sub("\\s*\\(\\d+\\)$", "", s)           # county candidate id
  s <- sub("\\s*/.*$", "", s)                   # President only, not the running mate
  s <- toupper(gsub("[.,\"']", "", s))          # PQQ3KV style: DONALD J TRUMP
  gsub("\\s+", " ", trimws(s))
}
ch$candidate <- ifelse(ch$raw %in% c("undervote", "No image found"), "UNDERVOTE",
                ifelse(ch$raw == "overvote", "OVERVOTE",
                ifelse(ch$raw == "Write-in", "WRITEIN", clean(ch$raw))))
long$ch <- match(paste(long$k, long$raw), paste(ch$k, ch$raw))

# ---- 3a. vote parquet (PQQ3KV layout) ----------------------------------------
cvr_id <- as.integer(cvr[[1]])
votes <- data.frame(
  cvr_id         = cvr_id[long$row],
  precinct_medsl = NA_character_,
  precinct_cvr   = cvr[[3]][long$row],
  office         = ct$office[long$k],
  district       = ct$district[long$k],
  candidate      = ch$candidate[long$ch],
  magnitude      = as.character(ct$magnitude[long$k]),
  party          = ch$party[long$ch],
  party_detailed = ch$party_detailed[long$ch],
  stringsAsFactors = FALSE)
pq_dir <- "out/cvrs/state=TEXAS/county_name=DALLAS"
dir.create(pq_dir, recursive = TRUE, showWarnings = FALSE)
nanoparquet::write_parquet(votes, file.path(pq_dir, "part-0.parquet"))

# ---- 3b. choice-level metadata (11602209 layout) ------------------------------
ch$votes <- as.integer(table(factor(long$ch, levels = seq_len(nrow(ch)))))
ch$column <- ct$column[match(ch$contest, ct$contest)]     # first column of the contest
meta <- do.call(rbind, lapply(split(ch, ch$contest), function(d) {
  d <- d[order(tolower(d$raw)), ]                          # choice_id: alphabetical raw value
  d$choice_id <- seq_len(nrow(d))
  d$cand_num <- order(order(-d$votes, d$choice_id))        # rank by votes, 1 = most
  c0 <- ct[match(d$contest[1], ct$contest), ]
  code <- ifelse(d$raw %in% c("undervote", "No image found"), "U", ifelse(d$raw == "overvote", "O", NA))
  if (c0$measure == 1) {
    code[d$raw == "For"] <- "Y"; code[d$raw == "Against"] <- "N"
  } else if (isTRUE(c0$nonpartisan == 1)) {
    real <- which(is.na(code)); top <- real[order(-d$votes[real])]
    code[top[1]] <- "A"; if (length(top) > 1) code[top[2]] <- "B"
  } else {
    code[which(d$party == "REP")] <- "R"; code[which(d$party == "DEM")] <- "D"
  }
  code[is.na(code)] <- as.character(d$cand_num[is.na(code)])
  data.frame(state = "TX", county = "Dallas", item_id = d$contest[1], item_id_2 = d$contest[1],
             item = c0$item, dist = c0$dist, place = c0$place, level = c0$level,
             nonpartisan = c0$nonpartisan, measure = c0$measure, choice_id = d$choice_id,
             choice = code, cand_num = d$cand_num, spending = NA_integer_, topic = NA_character_,
             description = NA_character_, column = d$column, unexp_term = c0$unexp_term,
             yes_orientation = NA_character_, num_votes = c0$magnitude, votes = d$votes,
             votes_choice = as.numeric(d$votes), votes_total = as.numeric(sum(d$votes)),
             D_in_race = as.integer(any(code == "D")), R_in_race = as.integer(any(code == "R")),
             raw = d$raw, candidate = d$candidate, party = d$party, stringsAsFactors = FALSE)
}))
fmt_cols <- c("state", "county", "item_id", "item_id_2", "item", "dist", "place", "level", "nonpartisan",
              "measure", "choice_id", "choice", "cand_num", "spending", "topic", "description", "column",
              "unexp_term", "yes_orientation", "num_votes", "votes", "votes_choice", "votes_total",
              "D_in_race", "R_in_race")
out_meta <- meta[, fmt_cols]
write.table(out_meta, "out/dallas_2024_item_choice_info.tab", sep = "\t", row.names = FALSE, na = "",
            quote = which(sapply(out_meta, is.character)))
# small human-readable crosswalk (choice code -> candidate name) for checking; not part of the format
write.csv(meta[, c("item_id", "item", "dist", "choice_id", "choice", "cand_num", "raw", "candidate", "party", "votes")],
          "data/dallas_2024_choice_crosswalk.csv", row.names = FALSE, na = "")

# ---- 4. validation against the official canvass ------------------------------
# Official: Texas SOS canvass report signed by the Dallas County Clerk, 11/19/2024,
# "Nov 5 2024 Final Canvass (signed sealed).pdf" (scanned; numbers read by OCR).
official_ballots <- 858562   # "Total # of Voters Voted"
n_ballots <- sum(!sheet2)
cat("Rows (sheets):", n_rows, " second sheets:", sum(sheet2), " ballots:", n_ballots,
    " official:", official_ballots, " diff:", n_ballots - official_ballots, "\n")
cat("Vote rows:", nrow(votes), " metadata rows:", nrow(meta), " contests:", length(unique(ct$contest)), "\n")
v <- canv[!is.na(canv$candidate_cvr), ]
v$cvr <- ch$votes[match(paste(v$column, v$candidate_cvr), paste(ct$column[ch$k], ch$raw))]
v$diff <- v$cvr - v$votes_official
val <- rbind(data.frame(contest = "Ballots counted", candidate = "", party = "", cvr = n_ballots, official = official_ballots, diff = n_ballots - official_ballots),
             data.frame(contest = v$contest_canvass, candidate = v$candidate_canvass, party = v$party, cvr = v$cvr, official = v$votes_official, diff = v$diff))
write.csv(val, "data/dallas_2024_validation.csv", row.names = FALSE)
cat("Candidates checked:", nrow(v), " exact:", sum(v$diff == 0), " off:", sum(v$diff != 0), "\n")
print(val[val$diff != 0, ], row.names = FALSE)
