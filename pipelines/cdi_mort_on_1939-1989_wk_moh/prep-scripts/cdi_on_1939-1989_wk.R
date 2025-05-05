

# ----------------------------------------
# Information for Locating Metadata
tidy_dataset = "cdi_on_1939-1989_wk"
digitization = "cdi_mort_on_1939-1989_wk"
metadata_path = "pipelines/cdi_mort_on_1939-1989_wk_moh/tracking"
# ----------------------------------------

library(iidda)
library(dplyr)
library(lubridate)
library(unpivotr)
library(zoo)

make_tidy_data = function(data){
  (data
   %>% filter(between(row, 2, max(row)),
              between(col, 3, max(col)))
   %>% select(row, col, data_type, numeric, character, date)
   %>% behead('N', historical_disease_family)
   %>% behead('N', historical_disease)
   %>% behead('N', stat_name)
   %>% behead('W', week_ending)

   # extract disease subclass info from stat_name, leaving stat_name only 'c' or 'd'
   %>% mutate(disease_subclass = ifelse(
         grepl("'|\"", stat_name)
       , gsub("^[CD]\\s+['\"]?(\\w+)['\"]?\\s*$", "\\1", stat_name)
       , ""
     )
  )
   %>% mutate(stat_name = gsub("['\"].*?['\"]", "", stat_name)
              %>% trimws())

   # FIXME: issues w/ this! xlsx_cells not reading in some empty cells so
   # na.locf is messed up
   %>% mutate(historical_disease = na.locf(historical_disease) %>% tolower())
   %>% unite(cases_this_period, c(numeric, character), sep='', na.rm = TRUE)

   # Creating period start and end dates
   %>% mutate(period_end_date = as.Date(week_ending, format = "%Y %B %d"))
   %>% mutate(period_start_date = period_end_date - days(6))

   %>% mutate(location = 'ONT.')

   %>% mutate(historical_disease =
                ifelse(is.na(historical_disease_family),
                       paste(historical_disease, disease_subclass, sep = ' '),
                       paste(historical_disease_family, historical_disease, disease_subclass, sep = ' '))
              %>% trimws())

   %>% select(location, period_start_date, period_end_date, historical_disease,
              cases_this_period, stat_name)

   %>% mutate(cases_this_period =
                ifelse(
                  cases_this_period == '',
                  'Not available',
                  cases_this_period
                ))

   # filtering out mortality data, keeping only cdi
   %>% filter(stat_name == 'C')
   %>% select(-stat_name)
   %>% filter(historical_disease != '1945:no name'
              & historical_disease != '1962:no name'
              & historical_disease != '1967:no name')
  )
}

# Processing Steps

metadata = get_tracking_metadata(tidy_dataset, digitization, metadata_path, original_format = FALSE) # iidda

data = read_digitized_data(metadata) # iidda

tidy_data = make_tidy_data(data) # local

data_with_scales = identify_scales(tidy_data) # iidda

data_with_scales = add_provenance(data_with_scales, tidy_dataset) # iidda

metadata = add_column_summaries(data_with_scales, tidy_dataset, metadata) # iidda

files = write_tidy_data(data_with_scales, metadata) # iidda
