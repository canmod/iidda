library(dplyr)
library(magick)
library(tidyr)

source('iidda-tools/R/iidda/R/school_term_ocr_functions.R')

input_metadata = list(
    year = 2018:2011,
    pdf_files = c(
        "EdCanNet_2018-2019-School-Calendar_v1.pdf", "2017-2018-School-Calendar_v8.pdf", "cea-2016-2017-school-calendar_v7.pdf", "cea-2015-2016-school-calendar_rev6.pdf", "cea-2014-2015-school-calendar_rev4.pdf", "cea-2013-2014-school-calendar-rev3.pdf", "cea-2012-2013-school-calendar.pdf", "cea-2011-2012-school-calendar.pdf"),
    yearly_page_ranges = list(
        3:8,
        3:8,
        3:8,
        3:9,
        3:6,
        3:6,
        3:6,
        3:6))

stopifnot(
    all(
        list.files('source-data') %in% 
        input_metadata$pdf_files))
pdf_files = paste0('source-data/', input_metadata$pdf_files)

output = yearly_output = list()

for(file in 1:length(input_metadata$year)) {
    pdf_image = image_read(
        pdf_files[file], 
        density = 200)[input_metadata$yearly_page_ranges[[file]]]
    output[[file]] = list()

    for(page in seq_along(input_metadata$yearly_page_ranges[[file]])) {
        print(page)
        output[[file]][[page]] = try(school_term_ocr(pdf_image, page))
    }

    yearly_output[[file]] =
        Negate(function(x){class(x) == 'try-error'}) %>%
        Filter(output[[file]]) %>%
        dplyr::bind_rows() %>%
        mutate(province = zoo::na.locf(province)) %>%
        mutate(year = input_metadata$year[file])
    write.csv(
        dplyr::bind_rows(yearly_output),
        'derived-data/ocr-extracts.csv',
        row.names = FALSE)
}
