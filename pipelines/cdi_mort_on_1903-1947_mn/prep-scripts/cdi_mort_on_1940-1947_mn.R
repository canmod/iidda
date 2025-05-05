

# ----------------------------------------
# Information for Locating Metadata
mort_dataset = "mort_on_1940-1947_mn"
cdi_dataset = "cdi_on_1940-1947_mn"
digitization = "cdi_mort_on_1940-1947_mn"
metadata_path = "pipelines/cdi_mort_on_1940-1947_mn/tracking"
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
              between(row, 3, 32),
              between(col, 1, 31))
   %>% select(row, col, data_type, numeric, character)
   %>% behead('N', month)
   %>% behead('N', stat_name)
   %>% behead('W', historical_disease)
  )
}

clean_sheet=function(beheaded_sheet, focal_sheet){
  (beheaded_sheet

   %>% mutate(month = na.locf(month))
   %>% unite(cases_this_period, c(numeric, character), sep='', na.rm=TRUE)

   # Creating period start and end dates
   %>% mutate(period_start_date = as.Date(paste(focal_sheet, month, 1), format = "%Y %B %d"))
   %>% mutate(period_end_date = floor_date(period_start_date + months(1), unit = "month") - days(1))

   %>% mutate(period_start_date = ifelse(
     grepl("^19[0-5]+[0-9]+", month),
     as.Date(paste(as.numeric(focal_sheet), 'January', 1), format = "%Y %B %d"),
     period_start_date))

   %>% mutate(period_end_date = ifelse(
     grepl("^19[0-5]+[0-9]+", month),
     as.Date(paste(as.numeric(focal_sheet), 'December', 31), format = "%Y %B %d"),
     period_end_date))

   # Creating cases_prev_period
   %>% mutate(cases_prev_period = ifelse(
     grepl("^19[0-5]+[0-9]+", month) &
     as.numeric(focal_sheet) - as.numeric(month) == 1,
     cases_this_period,
     ''
   ))

   # Creating cases_two_years_ago
   %>% mutate(cases_two_years_ago = ifelse(
     grepl("^19[0-5]+[0-9]+", month) &
     as.numeric(focal_sheet) - as.numeric(month) == 2,
     cases_this_period,
     ''
   ))

   %>% mutate(cases_this_period = ifelse(
     cases_this_period == cases_prev_period | cases_this_period == cases_two_years_ago,
     '',
     cases_this_period
   ))

   %>% mutate(cases_this_period = ifelse(
     cases_this_period == '-',
     0,
     cases_this_period
   ))

   %>% mutate(period_end_date = as.Date(period_end_date), period_start_date = as.Date(period_start_date))

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
