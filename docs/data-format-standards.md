# IIDDA Data Format Standards

![Status:Draft](https://img.shields.io/static/v1.svg?label=Status&message=Draft&color=yellow)

## Field Meanings

### Disease

* Disease -- local definition of disease name
* No -- disease numbers are used in `mort_cdi_ab_1912-1940_mn` -- not sure what they mean yet

https://github.com/kamillamagna/ICD-10-CSV

It would be nice to be able to follow some standard here like ICD-10, but not sure of the process of how to get there

One idea is to concatenate all unique values in `Disease` columns and then have an expert associate one ICD-10 (or some other standard) code to each. Then we could use a lookup table to convert `Disease` columns to `ICD-10` columns. This sounds good, but I am wondering about cases where the same description in two different datasets would lead an expert to choose different ICD-10 codes for each.

### Age Group

* `Youngest Age` -- a column with the youngest possible age (in years) of individuals associated with each record
* `Oldest Age` -- a column with the oldest possible age (in years) of individuals associated with each record

### Sex

Valid values (tentative list to be updated iff we find more cases):
* Male
* Female
* Undifferentiated
(inspired by https://www.cdisc.org/kb/articles/sex-and-gender)

### Date

Question -- should we always normalize to date ranges, or use simpler `Year` or `Month` fields for yearly or monthly data?

### Counts

* Deaths
* Cases

Death and Case number field names prefixed with things like `Total_` should use the un-prefixed version

### Rates

* Morbidity -- Cases per population
* Mortality -- Deaths per population

Any tidy table with Morbidity/Mortality columns should have metadata describing specifically how the calculations are made

Once we work a bit more with the data we might want to create a few different kinds of Morbidity/Mortality columns if it is not possible to directly compare across tables.  But in general we should convert these in every table to something comparable where ever possible.

These are useful for checking counts

Need to be specific about what the denominator is (e.g. per 100000 people)

Different definitions exist -- https://www.cdc.gov/csels/dsepd/ss1978/lesson3/section2.html

### Geography

Based on the above standards we have the following fields for geographical locations within Canada, I guess
* `Canadian Region` -- Atlantic, Quebec, Ontario, Prairies, British Columbia, Territories
* `ISO-3166 Country Codes` (e.g. CA)
* `ISO-3166 Subdivision Codes` This is basically state/prov/territory (e.g. CA-ON)

Question: What to do about Municipal etc?

## Field Naming Rules

Spaces, underscores, hyphens???

## References

Perhaps https://www.cdisc.org/ could be useful for establishing standards. Also, obviously check with Tycho.

https://www.cdc.gov/csels/dsepd/ss1978/lesson3/section2.html

https://www.statcan.gc.ca/eng/subjects/standard/sgc/2016/introduction

https://unstats.un.org/unsd/statcom/51st-session/documents/The_GSGF-E.pdf 

https://en.wikipedia.org/wiki/ISO_3166-2

https://www.cdc.gov/csels/dsepd/ss1978/lesson3/section2.html

https://www.snomed.org/

https://github.com/kamillamagna/ICD-10-CSV