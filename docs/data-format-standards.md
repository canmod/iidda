# IIDDA Derived Data Standards

![Status:Draft](https://img.shields.io/static/v1.svg?label=Status&message=Draft&color=yellow)

Data sources may optionally provide a `derived-data` folder containing one or more cleaned data files. These cleaned files provide some or all of the information in the `source-data` folder. The purpose of these `derived-data` files is to be as faithful as possible to the information in the original sources, but formatted in a manner that is more convenient for programmatic use. This document provides specifications for `derived-data` folders.

## Directory Structure

The `derived-data` folder is organized into a series of one or more data _products_ that represent a single cleaned data file. Each of these products is itself a folder containing the cleaned data file itself, as well as associated metadata and scripts.

For example, the `derived-data` folder of a particular data source in IIDDA contains the following four products.

* `cdi_ca_1964_wk_prov_mcgill`
* `cdi_ca_1965_wk_prov_mcgill`
* `cdi_ca_1966_wk_prov_mcgill`
* `cdi_ca_1967_wk_prov_mcgill`

Each product folder has the following files and folders.

* `{product_name}_metadata.json`
* `{product_name}_{additional_metadata}.json`
* `conversion-scripts`
* `{product_name}.{extension}`

Here the names in curly braces depend on the specific product and have the following meanings.

* `product_name` -- folder name of the product
* `other_metadata` -- some other type of metadata
* `extension` -- file extension for the dataset

The `{product_name}_metadata.json` file is required and follows the [DataCite JSON format](https://github.com/datacite/schema/blob/master/source/json/kernel-4.3/datacite_4.3_schema.json) for dataset metadata.

There can be as many `{product_name}_{other_metadata}.json` files as are required, such as a [data dictionary](https://specs.frictionlessdata.io/table-schema/) or [CSV dialect](https://specs.frictionlessdata.io/).

The `conversion-scripts` folder contains scripts that take `source-data` files as input and return the cleaned derived dataset, `{product_name}.{extension}`.

Here is an example product folder.

* `cdi_ca_1964_wk_prov_mcgill_metadata.json`
* `cdi_ca_1964_wk_prov_mcgill_data_dictionary.json`
* `cdi_ca_1964_wk_prov_mcgill_csv_dialect.json`
* `conversion-scripts`
  * `cdi_ca_1964_wk_prov_mcgill.R`
* `cdi_ca_1964_wk_prov_mcgill.csv`

## Specific Types of Derived Data

### CSV Files

The CSV format is the preferred format for tabular `derived-data` in IIDDA, as we believe that it is the most convenient format for a wide variety of potential users.

#### Additional Metadata

IIDDA has a [global data dictionary](https://github.com/canmod/iidda/blob/main/global-metadata/data-dictionary.json), which is a table that describes every field used in IIDDA. The information in the data dictionary for each CSV data product is a subset of the global data dictionary.

Project Tycho publishes a single format for all of their derived datasets -- https://fairsharing.org/bsg-s000718/.

CSV files in `derived-data` folders must be RFC-4180 compliant (https://datatracker.ietf.org/doc/html/rfc4180).

We recommend the following [CSV dialect](https://specs.frictionlessdata.io/)
```
{
   "dialect":  {
       "csvddfVersion": 1.2,
       "delimiter": ",",
       "lineTerminator": "\r\n",
       "quoteChar": "\"",
       "doubleQuote": true,
       "nullSequence": "",
       "skipInitialSpace": false,
       "header": true,
       "commentChar": "#",
       "caseSensitiveHeader": true 
   }
}
```
But at a minimum these metadata should be present.

#### Automatic Construction of Compliant CSV Files

Assume we have a plain `data.frame` object (i.e. not a `data.table`, `tibble`) called `data` and are writing it to a file called `data.csv`.

#### Rationale for not using Existing Tools and Standards

Decided not to use CSV lint to figure this out -- https://csvlint.io/about -- they have badges, which is great, but I'm not comfortable using a web-service like this and don't have a good sense for how stable it is.

Decided not to use `tableschema.r` because it was too buggy -- https://github.com/frictionlessdata/tableschema-r/issues/22.

Decided not to use `csvy` format, because although I like the idea it is not widely-enough adopted and `read.csv` doesn't read it out-of-the-box (you need to set `comment.char = "#"`).

#### Fields

##### Case

All field names _must_ use `snake_case` (https://en.wikipedia.org/wiki/Snake_case, https://github.com/Tazinho/snakecase)

##### Disease Identifiers

Fields named `disease` _must_ be used to contain the names of diseases as they were given in the `source-data`. Fields named `disease_subclass`  _must_ be used to contain the names of any sub-categories of diseases, again as they were given in the `source-data`. If it is necessary to identify the natural language used to describe the diseases, use field names that concatenate the word `disease` or `disease_subclass` with the ISO-639-1 language code (e.g. `disease_fr`).

If ICD codes are reported in the `source-data` these _must_ be placed in fields with names of the form `icd_{version}` and `icd_{version}_subclass`, where `{version}` should be replaced with the ICD version number that was reported in the `source-data`.  The data in these ICD fields _must_ have been reported in the `source-data` and _must not_ have been inferred from the reported disease names.

##### Dates

ISO-8601

##### Counts

##### Rates

* Morbidity -- Cases per population
* Mortality -- Deaths per population

Any tidy table with Morbidity/Mortality columns should have metadata describing specifically how the calculations are made

Once we work a bit more with the data we might want to create a few different kinds of Morbidity/Mortality columns if it is not possible to directly compare across tables.  But in general we should convert these in every table to something comparable where ever possible.

These are useful for checking counts

Need to be specific about what the denominator is (e.g. per 100000 people)

Different definitions exist -- https://www.cdc.gov/csels/dsepd/ss1978/lesson3/section2.html

##### Sex and Gender Identifiers

Fields named `sex` and `gender` must be used to represent sex and gender information as it was reported in the `source-data`. (TODO: how to choose between `sex` and `gender`). If the field name `sex` is used, valid values include (tentative list to be updated iff we find more cases):
* Male
* Female
* Undifferentiated
(inspired by https://www.cdisc.org/kb/articles/sex-and-gender)

##### Records

The meaning of each record in the dataset depends on the kind of data being represented.

## OLD -- Field Meanings

### Disease

* Disease -- local definition of disease name
* No -- disease numbers are used in `mort_cdi_ab_1912-1940_mn` -- not sure what they mean yet

https://github.com/kamillamagna/ICD-10-CSV

It would be nice to be able to follow some standard here like ICD-10, but not sure of the process of how to get there

One idea is to concatenate all unique values in `Disease` columns and then have an expert associate one ICD-10 (or some other standard) code to each. Then we could use a lookup table to convert `Disease` columns to `ICD-10` columns. This sounds good, but I am wondering about cases where the same description in two different datasets would lead an expert to choose different ICD-10 codes for each.

Another problem is that there are a very large number of pneumonia-related ICD-10 codes -- which one to choose when the data simply say "Pneumonia"?

### Age Group

* `Youngest Age` -- a column with the youngest possible age (in years) of individuals associated with each record
* `Oldest Age` -- a column with the oldest possible age (in years) of individuals associated with each record

### Date

https://github.com/davidearn/data_work/issues/4

### Counts

* Deaths
* Cases

Death and Case number field names prefixed with things like `Total_` should use the un-prefixed version



### Geography

Based on the above standards we have the following fields for geographical locations within Canada, I guess
* `Canadian Region` -- Atlantic, Quebec, Ontario, Prairies, British Columbia, Territories
* `ISO-3166 Country Codes` (e.g. CA)
* `ISO-3166 Subdivision Codes` This is basically state/prov/territory (e.g. CA-ON)

Question: What to do about Municipal etc?

## References

Perhaps https://www.cdisc.org/ could be useful for establishing standards. Also, obviously check with Tycho.

https://www.cdc.gov/csels/dsepd/ss1978/lesson3/section2.html

https://www.statcan.gc.ca/eng/subjects/standard/sgc/2016/introduction

https://unstats.un.org/unsd/statcom/51st-session/documents/The_GSGF-E.pdf 

https://en.wikipedia.org/wiki/ISO_3166-2

https://www.cdc.gov/csels/dsepd/ss1978/lesson3/section2.html

https://www.snomed.org/

https://github.com/kamillamagna/ICD-10-CSV