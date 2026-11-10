# Manual check list: Dallas Nov 2024

Everything in the Dallas pipeline was AI-generated (Claude Code) and has not been checked by hand. Tick each box only after doing it yourself, then update the "AI use" table in README.md with the date.

Run `Rscript R/dallas_2024.R` first (about 1 minute after the download).

## Raw files
- [ ] Open the county folder (URL in `data/dallas_2024_manifest.csv`) and confirm there are still exactly 9 files with the sizes in the manifest.
- [ ] Re-run `shasum -a 256 raw/dallas_2024_general/*.xlsx` and compare with the manifest.

## Ballots vs. parquet
- [ ] Pick 5 `Cast Vote Record` numbers from different xlsx files (one of them a row whose Ballot Style ends in "[2]"). For each, compare every non-blank cell in the xlsx with the rows for that `cvr_id` in `out/cvrs/state=TEXAS/county_name=DALLAS/part-0.parquet` (same count, same candidates, UNDERVOTE / OVERVOTE where the xlsx says so).
- [ ] Find 2 ballots where President is blank in the xlsx but Sheriff is filled in. Confirm the parquet shows WRITEIN for President.
- [ ] Look at 3 of those blank-President ballots in the county's redacted ballot images (6. Canvass/Ballot Images) if they can be matched by number, to test whether blank really means write-in.
- [ ] Confirm that rows whose style ends in "[2]" never contain President, Sheriff or any statewide judge.

## Totals vs. the official canvass
- [ ] Open `Nov 5 2024 Final Canvass (signed sealed).pdf` (6. Canvass/Results/Summary Results by City) and check "Total # of Voters Voted: 858562" on page 1.
- [ ] Check every number in `data/dallas_2024_canvass.csv` against the PDF. It was read by OCR (tesseract), so a misread digit is possible. Page 45 (95th District Judge, 611,311) was misread once already.
- [ ] Check the 11 mismatches in `data/dallas_2024_validation.csv` against the write-in lines in `Final Unofficial Results Report.pdf` (e.g. "Write-In: Donald Trump/ JD Vance 101"). The CVR should be short by exactly the write-ins cast for listed candidates. Chase Oliver is short by 1 while the unofficial report shows 0, so that one is unexplained.
- [ ] Pick 2 City of Dallas propositions and compare the For / Against totals in `data/dallas_2024_choice_crosswalk.csv` with `Dallas County Unoffical Final.pdf` or the city canvass. I did not check any local contest.

## Metadata file
- [ ] In `data/dallas_2024_choice_crosswalk.csv`, confirm every party (REP / DEM / LIB / GRE) against the canvass, especially the Green and Libertarian candidates (Stein, Espinoza, Crow, Dunlap, Oliver, Brown, Roberson, Jefferson, Hale).
- [ ] Confirm `choice` codes: D / R in partisan races, A / B for the top two in nonpartisan races, Y = For and N = Against for propositions.
- [ ] Compare 3 contests in `out/dallas_2024_item_choice_info.tab` with the 2020 Dallas rows in Dataverse file 11602209 (same item / dist / place / level spelling).
- [ ] Decide whether "CRIMINAL APPEALS PRESIDING JUDGE" and the University Hills `num_votes = 4` guesses are acceptable, or ask Prof. Kuriwaki.

## Vendor column
- [ ] Open the Verified Voting verifier in a browser for Dallas, Tarrant, Parker, Bexar, Cooke, Webb, Burnet and Hidalgo (2024) and confirm the make in `data/verified_voting_2024_tx.csv`.
- [ ] Webb and Burnet are marked "unconfirmed". Check the county election pages or SOS certification records before telling anyone their vendor.
