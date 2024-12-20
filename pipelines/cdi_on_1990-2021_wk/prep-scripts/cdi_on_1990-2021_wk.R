## ======================================================
## This script has been automatically modified,
## so please do not manually modify it.
## ======================================================


# ----------------------------------------
# Information for Locating Metadata
tidy_dataset = "cdi_on_1990-2021_wk"
digitization = "cdi_on_1990-2021_wk"
metadata_path = "pipelines/cdi_on_1990-2021_wk/tracking"
# ----------------------------------------

options(conflicts.policy = list(warn.conflicts = FALSE))
# remotes::install_github('canmod-eidm/iidda-tools', subdir = 'R/iidda')
library(plyr)
library(dplyr)
library(iidda)
library(tidyxl)
library(unpivotr)
library(tidyr)
library(zoo)
library(lubridate)
library(stringr)
library(purrr)

get_sheet_names = function(data){
  grep("\\d{4}", unique(data$sheet), value = TRUE)
}

behead_sheet = function(focal_sheet, data) {
  if(focal_sheet == 2019){
    beheaded = 
      (data
      %>% filter(sheet == focal_sheet)
      %>% select(row, col, data_type, numeric, character)
      %>% filter(col!=55)
      %>% behead('N', week)
      %>% behead('W', disease)
      %>% behead('W', classification)
    )
  }
  
  else{
    beheaded = 
      (data
      %>% filter(sheet == focal_sheet)
      %>% select(row, col, data_type, numeric, character)
      %>% behead('N', week)
      %>% behead('W', disease)
      %>% behead('W', classification)
    )
  }
  
  beheaded
}

clean_sheet = function(beheaded_sheet, focal_sheet){
  focal_sheet = as.numeric(focal_sheet)
  # getting epi-week end dates for the year
  enddates = epiweek_end_date(focal_sheet, 1:52)
  startdates = enddates - 6

  # getting epi-week end dates for previous year, for 53 weeks
  prevenddates = epiweek_end_date(focal_sheet-1, 1:53)

  # if the last epi week end date of the previous year isn't equal to the first
  # end date of the current year, there are 53 weeks in the previous year.
  if(prevenddates[length(prevenddates)] != enddates[1]){
    # this 53rd week of the previous year is combined with week one of the current
    # year - so change the first start date to be 7 days earlier.
    startdates[1] = startdates[1] - 7
  }

  (beheaded_sheet
   %>% mutate_at(c("disease", "classification"), tolower)

   # adding period start and end dates
   %>% mutate(week_num = as.numeric(str_extract(week, "\\d+")))
   %>% mutate(period_start_date = startdates[week_num])
   %>% mutate(period_end_date = enddates[week_num])

   %>% rename(cases_this_period = numeric)
   %>% rename(diagnosis_certainty = classification)
   %>% rename(historical_disease = disease)
   %>% mutate(location = "ONT.", location_type = "province")
    
   %>% select(period_start_date, period_end_date, location, location_type, historical_disease, cases_this_period, diagnosis_certainty)

  )
}

combine_sheets=function(cleaned_sheets){
  # combining sheets
  combined= (bind_rows(cleaned_sheets, .id='sheet')
              %>% select(-sheet)
              %>% mutate(cases_this_period = as.numeric(cases_this_period))
           #   %>% mutate(period_start_date=as.Date(period_start_date), period_end_date=as.Date(period_end_date))
  )
  
 
  #  subtracting hepatitis b acute from hepatitis b chronic since these counts 
  #  are not mutually exclusive 
 
  hepatitis_b_exclusive = (combined
      %>% filter(historical_disease %in% c("hepatitis b (acute)", "hepatitis b, chronic"))
      %>% pivot_wider(names_from = historical_disease, values_from = cases_this_period)
  
      %>% rename('hep_b_acute' = "hepatitis b (acute)",
                 'hep_b_chronic' = "hepatitis b, chronic"
                   )
  
      %>%  mutate(cases_this_period =  ifelse(is.na(hep_b_chronic),
                                              hep_b_chronic,
                                              hep_b_chronic - hep_b_acute))
      %>% mutate(historical_disease = "hepatitis b, chronic")
      %>% select(-hep_b_acute, -hep_b_chronic)
  )
  
  (combined
      %>% filter(historical_disease != "hepatitis b, chronic")
      %>% rbind(hepatitis_b_exclusive)
  ) 
}

metadata = get_tracking_metadata(tidy_dataset, digitization, metadata_path, original_format = FALSE) # iidda

data = read_digitized_data(metadata) # iidda

sheets = get_sheet_names(data) # local

beheaded_sheets = sapply(sheets, behead_sheet, data = data, simplify = FALSE) # local

cleaned_sheets = mapply(clean_sheet, beheaded_sheets, sheets, SIMPLIFY=FALSE) # local

tidy_data = combine_sheets(cleaned_sheets) # local

data_with_scales = identify_scales(tidy_data) # iidda

data_with_scales = add_provenance(data_with_scales, tidy_dataset) # iidda

metadata = add_column_summaries(data_with_scales, tidy_dataset, metadata) # iidda

files = write_tidy_data(data_with_scales, metadata) # iidda
