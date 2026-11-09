# texas-cvr

Which Texas counties post cast vote records (CVRs) for the 2022, 2024 and 2026 elections, and what votedatabase.com/cvr/ already has for Texas. I put this together for Shiro Kuriwaki's CVR project. Links were last checked on November 9, 2026.

## Files

| File | What it is |
|---|---|
| `data/tx_cvr_inventory.csv` | One row per county and election with a public CVR, plus counties I checked that post nothing |
| `data/tx_cvr_inventory.parquet` | Same table plus link check results, written by `R/check_links.R` |
| `data/votedatabase_tx_summary.csv` | One row per Texas folder on votedatabase.com/cvr/ |
| `data/cooke_2024_general.parquet` | Cooke County Nov 2024 general CVR, one row per ballot |
| `R/check_links.R` | Checks every link in the inventory and writes the parquet |
| `R/cooke_2024.R` | Downloads, cleans and checks the Cooke file |
| `R/votedatabase_summary.R` | Builds the votedatabase summary from a crawl listing |

## Counties that post CVRs

"P" = March primary, "R" = May primary runoff, "G" = November general. "req" means the county lists the CVR but says to file a public information request.

| County | 2022 P | 2022 R | 2022 G | 2024 P | 2024 R | 2024 G | 2026 P | 2026 R |
|---|---|---|---|---|---|---|---|---|
| Tarrant | zip | zip | zip | zip | zip | zip | zip | zip |
| Parker | | | zip | pdf | | zip | zip | pdf |
| Cooke | | | | xlsx | pdf | xlsx | xlsx | xlsx |
| Bexar | | | csv | xlsx | | zip | | |
| Dallas | | | | xlsx | | xlsx | | |
| Burnet | | | | pdf | pdf | pdf | pdf | |
| Webb | | | | | | pdf | | |
| Hidalgo | | | | pdf | | req | req | |

- Tarrant files are Hart Verity CVRExport zips (the biggest is 2.26 GB for Nov 2024). Parker's 2022 and 2024 generals are the same kind of file.
- Dallas Nov 2024 is 9 xlsx files in a folder called "CVR Redacted".
- Webb Nov 2024 is a single 22,622-page PDF. The PDF ones would need table extraction before they are usable.
- No county has posted the November 3, 2026 general yet (checked November 9, 2026). Tarrant, Dallas, Bexar and Parker are the most likely to post first.

I also checked these counties and found nothing posted for 2022 or later: Harris, Travis (2020 only), Collin, Denton (site blocks bots, partial check), Fort Bend, Montgomery, Williamson, Galveston, Brazoria, El Paso, Cameron, McLennan, Ellis, Bell, Midland, Randall, Comal, Kaufman, Ector, Potter. Rockwall and Hays still need a check by hand.

## What votedatabase.com/cvr/ has for Texas

70 county folders, about 1.88 million files and 41.6 GB. Almost all of it is the November 2020 general. There is nothing for 2024 or 2026.

- Nov 2022 general: Harris (per-ballot PDFs), Bexar (`CVR2022.csv`), Blanco, Brazoria (Hart zip).
- 2022 primaries: Titus, Montgomery, Kerr, plus 11 files in `/cvr/2022Primaries/Texas/`.
- Known errors: `Texas/Bexar/CVR.csv` is actually Andrews County 2020. Erath `CVR 2022.xlsx` is Nov 2020. Tarrant `Tarrant TX.csv` is precinct results, not a CVR. Four folders are misspelled: Burnett, Guadelupe, Hayes, Shackleford.

The `years_in_names` column is a plain text match for 2016 to 2026 in file paths, so treat it as a hint. In Harris, Cass and Nolan the matches are ballot numbers in file names like `2024-cvr.pdf`, not years.

## How to run

From the repo folder, in R 4.x with `readxl` and `nanoparquet` installed:

```
install.packages(c("readxl", "nanoparquet"))
Rscript R/check_links.R
Rscript R/cooke_2024.R
```

`check_links.R` sends a HEAD request to each link. Some county sites refuse HEAD, so for those it asks for the first byte only with curl (needs curl 7.84 or newer) and never downloads a whole file.

`votedatabase_summary.R` needs the crawl listing (`vd_texas.tsv`, date / size / path, about 200 MB), which is not in the repo because of its size: `Rscript R/votedatabase_summary.R path/to/vd_texas.tsv`.

## Cooke County example

`R/cooke_2024.R` reads the Cooke Nov 2024 xlsx (2.6 MB). It has 20,549 rows, one per ballot, which matches "Ballots Cast - Total" in the official canvass. The presidential column matches the canvass exactly: Trump 16,975, Harris 3,310, Oliver 107, Stein 40, undervotes 62. The 53 blank cells plus 2 "Write-in" cells add up to the 55 write-ins in the canvass.

## Data notes

- Texas Election Code 1.012(f) (HB 5180, effective Sept 1, 2023) makes CVRs and ballot images open for public inspection starting the day after the final canvass. Posting them online is voluntary, which is why only a few counties do it.
- SOS Election Advisory 2024-20 (June 6, 2024) tells counties to redact precinct, ballot style or polling place when it could identify a voter. So 2024 and later files can have less geographic detail.
- Bills to require online posting in 2025 (HB 1002, SB 107, HB 999) died in committee.
- `vendor` is filled in only where the file itself shows it (a Hart CVRExport, or Cooke's canvass report made with ES&S Electionware). Otherwise it is blank.
- Rows with `checked` = 2026-11-06 were not rechecked on November 9.
- Raw downloads go in `raw/`, which is not committed.
