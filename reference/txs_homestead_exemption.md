# Texas homestead exemption for school taxes, by year

The state-mandated school-district homestead exemption in dollars, by
ending school year (the statute keys on the tax year, which is the
ending year minus one). Hard-coded schedule; verify when a legislature
changes it (the top value reflects the 2025 legislative increase).

## Usage

``` r
txs_homestead_exemption(year)
```

## Arguments

- year:

  Integer ending school year(s); 2024 means the 2023-24 school year (tax
  year 2023).

## Value

Numeric vector of exemption amounts in dollars.

## Examples

``` r
txs_homestead_exemption(2024)
#> [1] 1e+05
```
