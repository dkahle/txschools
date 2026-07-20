# Data dictionaries: every table txschools returns

Every table the package returns is documented in a machine-readable data
dictionary shipped with the package, written in the
[data-dict.yaml](https://data-dict.tidyverse.org) format (spec 0.1.0):
column types, ranges, representative values, masking semantics,
cross-table relationships, and a glossary of TEA vocabulary. This
vignette *renders that file* – it is generated from the same dictionary
your code can read, so the two can never drift apart:

``` r

dict <- yaml::read_yaml(
  system.file("data-dict.yaml", package = "txschools")
)
length(dict$tables)
#> [1] 13
```

Two conventions apply everywhere and are worth internalizing before
reading the tables:

- **Years are ending years.** `year = 2025` means the 2024-25 school
  year, matching TEA’s URLs; `school_year` is the label form.
- **Identifiers are zero-padded strings.** Campus numbers are nine
  digits, district numbers six; keeping them as strings preserves
  leading zeros.

### Campus and district directory

**`directory`** — One row per Texas campus, district, region, or the
state, for one school year. The name-to-identifier lookup behind
txs_find_campus() and txs_find_district(). Returned by txs_directory().

| column | type | required | description | values / examples |
|:---|:---|:---|:---|:---|
| `year` | number(ordinal) | yes | School year ending calendar year. | 2013 to 2026 |
| `level` | enum | yes |  | `campus`, `district`, `region`, `state` |
| `id` | string | yes | TEA organization identifier. Nine digits for a campus (county-district-campus), six for a district; zero-padded. | `161920102`, `161920`, `12`, `TX` |
| `name` | string | yes | Entity name as published by TEA (upper case). | `CHINA SPRING EL`, `CHINA SPRING ISD` |
| `district` | string |  | Owning district’s six-digit number; null above district level. | `161920`, `057905` |
| `district_name` | string |  |  | `CHINA SPRING ISD`, `DALLAS ISD` |
| `county_name` | string |  |  | `MCLENNAN`, `DALLAS` |
| `region` | string |  | Education Service Center region number. | `12`, `10` |
| `grade_span` | string |  | Grades served, as published. | `EE-05`, `PK-12`, `09-12` |

### TAPR student-information datasets

**`tapr_student`** — Nine semantic datasets parsed from a TAPR campus or
district report’s student-information page, one requested entity-year
per pull. Grain: one row per category value (e.g. one grade level) per
entity-year and basis. Returned inside the named list from
txs_get_tapr(); the datasets `grade`, `ethnic`, `sex`, `cohorts`,
`program`, `disability`, `mobility`, `attrition`, and `retention` all
share this shape.

The category column is named for the dataset: `grade` in the grade
dataset (documented below as the representative), `ethnic`, `sex`,
`cohort`, `program`, `disability`, `mobility`, `attrition`, or
`retention` in the others. Every measure column travels with
`<measure>_masked` (true when TEA suppressed the value) and
`<measure>_mask_code` (the verbatim suppression marker) companions.

| column | type | required | description | values / examples |
|:---|:---|:---|:---|:---|
| `year` | number(ordinal) | yes |  | 2013 to 2026 |
| `school_year` | string | yes | Label form of `year`. | `2024-25`, `2023-24` |
| `level` | enum | yes |  | `campus`, `district` |
| `geography` | string | yes | Campus (9-digit) or district (6-digit) number, zero-padded. | `161920102`, `161920` |
| `entity_name` | string |  |  | `CHINA SPRING EL` |
| `district_name` | string |  |  | `CHINA SPRING ISD` |
| `county_name` | string |  |  | `MCLENNAN` |
| `source_url` | string |  | TEA report page this row was parsed from. | `https://rptsvr1.tea.texas.gov/cgi/sas/broker?...` |
| `retrieved_at` | datetime |  | When the page was retrieved. | 2026-01-01T00:00:00Z to 2027-01-01T00:00:00Z |
| `basis` | string |  | Row context on the report (membership vs enrollment, etc.). | `membership`, `enrollment` |
| `grade` | string |  | Category column, named for the dataset requested (see table details). For the grade dataset, the grade level. | `Kindergarten`, `Grade 3`, `Early Childhood Education` |
| `count` | number(quantity) \[students\] |  | Student count as printed; null when masked. | 0 to 10000 |
| `count_masked` | boolean |  |  |  |
| `count_mask_code` | string |  | Verbatim TEA suppression marker when masked. | `*`, `.`, `-`, `n/a`, `<1%` |
| `campus_percent` | number(quantity) \[proportion\] |  | Campus share of the category as a proportion (“49.6%” parses to 0.496). Null when masked. | 0 to 1 |
| `campus_percent_masked` | boolean |  |  |  |
| `campus_percent_mask_code` | string |  |  | `*`, `.` |
| `district_percent` | number(quantity) \[proportion\] |  |  | 0 to 1 |
| `district_percent_masked` | boolean |  |  |  |
| `district_percent_mask_code` | string |  |  | `*`, `.` |
| `state_percent` | number(quantity) \[proportion\] |  |  | 0 to 1 |
| `state_percent_masked` | boolean |  |  |  |
| `state_percent_mask_code` | string |  |  | `*`, `.` |

### TAPR average class sizes

**`tapr_class_size`** — Average class size by grade or subject for one
entity-year, with campus, district, and state comparison values. The
`class_size` dataset from txs_get_tapr(). Grain: one row per class-size
measure per entity-year.

Shares the identity columns of `tapr_student` (year, school_year, level,
geography, entity_name, district_name, county_name, source_url,
retrieved_at, basis); only the measure columns differ and are documented
here. Each measure carries `_masked`/`_mask_code` companions as in
`tapr_student`.

| column | type | required | description | values / examples |
|:---|:---|:---|:---|:---|
| `class_size` | string | yes | The class-size measure (grade or subject). | `Kindergarten`, `Grade 6`, `English/Language Arts` |
| `campus_class_size` | number(quantity) \[students per class\] |  |  | 0 to 40 |
| `district_class_size` | number(quantity) \[students per class\] |  |  | 0 to 40 |
| `state_class_size` | number(quantity) \[students per class\] |  |  | 0 to 40 |

### TAPR report-page datasets (generic long form)

**`tapr_report`** — Cell-level long form of a TAPR report page for one
entity-year. The datasets `staar_performance`, `staar_progress`,
`bilingual_esl`, `ccmr`, `graduation`, `attendance`, `staff`, and
`finance` from txs_get_tapr() all share this shape. Grain: one row per
table cell of the report page (a row label crossed with a
comparison-group column).

Shares the identity columns of `tapr_student` (year, school_year, level,
geography, entity_name, district_name, county_name, source_url,
retrieved_at). `value_num` is the number as printed by TEA: “90%” parses
to 90, “\$4,668” to 4668.

| column | type | required | description | values / examples |
|:---|:---|:---|:---|:---|
| `page_source` | enum | yes | Which TAPR page the cell came from. The attendance dataset is a filtered slice of the graduation page (TEA’s combined attendance/graduation/dropout report). | `student`, `staar_performance`, `staar_progress`, `bilingual_esl`, `ccmr`, `graduation`, `staff`, `finance` |
| `table_index` | number(ordinal) |  | Position of the source table on the page. | 1 to 60 |
| `row_index` | number(ordinal) |  |  | 1 to 500 |
| `section` | string |  | Section heading context (TEA’s colspan headings). | `Grade 3 Reading`, `STAAR Performance Rates` |
| `row_label` | string | yes |  | `All Students`, `Approaches Grade Level or Above` |
| `column` | string | yes | Comparison-group column header. | `Campus`, `District`, `State`, `African American` |
| `value` | string | yes | Cell value exactly as printed, masking codes intact. | `90%`, `$6,568`, `23.1`, `*` |
| `value_num` | number(quantity) |  | Numeric parse of `value`; null when masked or non-numeric. | -Inf to Inf |
| `masked` | boolean | yes |  |  |
| `mask_code` | string |  |  | `*`, `.`, `-`, `<1%` |

### TAPR statewide data files (tidy long form)

**`tapr_file`** — One statewide advanced-download data file (every
campus or district in Texas for one year and dataset code such as REF or
STAAR1), pivoted long. Returned by txs_get_tapr_file(). Grain: one row
per entity per variable code.

Identifier columns mirror the file as published and vary by level:
campus files carry a `CAMPUS` column, district files `DISTRICT`, and so
on (zero-padded strings). Decode `variable_code` with the
`tapr_dictionary` table.

| column | type | required | description | values / examples |
|:---|:---|:---|:---|:---|
| `year` | number(ordinal) | yes |  | 2013 to 2026 |
| `school_year` | string | yes |  | `2023-24` |
| `level` | enum | yes |  | `campus`, `district`, `region`, `state` |
| `variable_code` | string | yes | TEA variable mnemonic; see `tapr_dictionary`. | `CAMPNAME`, `CA00AR01S24R`, `CDALLC` |
| `value` | string |  | Value as published, masking codes intact. | `90`, `-1`, `CHINA SPRING EL` |
| `value_num` | number(quantity) |  | Numeric parse of `value`; null when masked or non-numeric. | -Inf to Inf |
| `masked` | boolean | yes |  |  |
| `mask_code` | string |  |  | `*`, `.`, `-1` |

### TAPR variable dictionary

**`tapr_dictionary`** — TEA’s statewide variable dictionary workbooks
parsed to one row per variable: the decoder for
`tapr_file.variable_code`. Returned by txs_get_tapr_dictionary().

| column | type | required | description | values / examples |
|:---|:---|:---|:---|:---|
| `year` | number(ordinal) | yes |  | 2013 to 2026 |
| `school_year` | string | yes |  | `2023-24` |
| `level` | enum | yes |  | `campus`, `district`, `region`, `state` |
| `sheet` | string |  | Workbook sheet the variable was documented on. | `cref`, `cstaar1` |
| `dataset` | string |  | Advanced-download dataset code the variable belongs to. | `REF`, `STAAR1`, `PROF` |
| `variable` | string | yes |  | `CAMPNAME`, `CPETALLC` |
| `label` | string | yes | Human-readable variable definition. | `Campus Name`, `Campus 2024 All Students Count` |

### AEIS statewide data files (tidy long form)

**`aeis`** — One statewide AEIS data file (2004-2012) by level and
dataset code (e.g. ref, stud, fin), pivoted long. Returned by
txs_get_aeis(). Grain: one row per entity per variable code.

Same tidy machinery as `tapr_file`: identifier columns mirror the file
as published (`CAMPUS` or `DISTRICT`, zero-padded strings), and the
record layout is available via txs_get_aeis(layout = TRUE).

| column | type | required | description | values / examples |
|:---|:---|:---|:---|:---|
| `year` | number(ordinal) | yes |  | 2004 to 2012 |
| `school_year` | string | yes |  | `2010-11` |
| `level` | enum | yes |  | `campus`, `district`, `region`, `state` |
| `variable_code` | string | yes |  | `DISTNAME`, `DPETALLC` |
| `value` | string |  |  | `CHINA SPRING ISD`, `2456`, `-1` |
| `value_num` | number(quantity) |  |  | -Inf to Inf |
| `masked` | boolean | yes |  |  |
| `mask_code` | string |  |  | `*`, `.`, `-1` |

### School Report Card (HTML era, tidy long form)

**`src`** — One campus’s School Report Card for one year (2004-2012),
parsed from TEA’s fixed-width HTML into cell-level long form. Returned
by txs_get_src(). Grain: one row per report line item per
comparison-group column. (2013-2019 reports are PDF-only and are
returned as a one-row file descriptor instead; 2020+ lives at
txschools.gov, out of package scope.)

| column | type | required | description | values / examples |
|:---|:---|:---|:---|:---|
| `year` | number(ordinal) | yes |  | 2004 to 2012 |
| `school_year` | string | yes |  | `2010-11` |
| `level` | enum | yes |  | `campus`, `district` |
| `geography` | string | yes |  | `161920102` |
| `school_name` | string |  |  | `CHINA SPRING EL` |
| `district_name` | string |  |  | `CHINA SPRING ISD` |
| `page` | number(ordinal) |  |  | 1 to 10 |
| `section` | string |  |  | `TAKS Performance`, `Attendance` |
| `measure` | string |  |  | `Reading`, `Attendance Rate` |
| `row_label` | string |  |  | `All Students`, `Grade 4` |
| `column` | string |  |  | `Campus`, `District`, `State` |
| `value` | string | yes |  | `94.0%`, `*` |
| `value_num` | number(quantity) |  |  | -Inf to Inf |
| `masked` | boolean | yes |  |  |
| `mask_code` | string |  |  | `*`, `.` |

### PEIMS financial data (budget or actual)

**`peims_finance`** — TEA’s statewide PEIMS single-file financial data:
one row per district (or charter) x fund x function x object x
organizational unit x program intent, for one school year and basis.
Returned by txs_get_peims_finance(); also the shape of the
`peims_finance_<basis>_<type>_<year>` tables that txs_write_peims_db()
writes to DuckDB. District actual files run to several million rows per
year.

The `*_label`, `district_name`, and `campus_name` columns are joined
from TEA’s companion code tables when `labels = TRUE` (the default) and
are absent when the code tables cannot be fetched or `labels = FALSE`.
Charter files use TEA’s nonprofit chart of accounts; their
asset/function/object/program-intent codes are normalized into the same
columns. No FERPA masking applies to this table: values are dollar
amounts, not student counts. Negative amounts are genuine (refunds,
adjustments, contra accounts).

| column | type | required | description | values / examples |
|:---|:---|:---|:---|:---|
| `district` | string | yes | Six-digit district number, zero-padded; charters included. | `161920`, `001902`, `003801` |
| `district_name` | string |  |  | `CHINA SPRING ISD`, `PINEYWOODS COMMUNITY ACADEMY` |
| `fin_unit` | string | yes | Three-digit organizational (fin) unit within the district; campus number where applicable, “000” for no cost center, “999” for undistributed. | `000`, `001`, `101`, `999` |
| `campus_name` | string |  |  | `CHINA SPRING H S`, `NO COST CENTER`, `UNDISTRIBUTED` |
| `year` | number(ordinal) | yes |  | 2000 to 2026 |
| `school_year` | string | yes |  | `2023-24`, `1999-00` |
| `basis` | enum | yes |  | `actual`, `budget` |
| `type` | enum | yes |  | `district`, `charter` |
| `fund_code` | string | yes | Three-digit fund code (199 = general fund). | `199`, `211`, `240`, `420`, `599` |
| `fund_label` | string |  |  | `GENERAL FUND`, `FOUNDATION SCHOOL PROGRAM` |
| `function_code` | string | yes | Two-digit function (11 = instruction). | `11`, `23`, `35`, `51`, `71` |
| `function_label` | string |  |  | `INSTRUCTION`, `FACILITY MAINTENANCE AND OPERATIONS` |
| `object_code` | string | yes | Four-digit object. 5xxx are revenues, 6xxx expenditures (61xx payroll, 62xx contracted services, 63xx supplies, 64xx other operating, 65xx debt service, 66xx capital outlay), 3xxx fund balances. | `5749`, `6119`, `6341`, `3600` |
| `object_label` | string |  |  | `SALARIES OR WAGES - TEACHERS AND OTHER PROFESSIONAL PERSONNEL` |
| `program_intent_code` | string |  | Two-digit program intent (11 = basic educational services). | `00`, `11`, `23`, `30` |
| `program_intent_label` | string |  |  | `BASIC EDUCATIONAL SERVICES`, `TITLE I, PART A SCHOOLWIDE ACTIVITIES` |
| `amount` | number(quantity) \[USD\] | yes | Budgeted or actual dollars; negatives are genuine. | -100000000 to 2000000000 |
| `fiscal_year` | number(ordinal) |  | Fiscal year as recorded in the file; equals `year`. | 2000 to 2026 |
| `updated` | date |  | TEA’s last-update stamp for the row. | 2000-01-01 to 2027-12-31 |

### PEIMS provenance table (\_peims_meta)

**`peims_meta`** — Written alongside every txs_write_peims_db() call:
one row per table write, recording where and when the data came from.
Stored in DuckDB as `_peims_meta`.

| column | type | required | description | values / examples |
|:---|:---|:---|:---|:---|
| `table` | string | yes |  | `peims_finance_actual_district_2024` |
| `year` | number(ordinal) |  |  | 2000 to 2026 |
| `school_year` | string |  |  | `2023-24` |
| `basis` | enum |  |  | `actual`, `budget` |
| `type` | enum |  |  | `district`, `charter` |
| `source_url` | string |  |  | `https://tea.texas.gov/data-reports/financial-reports/school-finance-reports-and-data/actget2024.zip` |
| `retrieved_at` | string |  | ISO 8601 retrieval timestamp of the source file. | `2026-07-18T23:03:55Z` |
| `sha256` | string |  | SHA-256 of the downloaded source file. | `29785442f150...` |
| `written_at` | string |  | ISO 8601 timestamp of the database write. | `2026-07-18T23:04:12Z` |

### School district property tax rates

**`tax_rates`** — One row per district per school year: adopted M&O and
I&S property-tax rates merged from the Texas Comptroller’s annual
rates-and-levies workbooks (tax years 2019 onward, primary) and TEA’s
adopted-tax-rates workbook (2005-06 onward, backfill). Returned by
txs_get_tax_rates(). Rates are dollars per \$100 of taxable value.

txs_derive_pennies() appends the HB3 decomposition columns
(tier_one_rate, golden_rate, copper_rate, enrichment_rate,
golden_pennies, copper_pennies); they are NA whenever `mcr` is NA. `mcr`
itself is a user-supplied pluggable input – TEA publishes no clean
statewide Maximum Compressed Rate file – so it is NA unless the caller
provides one.

| column | type | required | description | values / examples |
|:---|:---|:---|:---|:---|
| `year` | number(ordinal) | yes |  | 2006 to 2027 |
| `school_year` | string | yes |  | `2023-24`, `2005-06` |
| `district` | string | yes | Six-digit county-district number, zero-padded. | `161920`, `057905` |
| `district_name` | string |  |  | `CHINA SPRING ISD`, `China Spring ISD` |
| `mo_rate` | number(quantity) \[USD per \$100 taxable value\] | yes |  | 0 to 2 |
| `is_rate` | number(quantity) \[USD per \$100 taxable value\] |  |  | 0 to 1 |
| `total_rate` | number(quantity) \[USD per \$100 taxable value\] |  | From the Comptroller file where published, else mo_rate plus is_rate. | 0 to 3 |
| `mcr` | number(quantity) \[USD per \$100 taxable value\] |  | Maximum Compressed Rate; NA unless supplied by the caller. | 0 to 2 |
| `rate_source` | enum | yes |  | `comptroller`, `tea` |

### TEA district number to NCES LEAID crosswalk

**`crosswalk`** — One row per Texas school district linking TEA’s
six-digit county-district number to the seven-digit NCES LEAID (the
Census GEOID used by boundary files). Built from the NCES CCD directory
via the Urban Institute Education Data API. Returned by txs_crosswalk().

| column | type | required | description | values / examples |
|:---|:---|:---|:---|:---|
| `geoid` | string | key | Seven-digit NCES LEAID / Census GEOID. | `4813960`, `4816860` |
| `district` | string | yes |  | `161920`, `057905` |
| `lea_name` | string |  |  | `CHINA SPRING ISD` |

### District boundaries (sf)

**`boundaries`** — Simplified Census cartographic school-district
boundaries for Texas in WGS84, one polygon per district, returned as an
sf data frame by txs_boundaries(). Join TEA-keyed tables through the
crosswalk table.

| column | type | required | description | values / examples |
|:---|:---|:---|:---|:---|
| `geoid` | string | key |  | `4813960` |
| `name` | string |  |  | `China Spring ISD` |
| `geometry` |  |  | sf polygon geometry (EPSG:4326); not a scalar column. |  |

## How the tables relate

| join | cardinality | description |
|:---|:---|:---|
| `peims_finance.district = directory.district` | many-to-one | A PEIMS finance row’s district resolves to the directory’s district entry for the same year (directory `level = "district"` rows carry the district number in both `id` and `district`). |
| `tapr_student.geography = directory.id` | many-to-one | A TAPR entity’s campus or district number resolves to its directory entry for the same year. |
| `tapr_file.variable_code = tapr_dictionary.variable` | many-to-one | Statewide-file variable codes are defined in the dictionary for the same year and level. |
| `tax_rates.district = crosswalk.district` | many-to-one | Tax-rate rows resolve to Census geography through the crosswalk. |
| `crosswalk.geoid = boundaries.geoid` | one-to-one | The crosswalk’s LEAID is the boundary file’s GEOID. |

## Glossary

**TEA** — Texas Education Agency, the state agency overseeing public
K-12 education in Texas.

**TAPR** — Texas Academic Performance Reports (2013-present), TEA’s
annual campus/district/region/state report cards; successor to AEIS.

**AEIS** — Academic Excellence Indicator System (through 2011-12), the
predecessor of TAPR.

**SRC** — School Report Card, a condensed per-campus report TEA
publishes alongside TAPR/AEIS.

**PEIMS** — Public Education Information Management System, TEA’s
statewide data collection; its financial submission is the source of the
peims_finance table.

**campus number** — Nine-digit county-district-campus identifier; the
first six digits are the district number, the last three the campus.
Always handled as a zero-padded string.

**district number** — Six-digit identifier for a district or
open-enrollment charter (charters share the district number space).

**ending year** — The package identifies school years by their ending
calendar year: 2025 means the 2024-25 school year, matching TEA’s URLs.

**masking** — FERPA-driven suppression TEA applies to small student
counts. Masked cells keep their verbatim marker (“\*“,”.”, “\<1%”, -1
style sentinels) in `value`/`mask_code`, with `masked = true` and a null
numeric value. Never imputed. Not applicable to PEIMS finance (dollars,
not students).

**fund** — Revenue source bucket in TEA’s chart of accounts (e.g. 199
general fund, 211 Title I, 240 school nutrition, 599 debt service).

**function** — Purpose of an expenditure in TEA’s chart of accounts
(e.g. 11 instruction, 23 school leadership, 51 facility maintenance and
operations, 71 debt service).

**object** — What was bought or received (e.g. 61xx payroll, 62xx
contracted services, 66xx capital outlay; 5xxx revenues).

**program intent** — Student population an expenditure is intended to
serve (e.g. 11 basic educational services, 23 special education).

**fin unit** — Organizational unit within a district in PEIMS finance;
campus number where the money is attributable to a campus, otherwise
“000” (no cost center) or “999” (undistributed).

**charter** — Open-enrollment charter school, reported by TEA under the
nonprofit chart of accounts in PEIMS finance and as districts in most
other tables.

**ESC region** — One of twenty Education Service Center regions Texas
districts belong to (e.g. Region 12, Waco).

## Using the dictionary programmatically

The dictionary is plain YAML, so anything – your code, a colleague’s
Python, an AI agent – can consume it directly:

``` r

dict <- yaml::read_yaml(system.file("data-dict.yaml", package = "txschools"))

# Column names of the PEIMS finance table:
peims <- Filter(function(t) t$name == "peims_finance", dict$tables)[[1]]
vapply(peims$columns, `[[`, "", "name")
```

The [data-dict CLI](https://data-dict.tidyverse.org) can validate the
file against the specification, and the same conventions (one
`data-dict.yaml` per data collection) work for documenting your own
derived datasets downstream.
