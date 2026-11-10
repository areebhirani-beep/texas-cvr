# Target formats for the Dallas 2024 files

AI-generated (Claude Code), pending Areeb's manual check. Everything below was read from the Dataverse API on November 9, 2026. Only small files were downloaded: the README, usage notes, data descriptor and one or two county partitions read out of `cvrs.zip` with HTTP range requests.

## (a) Choice-level metadata: Dataverse file 11602209

`https://dataverse.harvard.edu/api/access/datafile/11602209` is `APSR_item_choice_info.tab`, in doi:10.7910/DVN/QHGLJS ("Replication Data for: How Partisan Are U.S. Local Elections? Evidence from 2020 Cast Vote Records"). The original is Stata (`.dta`, release 118); Dataverse serves it as tab-separated text with strings in double quotes. 61,840 rows, one per contest x choice x county. Columns, in order, with the Stata storage type read from the `.dta` header:

| # | column | type | # | column | type |
|---|---|---|---|---|---|
| 1 | state | str2 | 14 | spending | byte |
| 2 | county | str15 | 15 | topic | str32 |
| 3 | item_id | int | 16 | description | str77 |
| 4 | item_id_2 | int | 17 | column | int |
| 5 | item | str56 | 18 | unexp_term | byte |
| 6 | dist | str16 | 19 | yes_orientation | str4 |
| 7 | place | str50 | 20 | num_votes | byte |
| 8 | level | str1 | 21 | votes | long |
| 9 | nonpartisan | byte | 22 | votes_choice | float |
| 10 | measure | byte | 23 | votes_total | float |
| 11 | choice_id | int | 24 | D_in_race | byte |
| 12 | choice | str3 | 25 | R_in_race | byte |
| 13 | cand_num | int | | | |

Value conventions, taken from the replication README (`00_README.pdf`) and from the 2020 Dallas rows in the file itself (Dallas is one of the 46 Texas counties in it):

- `state` = "TX", `county` = "Dallas" (multi-word counties use `_`, e.g. "Fort_Bend").
- `item`: "US_PRES", "US_SEN", "US_REP", "ST_SEN", "ST_REP", "ST_BOE", "ST_RR_COMMISS", "SUPREME COURT JUSTICE", "CRIMINAL APPEALS JUDGE", "APPEALS CHIEF JUSTICE", "APPEALS JUSTICE", "DIST JUDGE", "CRIM DIST JUDGE", "CO_SHERIFF", "CO_TAX_ASSESSOR", "CO_COMMISSIONER"; measures are "<PLACE>, PROP <letter>" (e.g. "DALLAS INDEP SCHOOL DIST, PROP A"); local offices are e.g. "GARLAND CITY COUNCIL", "COPPELL COUNCIL".
- `dist`: "." when there is none. District numbers are not zero-padded ("24", "100"). Appeals justices are "court,place" ("5,3"). Supreme Court / CCA seats use the place number.
- `place`: "." for state and federal offices, "DALLAS COUNTY" for county offices and Criminal District Judge, the city / ISD name for local contests and measures.
- `level`: N (national), S (state, including district and criminal district judges), L (local and county).
- `nonpartisan`: 0 partisan, 1 nonpartisan, missing for measures. `measure`: 1 for ballot measures.
- `choice`: "D" / "R" for the Democratic / Republican candidate; "A" / "B" for the top two vote-getters in a nonpartisan contest; "Y" / "N" for a measure; "U" = undervote; "O" = overvote; any other candidate gets its `cand_num` as text ("3", "5", ...).
- `cand_num`: rank of the choice by votes in the contest, 1 = most votes, undervotes and overvotes included in the ranking.
- `choice_id`: 1..k within the county's contest. In the 2020 Dallas rows it follows alphabetical order of the raw CVR value (e.g. ST_REP 103: Fortenberry = 1, overvote = 2, Anchia = 3, undervote = 4).
- `column`: column number of the contest in the county's raw CVR file.
- `votes` = votes for the choice in this county; `votes_choice` = same choice summed across counties; `votes_total` = all choices in the contest (including U and O).
- `spending`, `topic`, `description`, `yes_orientation` are hand-coded by the authors for ballot measures.
- The paper's universe only keeps contests it could merge with national partisanship and with at least 100 votes.

## (b) Vote file: doi:10.7910/DVN/PQQ3KV

Dataset version 3.0. Files: `cvrs.zip` (548.5 MB), `county_info.xlsx`, `data-descriptor.pdf`, `README.md`, `usage-notes.qmd`, `usage-notes.R`. `cvrs.zip` is a hive-partitioned parquet database:

```
release/state=TEXAS/county_name=COOKE/part-0.parquet
release/state=TEXAS/county_name=FORT%20BEND/part-0.parquet
...
```

`state` and `county_name` exist only as partition folders (upper case, spaces URL-encoded). Dallas and Tarrant are not in the release. Schema of `state=TEXAS/county_name=COOKE/part-0.parquet` and `.../COLLIN/part-0.parquet` (written by parquet-cpp-arrow 16.1.0), all columns OPTIONAL:

| column | parquet type | example |
|---|---|---|
| cvr_id | INT32 | 15506 |
| precinct_medsl | STRING | "0970022" |
| precinct_cvr | STRING | "Pct. 22" |
| office | STRING | "US PRESIDENT" |
| district | STRING | "FEDERAL" |
| candidate | STRING | "DONALD J TRUMP" |
| magnitude | STRING | "1" |
| party | STRING | "REP" |
| party_detailed | STRING | "REPUBLICAN" |

- Long format: one row per ballot x contest. Cooke 2020 = 76,427 rows for 19,119 ballots.
- Only six offices: "US PRESIDENT" (district "FEDERAL"), "US SENATE" (district "TEXAS"), "US HOUSE", "STATE SENATE", "STATE HOUSE" (district zero-padded to 3 digits, "013", "068"), and GOVERNOR in states that had one.
- `candidate`: upper case, punctuation dropped ("MARY MJ HEGAR"), President only (no running mate). Invalid votes are "UNDERVOTE", "OVERVOTE", "WRITEIN".
- `party`: DEM, REP, LBT, GRN, OTH; `party_detailed`: DEMOCRAT, REPUBLICAN, LIBERTARIAN, GREEN, INDEPENDENT. Both missing for UNDERVOTE / OVERVOTE. For WRITEIN, `party` is missing and `party_detailed` is "WRITEIN" (Collin 2020: 188 rows).
- `cvr_id` is assigned by the authors within state x county. Unmerged ballot fragments keep their own id.
- `precinct_medsl` is matched to the MEDSL 2020 precinct file (3-digit county FIPS + precinct). Some precincts are pooled for privacy.

## What R/dallas_2024.R does, and every judgment call

The county file has 873,455 rows (sheets) and 103 columns: `Cast Vote Record`, `Ballot Status`, `Precinct`, `Ballot Style`, then 99 contest columns. Cells hold the candidate name (sometimes followed by a county id like "(20485)"), "undervote", "overvote", "Write-in", "No image found", For / Against, or blank.

| Issue | What I did | Confidence |
|---|---|---|
| 14,893 rows have no President, no Sheriff and no statewide judges. They hold only later contests (mostly City of Dallas Props G-U) and their style ends in "[2]". | Treated as the second sheet of a 2-sheet paper ballot. Kept as their own `cvr_id`; they cannot be linked to sheet 1 because sheets were scanned in separate batches (sheet-2 rows sit next to each other in id order). Ballots = 873,455 - 14,893 = 858,562, exactly the canvass "Total # of Voters Voted". | High |
| Blank cells on a first sheet in President (4,106), US Senate (750) and Railroad Commissioner (541), the only 3 contests with declared write-in candidates. No other statewide or countywide contest has a single blank first-sheet cell. | Coded as WRITEIN, together with the explicit "Write-in" cells. Most likely the county blanked write-in cells when redacting ("CVR Redacted"). This is an inference, not documented by the county. | Medium |
| "No image found" (8 President, 2 Senate, 1 RRC) | UNDERVOTE in the vote file; its own "U" row in the metadata, like the 2020 Dallas rows (which have a second, tiny U row in alphabetical position of "No image found"). | Medium |
| Party | Not in the CVR. Taken from the canvass (REP/DEM/LIB/GRE mapped to REP/DEM/LBT/GRN). Local nonpartisan candidates and measures: both party columns missing. | High |
| Contests outside PQQ3KV's six offices | Included (the metadata file covers all contests). `office` = the metadata `item` (e.g. "DALLAS, PROP A", "DIST JUDGE"), `district` = metadata `dist` or missing. Measures: candidate "FOR" / "AGAINST". | Guess at a convention PQQ3KV does not define |
| `cvr_id` | The county's own "Cast Vote Record" number (unique, 1 to 921,082 with gaps), so any row can be traced back to the xlsx. | High |
| `precinct_medsl` | Left missing. No 2024 MEDSL precinct match was attempted. `precinct_cvr` = the county "Precinct" value (e.g. "3205-01"). | n/a |
| Parquet schema | Same 9 columns, names, order and types. nanoparquet writes columns with no missing values as REQUIRED rather than OPTIONAL; values read back the same. | High |
| University Hills Municipal District Directors | Columns 99-102 (3 have no header) are one contest. `magnitude` / `num_votes` = 4, the number of columns. One ballot only. | Guess |
| `num_votes` | Set to the vote-for number. In 11602209 it is 1 for 61,832 of 61,840 rows; I could not find its definition. | Guess |
| `item_id`, `item_id_2` | 1..96 in ballot order, both the same. They need re-keying before merging with the 2020 file. | n/a |
| "CRIMINAL APPEALS PRESIDING JUDGE" | No 2020 Texas row to copy (the seat was not up in 2020). Name made up to match the other CCA item. | Guess |
| Write-in `choice` code | Its `cand_num` as text, like a minor candidate, since "O" is used for overvotes in the 2020 Dallas rows. | Medium |
| `spending`, `topic`, `description`, `yes_orientation` | Left missing. They are hand-coded in the original. | n/a |
| 100-vote floor | Not applied. Small contests (Ovilla Prop A = 204 ballots, University Hills = 1) are included. | n/a |
