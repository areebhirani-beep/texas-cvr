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
| `R/dallas_2024.R` | Dallas Nov 2024 pipeline: download, vote parquet, metadata file, canvass check |
| `R/dallas_2024_canvass_ocr.R` | Turns the OCR of Dallas's signed canvass into `data/dallas_2024_canvass.csv` |
| `data/dallas_2024_manifest.csv` | URL, size, sha256 and download date of the 9 Dallas files |
| `data/dallas_2024_canvass.csv` | Official Dallas Nov 2024 results per candidate, matched to the CVR spelling |
| `data/dallas_2024_validation.csv` | CVR totals vs. the official canvass |
| `data/dallas_2024_choice_crosswalk.csv` | Metadata choice codes next to the candidate names, for checking |
| `data/verified_voting_2024_tx.csv` | Verified Voting 2024 equipment rows for the 8 counties with public CVRs |
| `docs/FORMAT_NOTES.md` | The two Dataverse formats copied, and every judgment call |
| `CHECKLIST.md` | What to check by hand before sending anything |

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
Rscript R/dallas_2024.R
```

`check_links.R` sends a HEAD request to each link. Some county sites refuse HEAD, so for those it asks for the first byte only with curl (needs curl 7.84 or newer) and never downloads a whole file.

`votedatabase_summary.R` needs the crawl listing (`vd_texas.tsv`, date / size / path, about 200 MB), which is not in the repo because of its size: `Rscript R/votedatabase_summary.R path/to/vd_texas.tsv`.

## Cooke County example

`R/cooke_2024.R` reads the Cooke Nov 2024 xlsx (2.6 MB). It has 20,549 rows, one per ballot, which matches "Ballots Cast - Total" in the official canvass. The presidential column matches the canvass exactly: Trump 16,975, Harris 3,310, Oliver 107, Stein 40, undervotes 62. The 53 blank cells plus 2 "Write-in" cells add up to the 55 write-ins in the canvass.

## Dallas County, November 2024 general

`R/dallas_2024.R` downloads the 9 county xlsx files (277 MB) into `raw/`, then writes two files in the formats of Prof. Kuriwaki's Dataverse releases (details in `docs/FORMAT_NOTES.md`):

| Output | Format copied | Rows |
|---|---|---|
| `out/cvrs/state=TEXAS/county_name=DALLAS/part-0.parquet` (190 MB) | doi:10.7910/DVN/PQQ3KV: long, one row per ballot x contest, 9 columns `cvr_id, precinct_medsl, precinct_cvr, office, district, candidate, magnitude, party, party_detailed` | 32,042,797 |
| `out/dallas_2024_item_choice_info.tab` | Dataverse file 11602209 (`APSR_item_choice_info`): one row per contest x choice, same 25 columns | 308 (96 contests) |

`out/` is not committed because of its size. Run it from the repo folder with `Rscript R/dallas_2024.R` (about 1 minute after the download, needs about 8 GB of RAM).

Checked against the official canvass (Texas SOS canvass report signed by the County Clerk on November 19, 2024, read by OCR):

- Ballots: the file has 873,455 rows, but 14,893 of them are the second sheet of two-sheet paper ballots. That leaves 858,562 ballots, the same as the canvass "Total # of Voters Voted".
- 85 of 96 candidate totals match exactly. That covers all 6 US House races, all 3 state senate and 14 state house races, every judge, Sheriff, Tax Assessor and both commissioners.
- The other 11 are President, US Senate and Railroad Commissioner, the three races with write-in candidates. The CVR is short by exactly the write-in votes cast for a listed candidate, which the canvass adds to that candidate (Trump -101, Harris -91, Stein -5, Cruz -31, Allred -42, Brown -8, and all 4 Railroad candidates). Those numbers match the write-in lines in the county's unofficial final report. The one I cannot explain is Chase Oliver, short by 1.
- President in the CVR: Trump 322,468, Harris 511,027, Stein 8,983, Oliver 6,272, write-in 4,578, undervote 5,221, overvote 13.
- Local propositions and city council races are not in the SOS canvass, so they have not been checked.

Two judgment calls matter most. First, the second sheets cannot be linked to their first sheet, so they keep their own `cvr_id`. Second, blank cells in the three write-in races are coded WRITEIN. I think the county blanked write-in names when it redacted the file, but that is my inference. Both are explained in `docs/FORMAT_NOTES.md` and listed in `CHECKLIST.md`.

## AI use

Claude Code (Anthropic's AI coding tool) wrote the Dallas pipeline, the format notes, the vendor column and this section on November 9, 2026. I have started checking that work by hand: on November 10, 2026 I read through both Dallas R scripts, and I confirmed the total ballots (858,562) and the Trump (322,569) and Harris (511,118) totals against the signed canvass PDF. `CHECKLIST.md` lists the rest of what I will check, and I will update the second column below as I go.

| File | Status |
|---|---|
| `README.md` | Dallas, vendor and AI use sections: AI-generated (Claude Code), not yet manually checked. Rest: from the earlier commit, authorship not recorded here |
| `.gitignore` | AI-generated (Claude Code), not yet manually checked |
| `CHECKLIST.md` | AI-generated (Claude Code), not yet manually checked |
| `docs/FORMAT_NOTES.md` | AI-generated (Claude Code), not yet manually checked |
| `R/dallas_2024.R` | AI-generated (Claude Code), manually reviewed by Areeb on Nov 10, 2026 |
| `R/dallas_2024_canvass_ocr.R` | AI-generated (Claude Code), manually reviewed by Areeb on Nov 10, 2026 |
| `data/dallas_2024_manifest.csv` | AI-generated (Claude Code), not yet manually checked |
| `data/dallas_2024_canvass.csv` | AI-generated (Claude Code) from OCR. Total ballots, Trump and Harris rows manually checked by Areeb on Nov 10, 2026; other rows not yet checked |
| `data/dallas_2024_validation.csv` | AI-generated (Claude Code), not yet manually checked |
| `data/dallas_2024_choice_crosswalk.csv` | AI-generated (Claude Code), not yet manually checked |
| `data/verified_voting_2024_tx.csv` | AI-generated (Claude Code), not yet manually checked |
| `data/tx_cvr_inventory.csv` | `vendor` and `vendor_evidence` columns: AI-generated (Claude Code), not yet manually checked. Other columns: from the earlier commit, authorship not recorded here |
| `data/tx_cvr_inventory.parquet` | From the earlier commit, authorship not recorded here |
| `data/votedatabase_tx_summary.csv` | From the earlier commit, authorship not recorded here |
| `data/cooke_2024_general.parquet` | From the earlier commit, authorship not recorded here |
| `R/check_links.R` | From the earlier commit, authorship not recorded here |
| `R/cooke_2024.R` | From the earlier commit, authorship not recorded here |
| `R/votedatabase_summary.R` | From the earlier commit, authorship not recorded here |

When a file has been checked, change its status to "AI-generated, manually checked by Areeb on <date>". Use "written by Areeb" only for files written by hand.

## Data notes

- Texas Election Code 1.012(f) (HB 5180, effective Sept 1, 2023) makes CVRs and ballot images open for public inspection starting the day after the final canvass. Posting them online is voluntary, which is why only a few counties do it.
- SOS Election Advisory 2024-20 (June 6, 2024) tells counties to redact precinct, ballot style or polling place when it could identify a voter. So 2024 and later files can have less geographic detail.
- Bills to require online posting in 2025 (HB 1002, SB 107, HB 999) died in committee.
- `vendor` is now filled in for the 8 counties with public CVRs, and `vendor_evidence` says what it rests on. Dallas, Bexar, Cooke (ES&S) and Tarrant, Parker, Hidalgo (Hart) are backed by the files themselves plus Verified Voting. Webb (ES&S) and Burnet (Hart) rest on Verified Voting alone and are marked unconfirmed. `data/tx_cvr_inventory.parquet` has not been rebuilt since, so it does not have `vendor_evidence` yet.
- Rows with `checked` = 2026-11-06 were not rechecked on November 9.
- Raw downloads go in `raw/`, which is not committed.
