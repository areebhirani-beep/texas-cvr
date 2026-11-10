# Builds data/dallas_2024_canvass.csv: official Dallas Nov 2024 results, one row per candidate,
# matched to the candidate spelling used in the CVR file. Run once; the CSV is committed.
# Source: "Nov 5 2024 Final Canvass (signed sealed).pdf" (Texas SOS canvass report signed by the
# Dallas County Clerk on 11/19/2024), a 53-page scan in
# dallascounty.org/elections/Election Specific Record/2024/November General/6. Canvass/Results/
#   Summary Results by City (Not on archive list)/
# The scan has no text layer, so it was OCRed first (poppler + tesseract):
#   pdftoppm -r 200 -png final_canvass_signed.pdf raw/dallas_2024_canvass/ocr/p
#   for f in raw/dallas_2024_canvass/ocr/p-*.png; do tesseract "$f" "${f%.png}" --psm 6; done
# Page 45 misread 611311 as 8344 at 200 dpi; it was re-read at 400 dpi and is typed in below.
# Needs R/dallas_2024.R to have downloaded the xlsx files first.
L <- lapply(list.files("raw/dallas_2024_general", pattern = "xlsx$", full.names = TRUE), readxl::read_excel, col_types = "text", .name_repair = "minimal")
hdr <- names(L[[1]])
ocr <- sprintf("raw/dallas_2024_canvass/ocr/p-%02d.txt", 1:53)
ocr[45] <- NA
pages <- lapply(1:53, function(p) {
  if (p == 45) return(data.frame(page=45, contest_canvass="DISTRICT JUDGE, 95TH JUDICIAL DISTRICT", name="Monica Purdy", party="DEM", votes=611311))
  t <- readLines(ocr[p]); s <- grep("Provisional Votes Counted", t) + 1; e <- grep("DANIELLE", t) - 1
  t <- t[s:e]; t <- t[!grepl("Votes\\s*$", t)]
  title <- sub("^[^A-Z]*", "", t[1]); t <- t[-1]
  m <- regmatches(t, regexec("^(.*\\S)\\s+(REP|DEM|LIB|GRE|WRI)\\s+([0-9]+)\\.?$", t))
  m <- m[lengths(m) == 4]
  data.frame(page=p, contest_canvass=title, name=sapply(m, `[`, 2), party=sapply(m, `[`, 3), votes=as.numeric(sapply(m, `[`, 4)))
})
cv <- do.call(rbind, pages)
x <- do.call(rbind, L)
key <- function(s) toupper(gsub("[^A-Za-z]", "", sub(" \\([0-9]+\\)$", "", sub("\\s*/.*$", "", s))))
out <- list()
for (j in 5:57) {
  v <- unique(x[[j]]); v <- v[!is.na(v) & !v %in% c("undervote","overvote","Write-in","No image found")]
  best <- NA; bs <- -1
  for (p in 1:53) { k <- key(cv$name[cv$page==p]); sc <- sum(apply(adist(key(v), k), 1, min) <= 2); if (sc > bs) { bs <- sc; best <- p } }
  c2 <- cv[cv$page==best,]
  for (i in seq_len(nrow(c2))) {
    hit <- v[adist(key(v), key(c2$name[i]))[,1] <= 2]
    if (c2$party[i] == "WRI") hit <- character(0)
    out[[length(out)+1]] <- data.frame(column=j, contest=hdr[j], canvass_page=best, contest_canvass=c2$contest_canvass[i], candidate_canvass=c2$name[i], candidate_cvr=if (length(hit)==1) hit else NA, party=c2$party[i], votes_official=c2$votes[i])
  }
  if (length(setdiff(v, unlist(lapply(out, function(o) o$candidate_cvr[o$column==j]))))) cat("UNMATCHED", j, setdiff(v, unlist(lapply(out, function(o) o$candidate_cvr[o$column==j]))), "\n")
}
res <- do.call(rbind, out)
cat("pages used:", length(unique(res$canvass_page)), " dup pages:", sum(duplicated(unique(res[,c("column","canvass_page")])$canvass_page)), "\n")
write.csv(res, "data/dallas_2024_canvass.csv", row.names=FALSE, na="")
print(res[, c("column","canvass_page","candidate_canvass","candidate_cvr","party","votes_official")])
