## ======================================================
## This script has been automatically modified,
## so please do not manually modify it.
## ======================================================


# ----------------------------------------
# Information for Locating Metadata
mort_dataset = "mort_on_1903-1939_mn"
cdi_dataset = "cdi_on_1903-1939_mn"
digitization = "cdi_mort_on_1903-1939_mn"
metadata_path = "pipelines/cdi_mort_on_1903-1939_mn/tracking"
# ----------------------------------------

options(conflicts.policy = list(warn.conflicts = FALSE))
# remotes::install_github('canmod-eidm/iidda-tools', subdir = 'R/iidda')
library(dplyr)
library(iidda)
library(unpivotr)
library(zoo)
library(lubridate)

get_sheet_names =function(data){
  grep("^19[0-5]+[0-9]+", unique(data$sheet), value = TRUE)
}

behead_sheet = function(focal_sheet, data) {
  (data
       %>% filter(sheet == focal_sheet,
                  between(
                    row,
                    3,
                    if (as.numeric(focal_sheet) <= 1922) {
                      17
                    } else if (as.numeric(focal_sheet) >= 1924) {
                      19
                    } else {
                      18
                    }),
                  between(
                    col,
                    if (as.numeric(focal_sheet) > 1908 && as.numeric(focal_sheet) < 1911) {
                      2
                    } else {
                      1
                    },
                    max(col)))

       %>% select(row, col, data_type, numeric, character)
       %>% behead('N', historical_disease)
       %>% behead('N', stat_name)
       %>% behead('W', month)
      )
}

clean_sheet=function(beheaded_sheet, focal_sheet){
  (beheaded_sheet

      # Filtering out data that is not being used
      %>% filter(!(stat_name %in%
                     c('Municipalities Reporting', 'Population', 'Population reported on.', 'Population reporting')))

      %>% mutate(historical_disease = na.locf(historical_disease))
      %>% unite(cases_this_period, c(numeric, character), sep='', na.rm=TRUE)

      # Creating period start and end dates
      %>% mutate(period_start_date = as.Date(paste(focal_sheet, month, 1), format = "%Y %B %d"))
      %>% mutate(period_end_date = floor_date(period_start_date + months(1), unit = "month") - days(1))

      # Creating year start and end dates
      %>% mutate(period_start_date = ifelse(
        is.na(period_start_date), as.Date(paste(focal_sheet, 'January', 1), format = "%Y %B %d"),
        period_start_date))
      %>% mutate(period_end_date = ifelse(
        is.na(period_end_date), as.Date(paste(focal_sheet, 'December', 31), format = "%Y %B %d"),
        period_end_date))

      %>% mutate(period_start_date = ifelse(
        grepl('Total|rate', historical_disease, ignore.case = TRUE),
        as.Date(paste(focal_sheet, 'January', 1), format = "%Y %B %d"),
        period_start_date))

      %>% mutate(period_end_date = ifelse(
        grepl('Total|rate', historical_disease, ignore.case = TRUE),
        as.Date(paste(focal_sheet, 'December', 31), format = "%Y %B %d"),
        period_end_date))

      # Converting cases that are only dots '.' to 'Not available'
      %>% mutate(cases_this_period = ifelse(
        grepl("^\\.+[^0-9.]*$|-|….", cases_this_period),
        'Not available',
        cases_this_period
      ))

      %>% filter(!(is.na(cases_this_period)))

      # Creating cases_prev_period and cases_two_years_ago
      %>% mutate(cases_prev_period = ifelse(
        grepl("19[0-5]+[0-9]+", month) &
          (as.numeric(focal_sheet) - as.numeric(gsub("\\D", "", month)) == 1),
        cases_this_period,
        ''
      ))

      # Creating cases_two_years_ago
      %>% mutate(cases_two_years_ago = ifelse(
        grepl("19[0-5]+[0-9]+", month) &
          (as.numeric(focal_sheet) - as.numeric(gsub("\\D", "", month)) == 2),
        cases_this_period,
        ''
      ))

      %>% mutate(cases_this_period = ifelse(
        cases_this_period == cases_prev_period | cases_this_period == cases_two_years_ago,
        '',
        cases_this_period
      ))


      %>% mutate(period_end_date = as.Date(period_end_date), period_start_date = as.Date(period_start_date))

      %>% mutate(stat_name = ifelse(
        grepl('Total|rate', historical_disease, ignore.case = TRUE),
        'Deaths',
        stat_name
      ))

      %>% filter(!(is.na(stat_name)))

      %>% mutate(location = 'ONT.')

      %>% select(location, period_start_date, period_end_date, historical_disease,
                 cases_this_period, cases_prev_period, cases_two_years_ago, stat_name)

      )
}


combine_sheets = function(cleaned_sheets){
  # Combining sheets.
  combined= (bind_rows(cleaned_sheets, .id='sheet')
             %>% select(-sheet) )
}

# Mortality data

metadata = get_tracking_metadata(mort_dataset, digitization, metadata_path, original_format = FALSE) # iidda

data = read_digitized_data(metadata) # iidda

sheets = get_sheet_names(data) # local

beheaded_sheets = sapply(sheets, behead_sheet, data = data, simplify = FALSE) # local

cleaned_sheets = mapply(clean_sheet, beheaded_sheets, sheets, SIMPLIFY=FALSE) #local

tidy_data = combine_sheets(cleaned_sheets) #local

data_with_scales = identify_scales(tidy_data) # iidda

tidy_mort = filter(data_with_scales, stat_name == 'Deaths') |> select(-stat_name)

#tidy_mort = add_provenance(tidy_mort, mort_dataset) # iidda

metadata_mort = add_column_summaries(tidy_mort, mort_dataset, metadata) # iidda

files_mort = write_tidy_data(tidy_mort, metadata_mort) # iidda

# CDI data

metadata = get_tracking_metadata(cdi_dataset, digitization, metadata_path, original_format = FALSE) # iidda

data = read_digitized_data(metadata) # iidda

sheets = get_sheet_names(data) # local

beheaded_sheets = sapply(sheets, behead_sheet, data = data, simplify = FALSE) # local

cleaned_sheets = mapply(clean_sheet, beheaded_sheets, sheets, SIMPLIFY=FALSE) #local

tidy_data = combine_sheets(cleaned_sheets) #local

data_with_scales = identify_scales(tidy_data) # iidda

tidy_cdi = filter(data_with_scales, stat_name == 'Cases') |> select(-stat_name)

tidy_cdi = add_provenance(tidy_cdi, cdi_dataset) # iidda

metadata_cdi = add_column_summaries(tidy_cdi, cdi_dataset, metadata) # iidda

files_cdi = write_tidy_data(tidy_cdi, metadata_cdi) # iidda
