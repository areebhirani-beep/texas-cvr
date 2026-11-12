# texas-cvr

This repo is my work for Professor Shiro Kuriwaki's cast vote record (CVR) project, and it keeps track of which Texas counties post their CVRs online for the 2022, 2024 and 2026 elections, what votedatabase.com/cvr/ already has for Texas, and the pipelines that turn the county files into the formats from Professor Kuriwaki's Dataverse releases. I last checked all of the links on November 9, 2026.

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

In the table below, "P" is the March primary, "R" is the May primary runoff and "G" is the November general, and "req" means that the county lists the CVR but says that you have to file a public information request to get it.

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

- The Tarrant files are Hart Verity CVRExport zips, and the biggest one is 2.26 GB for November 2024, and Parker's 2022 and 2024 generals are the same kind of file.
- Dallas posted November 2024 as 9 xlsx files in a folder called "CVR Redacted".
- Webb posted November 2024 as a single 22,622-page PDF, and from what I can tell all of the PDF counties would need table extraction before their files are usable.
- No county had posted the November 3, 2026 general yet when I checked on November 9, 2026, and I think Tarrant, Dallas, Bexar and Parker are the most likely to post it first.

I also checked these counties and did not find anything posted for 2022 or later: Harris, Travis (2020 only), Collin, Denton (the site blocks bots, so this was only a partial check), Fort Bend, Montgomery, Williamson, Galveston, Brazoria, El Paso, Cameron, McLennan, Ellis, Bell, Midland, Randall, Comal, Kaufman, Ector and Potter, and I still need to check Rockwall and Hays by hand.

## What votedatabase.com/cvr/ has for Texas

There are 70 Texas county folders with about 1.88 million files and 41.6 GB in total, and almost all of it is from the November 2020 general, with nothing at all for 2024 or 2026.

- For the November 2022 general, there is Harris (per-ballot PDFs), Bexar (`CVR2022.csv`), Blanco and Brazoria (a Hart zip).
- For the 2022 primaries, there is Titus, Montgomery and Kerr, plus 11 files in `/cvr/2022Primaries/Texas/`.
- I found a few errors in the folders, which are that `Texas/Bexar/CVR.csv` is actually Andrews County's 2020 data, Erath's `CVR 2022.xlsx` is really from November 2020, and Tarrant's `Tarrant TX.csv` is precinct results and not a CVR, and four of the folder names are also misspelled (Burnett, Guadelupe, Hayes and Shackleford).

The `years_in_names` column is just a plain text match for the years 2016 to 2026 in the file paths, so I would treat it as a hint and not a fact, because in Harris, Cass and Nolan the matches are actually ballot numbers in file names like `2024-cvr.pdf` and not years.

## How to run

From the repo folder, in R 4.x with `readxl` and `nanoparquet` installed, you can run these commands:

```
install.packages(c("readxl", "nanoparquet"))
Rscript R/check_links.R
Rscript R/cooke_2024.R
Rscript R/dallas_2024.R
```

`check_links.R` sends a HEAD request to each link, but some county sites refuse HEAD requests, so for those sites it asks for only the first byte with curl (which needs curl 7.84 or newer), and it never downloads a whole file.

`votedatabase_summary.R` needs the crawl listing (`vd_texas.tsv`, with the date, size and path of each file, about 200 MB), which is not in the repo because of its size, and you can run it with `Rscript R/votedatabase_summary.R path/to/vd_texas.tsv`.

## Cooke County example

`R/cooke_2024.R` reads the Cooke November 2024 xlsx file (2.6 MB), which has 20,549 rows with one row per ballot, and that matches "Ballots Cast - Total" in the official canvass. The presidential column also matches the canvass exactly, with Trump at 16,975, Harris at 3,310, Oliver at 107, Stein at 40 and 62 undervotes, and the 53 blank cells plus the 2 "Write-in" cells add up to the 55 write-ins in the canvass.

## Dallas County, November 2024 general

`R/dallas_2024.R` downloads the 9 county xlsx files (277 MB) into `raw/`, and then it writes two files that follow the formats of Professor Kuriwaki's Dataverse releases, which I explain in more detail in `docs/FORMAT_NOTES.md`:

| Output | Format copied | Rows |
|---|---|---|
| `out/cvrs/state=TEXAS/county_name=DALLAS/part-0.parquet` (190 MB) | doi:10.7910/DVN/PQQ3KV: long, one row per ballot x contest, 9 columns `cvr_id, precinct_medsl, precinct_cvr, office, district, candidate, magnitude, party, party_detailed` | 32,042,797 |
| `out/dallas_2024_item_choice_info.tab` | Dataverse file 11602209 (`APSR_item_choice_info`): one row per contest x choice, same 25 columns | 308 (96 contests) |

`out/` is not committed because of its size, and you can run the pipeline from the repo folder with `Rscript R/dallas_2024.R`, which takes about 1 minute after the download and needs about 8 GB of RAM.

I checked the output against the official canvass, which is the Texas SOS canvass report signed by the County Clerk on November 19, 2024, and I read it in with OCR:

- The file has 873,455 rows, but 14,893 of them are the second sheet of two-sheet paper ballots, which leaves 858,562 ballots, and that is the same as "Total # of Voters Voted" in the canvass.
- 85 of the 96 candidate totals match exactly, which covers all 6 US House races, all 3 state senate races, all 14 state house races, every judge, the Sheriff, the Tax Assessor and both commissioners.
- The other 11 are in President, US Senate and Railroad Commissioner, which are the three races with write-in candidates, and in those races the CVR is short by exactly the write-in votes cast for a listed candidate, which the canvass adds back to that candidate (Trump -101, Harris -91, Stein -5, Cruz -31, Allred -42, Brown -8, and all 4 Railroad candidates). Those numbers match the write-in lines in the county's unofficial final report, and the one difference that I still cannot explain is Chase Oliver, who is short by 1.
- For President, the CVR has Trump at 322,468, Harris at 511,027, Stein at 8,983, Oliver at 6,272, write-ins at 4,578, undervotes at 5,221 and overvotes at 13.
- Local propositions and city council races are not in the SOS canvass, so I have not checked those yet.

There are two judgment calls that I think matter the most. The first is that the second sheets cannot be linked back to their first sheet, so they keep their own `cvr_id`, and the second is that blank cells in the three write-in races are coded as WRITEIN, because I believe the county blanked out the write-in names when it redacted the file, although that is my own inference. Both of these are explained in `docs/FORMAT_NOTES.md` and listed in `CHECKLIST.md`.

## AI use

Claude Code, which is Anthropic's AI coding tool, generated all of the code and data files in this repo, starting with the county inventory, the votedatabase summary and the Cooke example on the morning of November 9, 2026, and then the Dallas pipeline, the format notes, the vendor column and the first version of this section later that day. I have read through and reviewed all of the R code myself, starting with the two Dallas scripts on November 10, 2026 and finishing the rest by November 12, 2026, and on November 10 I also confirmed the total ballots (858,562) and the Trump (322,569) and Harris (511,118) totals against the signed canvass PDF. I have not finished checking the data files and docs yet, so `CHECKLIST.md` lists the rest of what I am going to check, and I will update the table below as I go.

| File | Status |
|---|---|
| `README.md` | AI-generated (Claude Code), not yet manually checked |
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
| `data/tx_cvr_inventory.csv` | AI-generated (Claude Code), not yet manually checked |
| `data/tx_cvr_inventory.parquet` | AI-generated (Claude Code), not yet manually checked |
| `data/votedatabase_tx_summary.csv` | AI-generated (Claude Code), not yet manually checked |
| `data/cooke_2024_general.parquet` | AI-generated (Claude Code), not yet manually checked |
| `R/check_links.R` | AI-generated (Claude Code), manually reviewed by Areeb by Nov 12, 2026 |
| `R/cooke_2024.R` | AI-generated (Claude Code), manually reviewed by Areeb by Nov 12, 2026 |
| `R/votedatabase_summary.R` | AI-generated (Claude Code), manually reviewed by Areeb by Nov 12, 2026 |

When I finish checking a file, I change its status to "AI-generated, manually checked by Areeb on <date>", and I only use "written by Areeb" for files that I wrote by hand.

## Data notes

- Texas Election Code 1.012(f) (HB 5180, effective September 1, 2023) makes CVRs and ballot images open for public inspection starting the day after the final canvass, but posting them online is voluntary, which is why only a few counties do it.
- SOS Election Advisory 2024-20 (June 6, 2024) tells counties to redact the precinct, ballot style or polling place when it could identify a voter, so the 2024 and later files can have less geographic detail.
- The bills that would have required online posting in 2025 (HB 1002, SB 107 and HB 999) all died in committee.
- `vendor` is now filled in for the 8 counties with public CVRs, and `vendor_evidence` says what each one is based on. Dallas, Bexar and Cooke (ES&S) and Tarrant, Parker and Hidalgo (Hart) are backed by the files themselves plus Verified Voting, but Webb (ES&S) and Burnet (Hart) are based on Verified Voting alone, so I marked them as unconfirmed, and I have not rebuilt `data/tx_cvr_inventory.parquet` since then, so it does not have `vendor_evidence` yet.
- The rows with `checked` = 2026-11-06 were not rechecked on November 9.
- Raw downloads go in `raw/`, which is not committed to the repo.
