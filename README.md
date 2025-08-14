# International Infectious Disease Data Archive (IIDDA)

[![CC BY-NC-SA 4.0][cc-by-nc-sa-shield]][cc-by-nc-sa]

[cc-by-nc-sa]: http://creativecommons.org/licenses/by-nc-sa/4.0/
[cc-by-nc-sa-image]: https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png
[cc-by-nc-sa-shield]: https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg

<img src="assets/1939weeklyON.jpg" width="40%">

- [International Infectious Disease Data Archive (IIDDA)](#international-infectious-disease-data-archive-iidda)
  - [Classic IIDDA](#classic-iidda)
  - [Featured Datasets](#featured-datasets)
    - [CANMOD Digitization Project](#canmod-digitization-project)
  - [IIDDA API](#iidda-api)
  - [Data Dictionary](#data-dictionary)
  - [Data Harmonization](#data-harmonization)
  - [Reproducing IIDDA Datasets](#reproducing-iidda-datasets)
    - [Running Natively](#running-natively)
    - [Running in a Docker Container](#running-in-a-docker-container)
    - [Running Interactively](#running-interactively)
    - [Dependency Management](#dependency-management)
    - [Requirements](#requirements)
  - [Project Structure](#project-structure)
    - [Data Sources and Pipelines](#data-sources-and-pipelines)
      - [Source Data](#source-data)
      - [Source Code](#source-code)
    - [Derived Data and Tidy Datasets](#derived-data-and-tidy-datasets)
    - [Identifiers](#identifiers)
    - [Metadata](#metadata)
    - [Lookup Tables](#lookup-tables)
  - [Contributions](#contributions)
    - [Contributing Source Data and Pipelines](#contributing-source-data-and-pipelines)
    - [Contributing Fixes to Data and Pipelines](#contributing-fixes-to-data-and-pipelines)
    - [Contributing to IIDDA Project Development](#contributing-to-iidda-project-development)
  - [Maintainer](#maintainer)
  - [Funding](#funding)

## Classic IIDDA

[David Earn](https://davidearn.mcmaster.ca) started the IIDDA project to make historical epidemiological data available to the research community. This GitHub repository replaces [classic IIDDA](https://davidearn.mcmaster.ca/iidda), which is currently offline. The classic IIDDA datasets are [here](pipelines/classic-iidda/digitizations).

## Featured Datasets

The following table contains links that will download a zip archive containing one or more datasets and [DataCite 4.3](https://doi.org/10.14454/7xq3-zf69) metadata, as well as links to these metadata. The metadata include lists of all of the files used to produce the associated dataset. To understand how these links work please go [here](#iidda-api). The datasets below are classified as unharmonized, harmonized, and normalized -- please see the section on [data harmonization](#data-harmonization) for an explanation of these terms.

### CANMOD Digitization Project

The [CANMOD](https://canmod.net) network funded the [systematic curation and digitization](https://canmod.net/digitization) of historical Canadian infectious disease data. Released data from this project appear in the table below.

> [!IMPORTANT]
> Please acknowledge any use of these data by [citing](CITATION.cff) this [preprint](https://www.medrxiv.org/content/10.1101/2024.12.20.24319425v1).

> [!WARNING]
> We’ve been noticing occasional temporary server issues that may cause the links below to fail.  
> Please [open an issue](https://github.com/canmod/iidda/issues) to let us know, and try again a bit later. We're working on it and thanks for your patience!


| Description                                            | Links                                                                                                                                                                                                                                        | Size   | Compressed | Breakdown          | Shortest Frequency                   | Time Range | Command to [reproduce](#reproducing-iidda-datasets)                     |
| ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ---------- | ------------------ | ------------------------------------ | ---------- | ----------------------------------------------------------------------- |
| Canadian Disease Incidence Data (CANDID), Unharmonized | [Data](https://math.mcmaster.ca/iidda/api/download?resource=csv&resource=metadata&dataset_ids=canmod-cdi-unharmonized), [Metadata](https://math.mcmaster.ca/iidda/api/metadata?string_comparison=Equals&dataset_ids=canmod-cdi-unharmonized) | 335MB  | 11.2MB     | prov/disease       | wk,mo,qr,yr (depending on breakdown) | 1903-2020  | `make derived-data/canmod-cdi-unharmonized/canmod-cdi-unharmonized.csv` |
| Canadian Disease Incidence Data (CANDID), Harmonized   | [Data](https://math.mcmaster.ca/iidda/api/download?resource=csv&resource=metadata&dataset_ids=canmod-cdi-harmonized),  [Metadata](https://math.mcmaster.ca/iidda/api/metadata?string_comparison=Equals&dataset_ids=canmod-cdi-harmonized)    | 266MB  | 9.1MB      | prov/disease       | wk,mo,qr,yr (depending on breakdown) | 1903-2020  | `make derived-data/canmod-cdi-harmonized/canmod-cdi-harmonized.csv`     |
| Canadian Disease Incidence Data (CANDID), Normalized   | [Data](https://math.mcmaster.ca/iidda/api/download?resource=csv&resource=metadata&dataset_ids=canmod-cdi-normalized),  [Metadata](https://math.mcmaster.ca/iidda/api/metadata?string_comparison=Equals&dataset_ids=canmod-cdi-normalized)    | 235MB  | 10.1MB     | prov/disease       | wk,mo,qr,yr (depending on breakdown) | 1903-2020  | `make derived-data/canmod-cdi-normalized/canmod-cdi-normalized.csv`     |
| Unharmonized population                                | [Data](https://math.mcmaster.ca/iidda/api/download?resource=csv&resource=metadata&dataset_ids=pop_ca_1871-1921_10-yearly_prov_age_sex&dataset_ids=pop_ca_1921-71_an_age_prov_sex&dataset_ids=pop_ca_1971-2021_an_age_prov_sex)               | 33.5MB | 2.5MB      | prov/sex/age-group | yr,10yr                              | 1881-2020  | Not a single command                                                    |
| Normalized population                                  | [Data](https://math.mcmaster.ca/iidda/api/download?resource=csv&resource=metadata&dataset_ids=canmod-pop-normalized),    [Metadata](https://math.mcmaster.ca/iidda/api/metadata?string_comparison=Equals&dataset_ids=canmod-pop-normalized)  | 2.5MB  | 0.5MB      | prov               | wk (interpolated)                    | 1881-2020  | `make derived-data/canmod-pop-normalized/canmod-pop-normalized.csv`     |

Name harmonization for the harmonized and normalized files is done using the following lookup tables.

* [Disease name lookup](lookup-tables/canmod-disease-lookup.csv)
  * Harmonized names are in `disease` and `nesting_disease`
  * Historical names are in `historical_disease`, `historical_disease_family`, and `historical_disease_subclass`
  * Remaining columns provide context and notes on how the mappings were chosen
* [Location name lookup](lookup-tables/canmod-location-lookup.csv)
  * Harmonized names are in `iso_3166` and `iso_3166_2` ([https://www.iso.org/iso-3166-country-codes](https://www.iso.org/iso-3166-country-codes.html))
  * Historical names are in `location`
  * Context for `location` is in `location_type`

The current results on cross-tabulations for checking data quality in this project can be found [here](https://math.mcmaster.ca/iidda/api/download?resource=csv&dataset_ids=canmod-disease-cross-check&dataset_ids=canmod-location-cross-check&dataset_ids=canmod-time-scale-cross-check).

An example of investigating the provenance of a strange smallpox record in these data is [here](https://canmod.github.io/iidda-tools/iidda.api/articles/Provenance).

## IIDDA API

> [!WARNING]
> We’ve been noticing occasional temporary server issues that may cause the IIDDA API to fail.  
> Please [open an issue](https://github.com/canmod/iidda/issues) to let us know, and try again a bit later. We're working on it and thanks for your patience!

The above tables contain links to featured data, but all data in the archive can be accessed using [this API](https://math.mcmaster.ca/iidda/api/docs).

The list of all [dataset IDs](#identifiers) in the API can be found [here](https://math.mcmaster.ca/iidda/api/metadata?string_comparison=Equals&response_type=dataset_ids). To download any of these datasets, along with their metadata, one may use the following URL formula.

```
https://math.mcmaster.ca/iidda/api/download?resource=csv&resource=metadata&dataset_ids={DATASET_ID}
```

There is also an [R binding of the API](https://canmod.github.io/iidda-tools/iidda.api/). Here is a [quick-start guide](https://canmod.github.io/iidda-tools/iidda.api/articles/Quickstart.html).

## Data Dictionary

All fields in IIDDA [datasets](#derived-data-and-tidy-datasets) must appear in the [data dictionary](https://github.com/canmod/iidda/blob/main/global-metadata/data-dictionary.json). If new fields must be added, a column metadata file needs to be added to [this directory](https://github.com/canmod/iidda/tree/main/metadata/columns).

## Data Harmonization

The [featured datasets](#featured-datasets) are each classified as one of the following types.

* **Unharmonized** : Minimally processed to allow data from different sources to be stored in the same [long-format](https://en.wikipedia.org/wiki/Wide_and_narrow_data) dataset.
* **Harmonized** : Excludes low quality records and includes location and disease names that simplify the combination of data from different sources (e.g., [poliomyelitis](https://en.wikipedia.org/wiki/Polio) whenever [infantile paralysis is reported historically](https://en.wikipedia.org/wiki/Polio#History) ).
* **Normalized** : Excludes overlapping data enabling aggregation without double-counting and facilitating integration of complementary data. All normalized datasets are also harmonized.

Please see the following references for background on these terms.

* [A general primer for data harmonization](https://doi.org/10.1038/s41597-024-02956-3)
* [Harmonization-information trade-offs for sharing individual participant data in biomedicine](https://doi.org/10.1162/99608f92.a9717b34)
* [Tidy data](http://www.jstatsoft.org/v59/i10/)

The files in [lookup-tables](lookup-tables) are used in the harmonization of historical names

## Reproducing IIDDA Datasets

> [!IMPORTANT]
> This is an advanced topic. If you would just like to access the data please see the [featured datasets](#featured-datasets), [links to classic IIDDA data](#classic-iidda), and the [IIDDA API](#iidda-api).

There are three alternatives each with different pros and cons.
1. [**Makefile (Host OS)**](#running-natively)
   *Runs natively on the host OS with `make` handling [dependencies](#dependency-management).*  
   **Pros:** Simple to set up, no container overhead, leverages native tools.  
   **Cons:** Requires `make` and other tools [installed](#requirements) on the host system.
2. [**Makefile (Docker)**](#running-in-a-docker-container)
   *Runs inside a Docker container with `make` managing dependencies.*  
   **Pros:** Ensures consistency across environments, isolates dependencies.  
   **Cons:** Slightly more complex setup, requiring Docker installation.
3. [**Interactive (e.g., RStudio)**](#running-interactively)  
   *Runs interactively in an IDE like RStudio on the host OS, without requiring `make` or `docker`.*  
   **Pros:** Easy for users unfamiliar with `make` or `docker`, ideal for debugging when [contributing data/code/fixes](#contributions).  
   **Cons:** Requires manual understanding of [dataset dependencies](#dependency-management), less automated.

### Running Natively

If you have all/most of the [requirements](#requirements) you could try taking the following three steps to make all of the derived datasets in the archive.

1. (one-time) Clone this repository
2. (one-time) `make install`
3. `make`

For instructions on making a specific dataset see the [Dependency Management](#dependency-management) section, but here is a simple example.
```
make derived-data/cdi_ca_1956_wk_prov_dbs/cdi_ca_1956_wk_prov_dbs.csv
```

### Running in a Docker Container

The [requirements](#requirements) are satisfied by a [docker](https://www.docker.com/) image that can be obtained with the following command.
```
docker pull stevencarlislewalker/iidda
```

With this image, one can skip steps 1 and 2 in the section on [Running Locally](#running-natively) and replace step 3 with the following command.
```
docker run --rm \
    -v "$(pwd):/usr/home/iidda" \
    stevencarlislewalker/iidda \
    make
```

Making specific datasets in the container can be done by modifying the `make` command to make a specific target. For example,
```
docker run --rm \
    -v "$(pwd):/usr/home/iidda" \
    stevencarlislewalker/iidda \
    make derived-data/cdi_ca_1956_wk_prov_dbs/cdi_ca_1956_wk_prov_dbs.csv
```

Datasets made in the container will be available in the `derived-data` directory, just as they would using `make` locally.

### Running Interactively

The simplest way to reproduce an IIDDA dataset is to go into the [pipelines](pipelines) directory, and use a tool like [Rstudio](https://posit.co/products/open-source/rstudio/) to work with a [source](#data-sources-and-pipelines) -- there is one source per sub-folder. Each source directory has sub-folders that may include any of the following.

* [`scans`](#source-data) -- Contains files of scans of original source documents.
* [`digitizations`](#source-data) -- Contains files in a format (typically `.xlsx` or `.csv`) that can be read into R or Python as tabular data as opposed to as images. Files in `digitizations` often have the same information as the files in `scans`, but in a format that is easier to read.
* [`prep-scripts`](#source-code) -- Contains scripts for generating a [tidy derived dataset](#derived-data-and-tidy-datasets) from the information in the other sub-folders.
* [`access-scripts`](#source-code) -- Contains scripts for programmatically obtaining `scans` or `digitizations`.

The scripts in `prep-scripts` can be run from the `iidda` project root directory to generate one or more datasets with metadata in a sub-folder of the top-level `derived-data` directory. 

> [!NOTE]
> The `derived-data` folder is not pushed to the central repository because its contents can be produced by running the `prep-scripts`.

> [!NOTE]
> This simple approach will not work if the dataset you are attempting to reproduce depends on another dataset that has not yet been made. You can find lists of the dependencies for a particular dataset in the [dataset-dependencies](dataset-dependencies) folder. If you have [make](https://www.gnu.org/software/make/) than you should be able to use this utility to [automatically respect these depenencies](#dependency-management).

### Dependency Management

The [Makefile](Makefile) can be used to build the entire `derived-data` directory by typing `make` into a terminal. To make a specific dataset `make derived-data/{DATASET_ID}/{DATASET_ID}.csv`. These commands require that all [_recommended_ requirements](#requirements) that must be met.

Dependencies are declared using the `.d` files in [dataset-dependencies](dataset-dependencies) folder, each of which lists the dependencies of the derived dataset of the same name. More technical dependencies (e.g., depending on the source metadata) do not need to be explicitly declared and are produced automatically in the `.d` files within the `derived-data` directory. The following table summarizes dependency declarations and automation.

| File Type                       | Purpose                                                                                                                                                 | Path Formula                                                                                                               |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Derived dataset                 | Generated data that is of interest                                                                                                                      | `derived-data/{DATASET_ID}/{DATASET_ID}.csv`                                                                               |
| User maintained dependency file | Manual editing allows user to manage the dependencies of the derived dataset                                                                            | [dataset-dependencies/{DATASET_ID}/{DATASET_ID}.d](dataset-dependencies/cdi_ca_1956_wk_prov_dbs/cdi_ca_1956_wk_prov_dbs.d) |
| Generated dependency file       | Updated version of the user maintained dependency file with technical changes that do not require user attention but are necessary for the build system | `derived-data/{DATASET_ID}/{DATASET_ID}.d`                                                                                 |

> [!NOTE]
> The `derived-data` directory is not pushed to the repository, because it is generated by pipelines. This is why only one of the path formulas above is associated with an active link. Most of the data declared in the [dataset-dependencies](dataset-dependencies) folder is pushed to the [API](#iidda-api) and can be accessed through there if you would not like to go through the trouble of [reproducing the datasets](#reproducing-iidda-datasets) yourself.

### Requirements

* Necessary
    * [R > 4.0](https://www.r-project.org/).
    * Have [Rscript](https://rdrr.io/cran/mark/man/rscript.html) on the path.
    * The [iidda](https://github.com/canmod/iidda-tools/tree/main/R/iidda), [iidda.analysis](https://github.com/canmod/iidda-tools/tree/main/R/iidda.analysis), and [iidda.api](https://github.com/canmod/iidda-tools/tree/main/R/iidda.api) R packages included in [iidda-tools](https://github.com/canmod/iidda-tools). Please follow these [instructions](https://github.com/canmod/iidda-tools?tab=readme-ov-file#for-users) to install all three packages.
    * [Make](https://www.gnu.org/software/make/).
* Recommended
    * Unix-like OS (includes macos).
    * Different R packages are used to create different derived datasets. The [r-package-recommendations-check.R](R/r-package-recommendations-check.R) script will install missing packages and check if any package versions are different from what the [maintainer](#maintainer) has used.
        * If you have `make` you should be able to run `make install` to get this package check (among other potentially useful things).
        * If you have `Rscript` you should be able to run `Rscript R/r-package-recommendations-check.R`.
* See [here](#contributing-to-iidda-project-development) for additional requirements that project maintainers must also satisfy.

## Project Structure

Although the project contains several top-level directories, the most import are [pipelines](pipelines), [dataset-dependencies](dataset-dependencies), `derived-data`, [metadata](metadata), and [lookup-tables](lookup-tables). The `derived-data` folder is not found within this central repository because its contents can be produced by running the [`prep-scripts`](#source-code). The following example illustrates the structure of these folders.

```
- pipelines
    - source_1
        - prep-scripts
            - prep-script_1.R
            - prep-script_1.R.json
            - ...
        - access-scripts
        - digitizations
            - digitization_1.xlsx
            - digitization_1.xlsx.json
            - ...
        - scans
            - scan_1.pdf
            - scan_1.pdf.json
            - ...
    - source_2
    - ...
- dataset-dependencies
    - tidy-dataset_1
        - tidy-dataset_1.d
    - tidy-dataset_2
        - tidy-dataset_2.d
    - ...
- derived-data
    - tidy-dataset_1
        - tidy-dataset_1.csv
        - tidy-dataset_1.json
        - tidy-dataset_1.d
    - tidy-dataset_2
        - tidy-dataset_2.csv
        - tidy-dataset_2.json
        - tidy-dataset_2.d
    - ...
- metadata
    - columns
        - column_1.json
        - column_2.json
        - ...
    - organizations
        - org_1.json
        - org_2.json
        - ...
    - sources
        - source_1.json
        - source_2.json
        - ...
    - tidy-datasets
        - tidy-dataset_1.json
        - tidy-dataset_2.json
        - ...
- lookup-tables
    - lookup-table-1.csv
    - lookup-table-2.csv
    - ...
```



### Data Sources and Pipelines

Data sources are folders in the `pipelines` directory containing [source data](#source-data) and [source code](#source-code). To create a new data source, create a new folder within the `pipelines` directory using a name that gives an [identifier](#identifiers) for the source.

#### Source Data

We distinguish between two types of source data: scans and digitizations. A scan is a file containing images of a hardcopy data source. We assume that such a file cannot be processed into a format that is usable by an epidemiologist without some form of manual data entry (although we recognize that AI is a fast moving field!). A digitization on the other hand is a file containing information that can be cleaned and processed using code. Examples of digitizations are `csv` and `xlsx` files, but also `pdf` files that can be reliably processed using data extraction tools. Scans of books on the other hand cannot be processed using such tools.

To [contribute source data](#contributing-source-data-and-pipelines), create a new [data source](#data-sources-and-pipelines) or find an existing source. Within this source folder create `scans` and/or `digitizations` folders to place each scan and digitization file. The file name with the extension removed will become the unique identifier for that resource so follow the [rules and guidelines](#identifiers) when creating these names. For each file, create a metadata file of the same name but with `.json` added after the existing extension. See other data sources for valid formats for scans and digitizations. Here is a typical example of a [source](pipelines/cdi_ca_1975-78_wk_prov) with [scans](pipelines/cdi_ca_1975-78_wk_prov/scans) and [digitizations](pipelines/cdi_ca_1975-78_wk_prov/digitizations) folders.

#### Source Code

We distinguish between two types of source data: prep scripts and access scripts. A prep script is used to convert a digitization or set of digitizations into a tidier dataset or to support one or more such scripts. An access script is used to automatically access another data archive or portal to produce a file to be placed in a `digitizations` or `scans` folder. Source code file names should follow the same rules as [source-data](#source-data) and are also each associated with a metadata file following the convensions outlined in [source-data](#source-data). Here is a typical example of a [source](pipelines/pop_ca_1971-2021_an_age_prov_sex) with both [prep-script](pipelines/pop_ca_1971-2021_an_age_prov_sex/prep-scripts) and [access-script](pipelines/pop_ca_1971-2021_an_age_prov_sex/access-scripts) folders.


### Derived Data and Tidy Datasets

The data sources in the `pipelines` folder can be used to produce derived data that has been 'tidied'. These datasets are the ultimate goal of all of this. Each dataset has [metadata](#metadata). See [here](#reproducing-iidda-datasets) for how to reproduce all of these datasets, and for pointers on how to avoid going through the trouble of reproducing them.

### Identifiers

The following types of entities in the archive are each associated with a unique and human readable identifier that will never change.

* [sources](#data-sources-and-pipelines)
* [tidy-datasets](#derived-data-and-tidy-datasets)
* [columns](#data-dictionary)
* [digitizations](#source-data)
* [scans](#source-data)
* [prep-scripts](#source-code)
* [access-scripts](#source-code)

For example, the dataset [cdi_bot_ca_1933-55_wk_prov](metadata/tidy-datasets/cdi_bot_ca_1933-55_wk_prov.json) contains data on the communicable disease incidence (`cdi`) of botulism (`bot`) in Canada (`ca`) from 1933-55 (`1933-55`) weekly (`wk`) broken down by province (`prov`). Examples of entities include data sources, resources within a data source (e.g., a scan of an old book), and datasets that can be derived from source material.

We do our best to keep the underscore-delimited format of the identifiers consistent, but our only promises about the identifiers are as follows.

* They contain only lowercase letters, digits, underscores, and dashes.
* They never change.
* Along with the type of entity, they uniquely identify an entity.

To clarify the last point, no two entities of the same type have the same identifier, but different types of entities can share an identifier to indicate a close association. For example a [tidy dataset](#derived-data-and-tidy-datasets) and the [prep script](#prep-scripts) that produces it should have the same identifier. 

Dots cannot be used in dataset identifiers as they would interfere with assumptions made by the [tools](https://github.com/canmod/iidda-tools).

### Metadata

All entities associated with an [identifier](#identifiers) are also associated with metadata. The following table illustrates how to find the metadata for each type of entity.

| Type of Entity                                  | Synonym      | Path Formula (with example link)                                                                                                                                  |
| ----------------------------------------------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Source](#data-sources-and-pipelines)           | Pipeline     | [metadata/sources/{SOURCE_ID}.json](metadata/sources/cdi_ca_1956-63_1973-74_wk_prov.json)                                                                         |
| [Tidy Dataset](#derived-data-and-tidy-datasets) | Derived Data | [metadata/sources/{DATASET_ID}.json](metadata/tidy-datasets/cdi_ca_1956_wk_prov_dbs.json)                                                                         |
| [Column](#data-dictionary)                      |              | [metadata/columns/{COLUMN_NAME}.json](metadata/columns/cases_this_period.json)                                                                                    |
| [Digitization](#source-data)                    |              | [pipelines/{SOURCE_ID}/digitizations/{DIGITIZATION_ID}.{FILE_EXT}.json](pipelines/cdi_ca_1956-63_1973-74_wk_prov/digitizations/cdi_ca_1956_wk_prov_dbs.xlsx.json) |
| [Scan](#source-data)                            |              | [pipelines/{SOURCE_ID}/scans/{SCAN_ID}.{FILE_EXT}.json](pipelines/cdi_ca_1956-63_1973-74_wk_prov/scans/cdi_ca_1956_wk_prov_dbs.pdf.json)                          |
| [Prep Script](#source-code)                     |              | [pipelines/{SOURCE_ID}/prep-scripts/{PREP_ID}.{FILE_EXT}.json](pipelines/cdi_ca_1956-63_1973-74_wk_prov/prep-scripts/cdi_ca_1956_wk_province_dbs.R.json)          |
| [Access Script](#source-code)                   |              | [pipelines/{SOURCE_ID}/access-scripts/{ACCESS_ID}.{FILE_EXT}.json](pipelines/pop_ca_1971-2021_an_age_prov_sex/access-scripts/statcan_api.py.json)                 |


Ultimately we want to remove the need for synonyms, which arose organically while producing the archive.

### Lookup Tables

The datasets in the [lookup-tables](lookup-tables) folder are useful for [data harmonization](#data-harmonization). Each lookup table is produced in a partially manual and partially automated manner. Each lookup table is associated with a [derived dataset](#derived-data-and-tidy-datasets) that summarizes all of the unique historical names in the datasets declared in the [`.d` dependency file](#dependency-management) for that dataset. The script that produces this derived dataset also produces a lookup table, which has additional columns that define the harmonized names. If new historical names are discovered an error message is given prompting the pipeline author to update the lookup table with harmonized names for the new historical names. Once this lookup table contains harmonized names for all historical names, it can be used to harmonize the names of any dataset through a [dataset join](https://dplyr.tidyverse.org/reference/mutate-joins.html). This manual/automated hybrid is an example of a [human-in-the-loop](https://en.wikipedia.org/wiki/Human-in-the-loop) system.


## Contributions

Thank you :pray:

### Contributing Source Data and Pipelines

Just create a sub-folder of [pipelines](pipelines), and place source data in its `digitizations` or `scans` sub-folders.

That's it ... unless you want a gold star, in which case please do contribute [prep script source code](#source-code) and do as much of the following as possible.

* Before embarking on prep scripting, please make sure that [these requirements](#requirements) are satisfied.
* Write R scripts that prepare these data using [valid IIDDA columns](metadata/columns) -- see `?iidda::register_prep_script` before starting.
* Generate valid [IIDDA metadata](#metadata) for [data sources](metadata/sources), [derived data](metadata/tidy-datasets), and source data using  `iidda::register_prep_script`.

This is probably not enough information, but if you are interested in contributing please contact the [maintainer](#maintainer) who would be happy to help and perhaps expand the docs on how to contribute.

### Contributing Fixes to Data and Pipelines

Make a changes to something in the [pipelines](pipelines) folder and open a [pull request](https://github.blog/developer-skills/github/beginners-guide-to-github-creating-a-pull-request/). If you are just fixing data entry errors, that's all there is to do. If you are fixing code please read [Reproducing IIDDA Datasets](#reproducing-iidda-datasets).

### Contributing to IIDDA Project Development

Please contact the [maintainer](#maintainer) if you would like to contribute more than data and pipelines for processing them.

There are additional [requirements](#requirements) for those involved in project development.

* [Python >= 3.9](https://www.python.org/).
* [iidda-utilities](https://github.com/canmod/iidda-utilities) (Private repo of Python and R tools. Contact the [maintainer](#maintainer) for access.)
* The [iidda_api](https://github.com/canmod/iidda-tools/tree/main/python/iidda_api) Python package included in [iidda-tools](https://github.com/canmod/iidda-tools).

This additional setup allows one to deploy datasets to the [IIDDA API](#iidda-api) using `make` commands of the following type.
```
make derived-data/{DATASET_ID}/{DATASET_ID}.deploy
```

One may also delete dataset versions from the API using the `DeleteVersions` class in the `iidda-utilities` python package. There is a [make rule](Makefile) that cleans up all old versions, which is necessary from time to time to maintain performance.

```
make delete-all-but-latest-versions
```

In the future we should archive these old versions somewhere else for reproducibility.

## Maintainer

https://github.com/stevencarlislewalker

## Funding

This work was supported by NSERC through the [CANMOD](https://canmod.net) network.
