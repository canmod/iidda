Canadian School Term Data
=========================

[![Lifecycle:Experimental](https://img.shields.io/badge/Lifecycle-Experimental-339999)](<Redirect-URL>)

# Derived Data

[OCR digitized Canadian school term data from 2011-2019](https://raw.githubusercontent.com/davidearn/iidda/master/data/school-terms-canada/derived-data/ocr-extracts.csv)

# Source Data

* [2018-2019](https://raw.githubusercontent.com/davidearn/iidda/master/data/school-terms-canada/source-data/EdCanNet_2018-2019-School-Calendar_v1.pdf)
* [2017-2018](https://raw.githubusercontent.com/davidearn/iidda/master/data/school-terms-canada/source-data/2017-2018-School-Calendar_v8.pdf)
* [2016-2017](https://raw.githubusercontent.com/davidearn/iidda/master/data/school-terms-canada/source-data/cea-2016-2017-school-calendar_v7.pdf)
* [2015-2016](https://raw.githubusercontent.com/davidearn/iidda/master/data/school-terms-canada/source-data/cea-2015-2016-school-calendar_rev6.pdf)
* [2014-2015](https://raw.githubusercontent.com/davidearn/iidda/master/data/school-terms-canada/source-data/cea-2014-2015-school-calendar_rev4.pdf)
* [2013-2014](https://raw.githubusercontent.com/davidearn/iidda/master/data/school-terms-canada/source-data/cea-2013-2014-school-calendar-rev3.pdf)
* [2012-2013](https://raw.githubusercontent.com/davidearn/iidda/master/data/school-terms-canada/source-data/cea-2012-2013-school-calendar.pdf)
* [2011-2012](https://raw.githubusercontent.com/davidearn/iidda/master/data/school-terms-canada/source-data/cea-2011-2012-school-calendar.pdf)

# Data Derivation Process

[This R script](https://github.com/davidearn/iidda/blob/main/data/school-terms-canada/conversion-scripts/school_term_ocr.R) is executed within a docker container produced from a docker image created by [this dockerfile](https://github.com/davidearn/iidda/blob/main/data/school-terms-canada/dockerfile). The dependencies for the R script can be found [here](https://github.com/stevencarlislewalker/iidda-tools/tree/main/R/iidda/R).

# Data Access Method

On 2021-07-19, the PDF files containing the source data were accessed here:

* (https://www.edcan.ca/wp-content/uploads/EdCanNet_2018-2019-School-Calendar_v1.pdf)
* (https://www.edcan.ca/wp-content/uploads/2017-2018-School-Calendar_v8.pdf)
* (http://www.edcan.ca/wp-content/uploads/cea-2016-2017-school-calendar_v7.pdf)
* (http://www.edcan.ca/wp-content/uploads/cea-2015-2016-school-calendar_rev6.pdf)
* (http://www.edcan.ca/wp-content/uploads/cea-2014-2015-school-calendar_rev4.pdf)
* (http://www.edcan.ca/wp-content/uploads/cea-2013-2014-school-calendar-rev3.pdf)
* (http://www.edcan.ca/wp-content/uploads/cea-2012-2013-school-calendar.pdf)
* (http://www.edcan.ca/wp-content/uploads/cea-2011-2012-school-calendar.pdf)
