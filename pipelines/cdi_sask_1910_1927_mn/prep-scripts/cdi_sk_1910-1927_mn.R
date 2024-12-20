## ======================================================
## This script has been automatically modified,
## so please do not manually modify it.
## ======================================================


# There is also mortality data for 1910 that is not being made into a 
# tidy_dataset, and there is mortality data that is not digitized for 1927 and 1926

# ----------------------------------------
# Information for Locating Metadata
tidy_dataset = "cdi_sk_1910-1927_mn"
digitization = "cdi_sk_1910-1927_mn"
metadata_path = "pipelines/cdi_sask_1910_1927_mn/tracking"
# ----------------------------------------

options(conflicts.policy = list(warn.conflicts = FALSE))
# remotes::install_github('canmod-eidm/iidda-tools', subdir = 'R/iidda')
library(dplyr)
library(iidda)
library(zoo)
library(unpivotr)
library(lubridate)

get_sheet_names =function(data){
  grep("^19[0-5]+[0-9]+", unique(data$sheet), value = TRUE)
}

behead_sheet = function(focal_sheet, data) {
  if(focal_sheet == '1910'){
  (data
   %>% filter(sheet == focal_sheet,
              between(row, 3, 17),
              between(col, 1, 22))
   %>% select(row, col, data_type, numeric, character)
   %>% behead('N', historical_disease)
   %>% behead('N', stat_name)
   %>% behead('W', month)
  )}
  
  else{
    (data
     %>% filter(sheet == focal_sheet,
                between(
                  row,
                  3,
                  if (focal_sheet == '1921') {
                    18
                  } else if (focal_sheet == '1922') {
                    20
                  } else if (focal_sheet == '1923') {
                    26
                  } else if (focal_sheet == '1924') {
                    28
                  } else {
                    27
                  }),
                between(
                  col,
                  1,
                  if (focal_sheet %in% c('1921', '1922', '1926')) {
                    14
                  } else {
                    13
                  }))
     %>% select(row, col, data_type, numeric, character)
     %>% behead('N', month)
     %>% behead('W', historical_disease)
     %>% mutate(stat_name = 'Cases')
    )}
}

clean_sheet=function(beheaded_sheet, focal_sheet){
  (beheaded_sheet
   
   %>% mutate(historical_disease = na.locf(historical_disease))
   %>% unite(cases_this_period, c(numeric, character), sep='', na.rm=TRUE)
   
   %>% mutate(month = sub('\\.', '', month))
 
   %>% mutate(month = ifelse(month == 'Sept', 'Sep', month))
   
   # Creating period start and end dates
   %>% mutate(period_start_date = as.Date(paste(focal_sheet, month, 1), format = "%Y %B %d"))
   %>% mutate(period_end_date = floor_date(period_start_date + months(1), unit = "month") - days(1))
   
   %>% mutate(period_start_date = ifelse(
     grepl("Total", month),
     as.Date(paste(as.numeric(focal_sheet), 'January', 1), format = "%Y %B %d"),
     period_start_date))
   
   %>% mutate(period_end_date = ifelse(
     grepl("Total", month),
     as.Date(paste(as.numeric(focal_sheet), 'December', 31), format = "%Y %B %d"),
     period_end_date))
   
   %>% mutate(cases_this_period = ifelse(
     cases_this_period %in% c('-', '..'), 
     0,
     cases_this_period
   ))
   
   %>% mutate(period_end_date = as.Date(period_end_date), period_start_date = as.Date(period_start_date))
   
   %>% mutate(location = 'SASK.')
   
   %>% filter(historical_disease != 'Totals')
   
   %>% select(location, period_start_date, period_end_date, historical_disease,
              cases_this_period, stat_name)
   
  )
}

combine_sheets = function(cleaned_sheets){
  # Combining sheets.
  combined= (bind_rows(cleaned_sheets, .id='sheet')
             %>% filter(stat_name == 'Cases')
             %>% select(-sheet, -stat_name) )
}

metadata = get_tracking_metadata(tidy_dataset, digitization, metadata_path, original_format = FALSE) # iidda

data = read_digitized_data(metadata) # iidda

sheets = get_sheet_names(data) # local

beheaded_sheets = sapply(sheets, behead_sheet, data = data, simplify = FALSE) # local

cleaned_sheets = mapply(clean_sheet, beheaded_sheets, sheets, SIMPLIFY=FALSE) #local

tidy_data = combine_sheets(cleaned_sheets) # local

data_with_scales = identify_scales(tidy_data) # iidda

data_with_scales = add_provenance(data_with_scales, tidy_dataset) # iidda

metadata = add_column_summaries(data_with_scales, tidy_dataset, metadata) # iidda

files = write_tidy_data(data_with_scales, metadata) # iidda
