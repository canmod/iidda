## ======================================================
## This script has been automatically modified,
## so please do not manually modify it.
## ======================================================


# ----------------------------------------
# Information for Locating Metadata
tidy_dataset = "cdi_qc_1915-1925_mn_county_municipality"
digitization = "cdi_qc_1915-1925_mn_county_municipality"
metadata_path = "pipelines/cdi_qc_1895-1925_1927-31_mn_munic/tracking"
# ----------------------------------------

options(conflicts.policy = list(warn.conflicts = FALSE))
# remotes::install_github('canmod-eidm/iidda-tools', subdir = 'R/iidda')
library(dplyr)
library(iidda)
library(zoo)
library(unpivotr)
library(lubridate)
library(stringr)

get_sheet_names =function(data){
  grep('^[a-zA-Z]{3}_\\d{4}$', unique(data$sheet), value = TRUE)
}

# Extract month and year from each sheet
get_sheet_info = function(focal_sheet, data){
  year = (data
          %>% filter(address == 'A2', sheet==focal_sheet)
          %>% .$character
          %>% str_extract("\\b\\d{4}\\b"))
  
  month = (data
           %>% filter(address == 'A2', sheet==focal_sheet)
           %>% .$character
           %>% gsub("(?i)\\bin\\b", '', .)
           %>% str_extract("\\b[A-Za-z]+\\b"))
  
  nlist(year, month)
}

behead_sheet = function(focal_sheet, data) {
  (data
   %>% filter(sheet == focal_sheet, between(row, 3, max(row)-2), between(col, 1, 12))
   %>% select(row, col, data_type, numeric, character)
   %>% behead('N', historical_disease)
   %>% behead('W', county)
   %>% behead('W', municipality)
  )
}

clean_sheet = function(beheaded_sheet, focal_sheet_info){
  beheaded_sheet$county = na.locf(beheaded_sheet$county, na.rm = FALSE) 
  
 
    (beheaded_sheet
    # This line isn't working, but the first line replaces it
    # %>% mutate(county = na.locf(county), na.rm = FALSE)
    
     %>% mutate(county = ifelse(is.na(county), 'Quebec', county))
     
     %>% unite(cases_this_period, c(numeric, character), sep='', na.rm=TRUE)
     %>% mutate(cases_this_period = ifelse(cases_this_period %in% c('-', '-'), 0, cases_this_period))
     %>% mutate(cases_this_period = ifelse(grepl('\\…|\\.', cases_this_period), 0, cases_this_period))
    
     # Creating period start and end dates
     %>% mutate(period_start_date = as.Date(paste(focal_sheet_info$year, focal_sheet_info$month, 1), format = "%Y %B %d"))
     %>% mutate(period_end_date = floor_date(period_start_date + months(1), unit = "month") - days(1))
    
     %>% rename(location = municipality)
     %>% mutate(location = ifelse(location == 'Quebec', 'Quebec City', location))
     %>% mutate(location_type = 'municipality')
    
    # making Quebec total
     %>% mutate(location_type = ifelse(grepl('total', location, ignore.case = TRUE), 
                       'province', location_type))
     %>% mutate(county = ifelse(grepl('total', location, ignore.case = TRUE), 
                                      NA, county))
     %>% mutate(location = ifelse(grepl('total', location, ignore.case = TRUE), 
                                  'Quebec', location))
     
     %>% select(historical_disease, location, county, cases_this_period, 
                period_start_date, period_end_date, location_type)
    
    %>% rename(nesting_location = county)
    %>% filter(!is.na(location))
    
    %>% filter(!(is.na(location)))
    %>% mutate(time_scale = 'mo')
    %>% mutate(location = trimws(location))
    %>% mutate(nesting_location = ifelse(is.na(nesting_location), '', nesting_location))
   )
  
}

combine_sheets = function(cleaned_sheets){
  combined = ((bind_rows(cleaned_sheets, .id='sheet')) 
              %>% select(-sheet)
              %>% filter(!(cases_this_period == 'x'))
  )
}

metadata = get_tracking_metadata(tidy_dataset, digitization, metadata_path, original_format = FALSE) # iidda

data = read_digitized_data(metadata) # iidda

sheets = get_sheet_names(data) # local

beheaded_sheets = sapply(sheets, behead_sheet, data = data, simplify = FALSE) # local

sheet_info = sapply(sheets, get_sheet_info, data=data, simplify=FALSE) # local

cleaned_sheets = mapply(clean_sheet, beheaded_sheets, sheet_info, SIMPLIFY=FALSE) # local

tidy_data = combine_sheets(cleaned_sheets) # local

tidy_data = add_provenance(tidy_data, tidy_dataset) # iidda

metadata = add_column_summaries(tidy_data, tidy_dataset, metadata) # iidda

files = write_tidy_data(tidy_data, metadata) # iidda
