# Getting started with txschools

`txschools` makes it straightforward to pull *public* school-performance
data published by the Texas Education Agency (TEA): the Texas Academic
Performance Reports (TAPR, 2013-present), the School Report Card (SRC,
2004-2019), and the Academic Excellence Indicator System (AEIS,
2004-2012).

## Find your school

TEA identifies campuses by nine-digit county-district-campus numbers and
districts by six-digit numbers. Look them up by name:

``` r

txs_find_campus("china spring")
#> # A tibble: 7 × 9
#>    year level  id     name  district district_name county_name region grade_span
#>   <int> <chr>  <chr>  <chr> <chr>    <chr>         <chr>       <chr>  <chr>     
#> 1  2024 campus 16192… CHIN… 161920   CHINA SPRING… MCLENNAN    12     09 - 12   
#> 2  2024 campus 16192… TAG   161920   CHINA SPRING… MCLENNAN    12     10 - 12   
#> 3  2024 campus 16192… CHAL… 161920   CHINA SPRING… MCLENNAN    12     07 - 11   
#> 4  2024 campus 16192… CHIN… 161920   CHINA SPRING… MCLENNAN    12     07 - 08   
#> 5  2024 campus 16192… CHIN… 161920   CHINA SPRING… MCLENNAN    12     02 - 04   
#> 6  2024 campus 16192… CHIN… 161920   CHINA SPRING… MCLENNAN    12     05 - 06   
#> 7  2024 campus 16192… CHIN… 161920   CHINA SPRING… MCLENNAN    12     EE - 01
```

## Discover available years and downloads

``` r

txs_list_years("tapr")
#> # A tibble: 13 × 3
#>    source  year school_year
#>    <chr>  <int> <chr>      
#>  1 tapr    2013 2012-13    
#>  2 tapr    2014 2013-14    
#>  3 tapr    2015 2014-15    
#>  4 tapr    2016 2015-16    
#>  5 tapr    2017 2016-17    
#>  6 tapr    2018 2017-18    
#>  7 tapr    2019 2018-19    
#>  8 tapr    2020 2019-20    
#>  9 tapr    2021 2020-21    
#> 10 tapr    2022 2021-22    
#> 11 tapr    2023 2022-23    
#> 12 tapr    2024 2023-24    
#> 13 tapr    2025 2024-25

downloads <- txs_list_downloads(2024, source = "tapr")
downloads
#> # A tibble: 76 × 11
#>    source  year school_year level    data_type  dataset file_format label method
#>    <chr>  <int> <chr>       <chr>    <chr>      <chr>   <chr>       <chr> <chr> 
#>  1 tapr    2024 2023-24     campus   dictionary NA      xlsx        camp… get   
#>  2 tapr    2024 2023-24     district dictionary NA      xlsx        dist… get   
#>  3 tapr    2024 2023-24     region   dictionary NA      xlsx        regi… get   
#>  4 tapr    2024 2023-24     state    dictionary NA      xlsx        state get   
#>  5 tapr    2024 2023-24     campus   advanced   REF     csv         TAPR… get   
#>  6 tapr    2024 2023-24     campus   advanced   STAAR1  csv         TAPR… get   
#>  7 tapr    2024 2023-24     campus   advanced   STAAR2  csv         TAPR… get   
#>  8 tapr    2024 2023-24     campus   advanced   STAAR3  csv         TAPR… get   
#>  9 tapr    2024 2023-24     campus   advanced   PART1   csv         TAPR… get   
#> 10 tapr    2024 2023-24     campus   advanced   STAAR4  csv         TAPR… get   
#> # ℹ 66 more rows
#> # ℹ 2 more variables: url <chr>, params <chr>
```

TAPR’s statewide data lives behind TEA’s SAS-broker “Advanced Download”
interface: one CSV per `level` × `dataset` code (`"REF"`, `"STAAR1"`,
`"GRAD"`, …). The `TAPR_*.xlsx` workbooks TEA links as “TAPR Data in
Excel” are variable dictionaries, exposed here as
`data_type = "dictionary"`.

## Download semantic TAPR datasets

``` r

tapr <- txs_get_tapr(
  year      = 2025,
  level     = "campus",
  geography = "161920102",
  datasets  = c("grade", "sex")
)
#> ℹ Downloading TAPR student information page (source)
tapr$grade
#> # A tibble: 6 × 23
#>    year school_year level  geography entity_name     district_name   county_name
#>   <int> <chr>       <chr>  <chr>     <chr>           <chr>           <chr>      
#> 1  2025 2024-25     campus 161920102 CHINA SPRING EL CHINA SPRING I… MCLENNAN C…
#> 2  2025 2024-25     campus 161920102 CHINA SPRING EL CHINA SPRING I… MCLENNAN C…
#> 3  2025 2024-25     campus 161920102 CHINA SPRING EL CHINA SPRING I… MCLENNAN C…
#> 4  2025 2024-25     campus 161920102 CHINA SPRING EL CHINA SPRING I… MCLENNAN C…
#> 5  2025 2024-25     campus 161920102 CHINA SPRING EL CHINA SPRING I… MCLENNAN C…
#> 6  2025 2024-25     campus 161920102 CHINA SPRING EL CHINA SPRING I… MCLENNAN C…
#> # ℹ 16 more variables: source_url <chr>, retrieved_at <chr>, basis <chr>,
#> #   grade <chr>, count <int>, count_masked <lgl>, count_mask_code <chr>,
#> #   campus_percent <dbl>, campus_percent_masked <lgl>,
#> #   campus_percent_mask_code <chr>, district_percent <dbl>,
#> #   district_percent_masked <lgl>, district_percent_mask_code <chr>,
#> #   state_percent <dbl>, state_percent_masked <lgl>,
#> #   state_percent_mask_code <chr>
```

[`txs_get_tapr()`](https://dkahle.github.io/txschools/reference/txs_get_tapr.md)
returns a named list because a TAPR report is a collection of datasets,
not one rectangular table.

## Download a statewide TAPR data file

``` r

df <- txs_get_tapr_file(
  year        = 2024,
  level       = "campus",
  dataset     = "REF",
  data_type   = "advanced",
  output      = "tidy"
)
#> ℹ Using cached file: /private/var/folders/sj/hzqk2hps4wzfm92lfjdhpv3m0000gn/T/Rtmp594Xc7/txschools-vignette/tapr/2023-24/campus/advanced/tapr_campus_2024_ref.csv
df
#> # A tibble: 63,574 × 15
#>    CAMPUS    CAMPNAME DISTRICT DISTNAME REGION GRDTYPE GRDSPAN  year school_year
#>    <chr>     <chr>    <chr>    <chr>    <chr>  <chr>   <chr>   <int> <chr>      
#>  1 '0019020… CAYUGA … '001902  CAYUGA … '07    S       '09 - …  2024 2023-24    
#>  2 '0019020… CAYUGA … '001902  CAYUGA … '07    S       '09 - …  2024 2023-24    
#>  3 '0019020… CAYUGA … '001902  CAYUGA … '07    S       '09 - …  2024 2023-24    
#>  4 '0019020… CAYUGA … '001902  CAYUGA … '07    S       '09 - …  2024 2023-24    
#>  5 '0019020… CAYUGA … '001902  CAYUGA … '07    S       '09 - …  2024 2023-24    
#>  6 '0019020… CAYUGA … '001902  CAYUGA … '07    S       '09 - …  2024 2023-24    
#>  7 '0019020… CAYUGA … '001902  CAYUGA … '07    S       '09 - …  2024 2023-24    
#>  8 '0019020… CAYUGA … '001902  CAYUGA … '07    M       '06 - …  2024 2023-24    
#>  9 '0019020… CAYUGA … '001902  CAYUGA … '07    M       '06 - …  2024 2023-24    
#> 10 '0019020… CAYUGA … '001902  CAYUGA … '07    M       '06 - …  2024 2023-24    
#> # ℹ 63,564 more rows
#> # ℹ 6 more variables: level <chr>, variable_code <chr>, value <chr>,
#> #   value_num <dbl>, masked <lgl>, mask_code <chr>
```

Variable codes are documented in the per-year dictionary:

``` r

dict <- txs_get_tapr_dictionary(2024, "campus")
#> ℹ Downloading: https://rptsvr1.tea.texas.gov/perfreport/tapr/2024/Basic%20Download/xplore/TAPR_campus_2024.xlsx
dict
#> # A tibble: 5,011 × 7
#>     year school_year level  sheet dataset variable label                        
#>    <int> <chr>       <chr>  <chr> <chr>   <chr>    <chr>                        
#>  1  2024 2023-24     campus cref  CREF    PAIRNAME Campus 2024 Flag - Campus/Di…
#>  2  2024 2023-24     campus cref  CREF    PAIRCAMP Campus 2024 Flag - Campus/Di…
#>  3  2024 2023-24     campus cref  CREF    CFLCHART Campus 2024 Flag - Charter S…
#>  4  2024 2023-24     campus cref  CREF    CFLALTED Campus 2024 Flag - Rated und…
#>  5  2024 2023-24     campus cref  CREF    CAMPNAME Campus Name                  
#>  6  2024 2023-24     campus cref  CREF    CAMPUS   Campus Number                
#>  7  2024 2023-24     campus cref  CREF    GRDTYPE  Campus Type (B,E,M,S) Total …
#>  8  2024 2023-24     campus cref  CREF    CNTYNAME County Name                  
#>  9  2024 2023-24     campus cref  CREF    COUNTY   County Number                
#> 10  2024 2023-24     campus cref  CREF    DISTNAME District Name                
#> # ℹ 5,001 more rows
```

Every call records source metadata as an attribute:

``` r

attr(df, "txschools")
#> $source
#> [1] "tapr"
#> 
#> $year
#> [1] 2024
#> 
#> $school_year
#> [1] "2023-24"
#> 
#> $level
#> [1] "campus"
#> 
#> $data_type
#> [1] "advanced"
#> 
#> $dataset
#> [1] "REF"
#> 
#> $file_format
#> [1] "csv"
#> 
#> $source_url
#> [1] "https://rptsvr1.tea.texas.gov/cgi/sas/broker"
#> 
#> $retrieved_at
#> [1] "2026-07-19T20:19:12Z"
#> 
#> $sha256
#> [1] "90e9275fea3219509c3b3ee2a4ad598ac4115667950935dc192bf3fb72a7ab95"
#> 
#> $size_bytes
#> [1] 1240102
#> 
#> $cache_path
#> [1] "/private/var/folders/sj/hzqk2hps4wzfm92lfjdhpv3m0000gn/T/Rtmp594Xc7/txschools-vignette/tapr/2023-24/campus/advanced/tapr_campus_2024_ref.csv"
#> 
#> $used_cache
#> [1] TRUE
#> 
#> $masking_values
#>  [1] "."   "*"   "-"   "---" "-1"  "-2"  "-3"  "-4"  "-99" "n/a" "N/A"
```

A re-call uses the cached copy without re-downloading.

## School Report Cards

TEA publishes SRC as per-campus reports. 2004-2012 campus reports are
HTML and parse into a tidy tibble; 2013-2019 reports are PDF and are
downloaded to the cache:

``` r

src <- txs_get_src(2011, "campus", "161920102")
#> ℹ Downloading SRC campus report: https://rptsvr1.tea.texas.gov/cgi/sas/broker
src
#> # A tibble: 198 × 15
#>     year school_year level  geography school_name    district_name  page section
#>    <int> <chr>       <chr>  <chr>     <chr>          <chr>         <int> <chr>  
#>  1  2011 2010-11     campus 161920102 CHINA SPRING … CHINA SPRING…     1 TAKS M…
#>  2  2011 2010-11     campus 161920102 CHINA SPRING … CHINA SPRING…     1 TAKS M…
#>  3  2011 2010-11     campus 161920102 CHINA SPRING … CHINA SPRING…     1 TAKS M…
#>  4  2011 2010-11     campus 161920102 CHINA SPRING … CHINA SPRING…     1 TAKS M…
#>  5  2011 2010-11     campus 161920102 CHINA SPRING … CHINA SPRING…     1 TAKS M…
#>  6  2011 2010-11     campus 161920102 CHINA SPRING … CHINA SPRING…     1 TAKS M…
#>  7  2011 2010-11     campus 161920102 CHINA SPRING … CHINA SPRING…     1 TAKS M…
#>  8  2011 2010-11     campus 161920102 CHINA SPRING … CHINA SPRING…     1 TAKS M…
#>  9  2011 2010-11     campus 161920102 CHINA SPRING … CHINA SPRING…     1 TAKS M…
#> 10  2011 2010-11     campus 161920102 CHINA SPRING … CHINA SPRING…     1 TAKS M…
#> # ℹ 188 more rows
#> # ℹ 7 more variables: measure <chr>, row_label <chr>, column <chr>,
#> #   value <chr>, value_num <dbl>, masked <lgl>, mask_code <chr>
```

## AEIS

Statewide AEIS files (2004-2012) are keyed by level and dataset code:

``` r

aeis <- txs_get_aeis(2011, "district", dataset = "ref",
                     geography = "161920")
#> ℹ Downloading: https://rptsvr1.tea.texas.gov/cgi/perfreport/2011aeis.cgi
aeis
#> # A tibble: 6 × 11
#>   DISTNAME DISTRICT REGION  year school_year level variable_code value value_num
#>   <chr>    <chr>    <chr>  <int> <chr>       <chr> <chr>         <chr>     <dbl>
#> 1 CHINA S… 161920   12      2011 2010-11     dist… secs          D            NA
#> 2 CHINA S… 161920   12      2011 2010-11     dist… dackdtl       UVJS         NA
#> 3 CHINA S… 161920   12      2011 2010-11     dist… COUNTY        161         161
#> 4 CHINA S… 161920   12      2011 2010-11     dist… CNTYNAME      MCLE…        NA
#> 5 CHINA S… 161920   12      2011 2010-11     dist… DFLCHART      N            NA
#> 6 CHINA S… 161920   12      2011 2010-11     dist… D_RATING      R            NA
#> # ℹ 2 more variables: masked <lgl>, mask_code <chr>
```

## Citation

``` r

txs_cite(df)
#> Texas Education Agency (2026). "TAPR 2023-24, campus-level (advanced,
#> csv)." Retrieved 2026-07-19T20:19:12Z via the txschools R package;
#> SHA-256 90e9275fea32., <https://rptsvr1.tea.texas.gov/cgi/sas/broker>.
```

## Bulk multi-year downloads

``` r

plan <- txs_bulk_plan(2023:2024, levels = "campus", datasets = c("REF", "GRAD"))
plan
#> # A tibble: 4 × 12
#>   source  year school_year level  data_type dataset file_format method url      
#>   <chr>  <int> <chr>       <chr>  <chr>     <chr>   <chr>       <chr>  <chr>    
#> 1 tapr    2023 2022-23     campus advanced  REF     csv         post   https://…
#> 2 tapr    2023 2022-23     campus advanced  GRAD    csv         post   https://…
#> 3 tapr    2024 2023-24     campus advanced  REF     csv         get    https://…
#> 4 tapr    2024 2023-24     campus advanced  GRAD    csv         get    https://…
#> # ℹ 3 more variables: params <chr>, cache_path <chr>, exists_in_cache <lgl>
done <- txs_bulk_download(plan, delay = 5)
done
#> # A tibble: 4 × 17
#>   source  year school_year level  data_type dataset file_format method url      
#>   <chr>  <int> <chr>       <chr>  <chr>     <chr>   <chr>       <chr>  <chr>    
#> 1 tapr    2023 2022-23     campus advanced  REF     csv         post   https://…
#> 2 tapr    2023 2022-23     campus advanced  GRAD    csv         post   https://…
#> 3 tapr    2024 2023-24     campus advanced  REF     csv         get    https://…
#> 4 tapr    2024 2023-24     campus advanced  GRAD    csv         get    https://…
#> # ℹ 8 more variables: params <chr>, cache_path <chr>, exists_in_cache <lgl>,
#> #   status <chr>, bytes <dbl>, elapsed_s <dbl>, sha256 <chr>, error <chr>
```
