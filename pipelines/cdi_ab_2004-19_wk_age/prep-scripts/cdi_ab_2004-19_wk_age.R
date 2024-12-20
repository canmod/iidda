# ----------------------------------------
# Information for Locating Metadata
tidy_dataset = "cdi_ab_2004-19_wk_age"
digitization = "cdi_ab_2004-19_wk_age"
metadata_path = "pipelines/cdi_ab_2004-19_wk_age/tracking"
# ----------------------------------------

options(conflicts.policy = list(warn.conflicts = FALSE))
# remotes::install_github('canmod-eidm/iidda-tools', subdir = 'R/iidda')
library(plyr)
library(dplyr)
library(stringr)
library(iidda)

make_tidy_data = function(data){
  (data

   # Creating period start and end dates
   %>% mutate(period_end_date = epiweek_end_date(year, week))
   %>% mutate(period_start_date = period_end_date - 6)

   %>% rename(cases_this_period = count, historical_disease = disease_name)

   # Creating upper_age and lower_age
   %>% mutate(lower_age = ifelse(grepl('<', age_group), 0, ''))
   %>% mutate(lower_age = ifelse(grepl('-[0-9]+', age_group) , str_extract(age_group, '^[0-9]{1,2}'), lower_age))
   %>% mutate(lower_age = ifelse(grepl('\\+', age_group), str_extract(age_group, '\\d+'), lower_age))
   %>% mutate(lower_age = ifelse(grepl('unknown', age_group, ignore.case = TRUE), 'all unspecified ages', lower_age))

   %>% mutate(upper_age = ifelse(grepl('<', age_group, ignore.case = TRUE), str_extract(age_group, '[0-9]+'), ''))
   %>% mutate(upper_age = ifelse(grepl('-[0-9]+', age_group) , str_extract(age_group, '(?<=-)[0-9]+'), upper_age))
   %>% mutate(upper_age = ifelse(grepl('\\+', age_group), '', upper_age))
   %>% mutate(upper_age = ifelse(grepl('unknown', age_group, ignore.case = TRUE), 'all unspecified ages', upper_age))

   %>% mutate(location = 'ALTA.')
   %>% select(location, period_start_date, period_end_date, historical_disease, cases_this_period, lower_age, upper_age)
  )
}

metadata = get_tracking_metadata(tidy_dataset, digitization, metadata_path, original_format = FALSE) # iidda

data = read_digitized_data(metadata) # iidda

tidy_data = make_tidy_data(data) # local

data_with_scales = identify_scales(tidy_data) # iidda

data_with_scales = add_provenance(data_with_scales, tidy_dataset) # iidda

metadata = add_column_summaries(data_with_scales, tidy_dataset, metadata) # iidda

files = write_tidy_data(data_with_scales, metadata) # iidda
