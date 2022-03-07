# Data Folder Organization

![Status:Draft](https://img.shields.io/static/v1.svg?label=Status&message=Draft&color=yellow)

At the top-level of the `data` directory we have a set of folders -- one for every data source. Within each data source there are the following items.

* `README.md` file
* `packaging-scripts` folder
* `source-data` folder
* `derived-data` folder
* (optional) `intermediate-data` folder

The `packaging-scripts` folder contains scripts for releasing the data source as a zip archive, which will presumably be pushed somewhere like a GitHub release,  Zenodo, AWS S3, FRDR). (TODO: Guidelines for the `packaging-scripts` folder are currently outstanding).

The `source-data` folder contains the data files that are obtained from contributors, as well as files that were manually created from those original sources (e.g. Excel spreadsheets that represent digitized versions of scanned PDF documents).

The `derived-data` folder may contain one or more files, which provide some or all of the information in the files in the `source-data` folder. The purpose of these `derived-data` files is to be as faithful as possible to the information in the original sources, but formatted in a manner that is more convenient for programmatic use. Requirements for the `derived-data` folder are provided [here](https://github.com/canmod/iidda/blob/main/docs/data-format-standards.md).

The optional `intermediate-data` folder is for automated conversions of the `source-data` into formats that are more convenient for the processing scripts in the `derived-data` folder. This `intermediate-data` folder has the same structure as `derived-data`, but without the metadata. The scripts in the `derived-data` folder can use `intermediate-data` instead of (or as well as) `source-data`.
