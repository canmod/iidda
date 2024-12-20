library(iidda)
library(iidda.analysis)
library(readr)
library(dplyr)

dataset_id = "phac-cdi-portal"

phac_to_canmod_lookup = read_csv("lookup-tables/phac-to-canmod-disease-lookup.csv")
canmod_lookup = read_csv("lookup-tables/canmod-disease-lookup.csv")

metadata = get_dataset_metadata("phac-cdi-portal")

phac_data = (read_csv('pipelines/phac-cdi-portal/digitizations/phac_portal_data.csv')
   %>% rename(historical_disease = Disease,
             year = Year,
             cases_this_period = 'Number of reported cases')

   %>% filter(!is.na(cases_this_period))
   %>% mutate(period_start_date = as.Date(paste(year, '-01-01', sep = '')))
   %>% mutate(period_end_date = as.Date(paste(year, '-12-31', sep = '')))
   %>% mutate(days_this_period = iidda.analysis::num_days(period_start_date, period_end_date))

   # joining with phac reporting population
   #%>% left_join(phac_population, by = c('web_portal_disease', 'year'))

   %>% left_join(phac_to_canmod_lookup, by = 'historical_disease')
   %>% filter(!is.na(disease))

   # joining with our normalized disease name look-up table
   %>% lookup_join(canmod_lookup, names_to_join_by("disease"))
   %>% mutate(cases_this_period = as.numeric(cases_this_period),
             days_this_period = as.numeric(days_this_period))
             #reporting_population_phac = as.numeric(reporting_population_phac))
   %>% mutate(iso_3166_2 = '')

   # don't want to join population since not all provinces are reporting all years
   # info about what provinces are reporting when is found in reporting_schedule
   # need to do this in another pipeline and then join to this one
   # %>% join_population()

   %>% mutate(year = as.double(year))
   |> mutate(time_scale = "yr")
   %>% select(
      period_start_date, period_end_date, days_this_period, year, time_scale
    , disease, historical_disease, cases_this_period
   )
)

metadata = add_column_summaries(phac_data, dataset_id, metadata)

files = write_tidy_data(phac_data, metadata)
