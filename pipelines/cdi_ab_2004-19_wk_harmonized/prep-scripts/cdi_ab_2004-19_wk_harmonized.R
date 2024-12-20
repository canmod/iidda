
# ----------------------------------------
dataset_id = "cdi_ab_2004-19_wk_harmonized"
# ----------------------------------------

options(conflicts.policy = list(warn.conflicts = FALSE))
library(iidda.analysis)
library(iidda)
library(dplyr)
library(lubridate)

missing_handlers = iidda::MissingHandlers(
  unclear = , zeros = c("\u2014", "\u23BB", "\u002D", "\u203E", "\u005F", "\u2013")
  #, zeros = c("—"     , "⎻"     , "-"     , "‾"     , "_"     , "–"     )
)

get_hidden_numbers = missing_handlers$get_hidden_numbers
is_reported = missing_handlers$is_reported

harmonize_data = function(tidy_cdi) {
  if (nrow(tidy_cdi) == 0L) stop("no data to harmonize")
  location_lookup = read_lookup("canmod-location-lookup")
  disease_lookup = read_lookup("canmod-disease-lookup")
  aggregated_data =
    (tidy_cdi
     ## aggregate over age groups
     |> group_by(original_dataset_id, location, location_type, time_scale, period_start_date, period_end_date, historical_disease)
     |> summarise(cases_this_period = sum(readr::parse_number(cases_this_period)), digitization_id = unique(digitization_id))
     |> ungroup()
  )

  ## adding 0's:
  ## calculating all possible period end dates
  dates = c()
  for(yr in year(min(as.Date(tidy_cdi$period_end_date))):year(max(as.Date(tidy_cdi$period_end_date))))
    {
    dates = append(dates, as.Date(mapply(epiweek_end_date, yr, c(0:52))))
  }
  all_end_dates = unique(dates)

  harmonized_data =
    (## all possible combinations of historical_disease and all_end_dates
      expand.grid(historical_disease = unique(aggregated_data$historical_disease),
               period_end_date = all_end_dates)
    |> merge(aggregated_data, by = c("historical_disease", "period_end_date"), all.x = TRUE)

    |> mutate(cases_this_period = ifelse(is.na(cases_this_period),
                                               0,
                                               cases_this_period))
    |> mutate(original_dataset_id = 'cdi_ab_2004-19_wk_age'
              , location = 'ALTA.'
              , location_type = 'province'
              , time_scale = 'wk'
              , period_start_date = period_end_date - 6
              )

    |> lookup_join(location_lookup, names_to_join_by("location"))
    |> lookup_join(disease_lookup, names_to_join_by("disease"))
    |> mutate(cases_this_period = get_hidden_numbers(cases_this_period))
    |> filter(is_reported(cases_this_period))

    #|> mutate(case_rate = 1e5 * cases_this_period / days_this_period / population_reporting)
    |> mutate(across(everything(), as.character))

    |> add_basal_disease(disease_lookup) # iidda
    |> mutate(digitization_id = "cdi_ab_2004-19_wk_age") ## deciding to refer to this digitization id even for records that are a sum over age groups

    |> select(
      iso_3166
      ,iso_3166_2
      ,period_start_date
      ,period_end_date
      ,disease
      ,nesting_disease
      ,basal_disease
      ,cases_this_period
      ,location
      ,location_type
      ,time_scale
      ,historical_disease
      ,historical_disease_family
      ,historical_disease_subclass
      ,original_dataset_id
      ,digitization_id
    )
    )

  harmonized_data

}

# Processing Steps

metadata = get_dataset_metadata(dataset_id) # iidda

tidy_cdi = read_prerequisite_data(dataset_id) # iidda

harmonized_data = harmonize_data(tidy_cdi) # local

metadata = add_column_summaries(harmonized_data, dataset_id, metadata) # iidda

files = write_tidy_data(harmonized_data, metadata) # iidda
