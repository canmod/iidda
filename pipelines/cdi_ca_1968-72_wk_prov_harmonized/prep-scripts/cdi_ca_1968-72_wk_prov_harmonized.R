
# ----------------------------------------
dataset_id = "cdi_ca_1968-72_wk_prov_harmonized"
# ----------------------------------------

options(conflicts.policy = list(warn.conflicts = FALSE))
library(iidda.analysis)
library(iidda)
library(dplyr)

missing_handlers = iidda::MissingHandlers(
  unclear = c("Unclear", "unclear", "uncleaar", "uncelar")
  , not_reported = c("", "Not available", "*", "Not reportable")
  , zeros = c("\u2014", "\u23BB", "\u002D", "\u203E", "\u005F", "\u2013")
  #, zeros = c("—"     , "⎻"     , "-"     , "‾"     , "_"     , "–"     )
)
get_hidden_numbers = missing_handlers$get_hidden_numbers
is_reported = missing_handlers$is_reported

harmonize_data = function(tidy_cdi, disease_lookup) {
  if (nrow(tidy_cdi) == 0L) stop("no data to harmonize")
  
  location_lookup = read_lookup("canmod-location-lookup")
  disease_lookup = read_lookup("canmod-disease-lookup")
  (tidy_cdi
   |> lookup_join(location_lookup, names_to_join_by("location"))
   |> lookup_join(disease_lookup, names_to_join_by("disease"))
   |> mutate(cases_this_period = get_hidden_numbers(cases_this_period))
   |> filter(is_reported(cases_this_period))

   |> mutate(across(starts_with("cases_"), readr::parse_number))
   
   |> mutate(across(everything(), as.character))
    
   |> add_basal_disease(disease_lookup) # iidda
    
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
      ,scan_id
      ,digitization_id
    )
  )
}


# Processing Steps

metadata = get_dataset_metadata(dataset_id) # iidda

tidy_cdi = read_prerequisite_data(dataset_id) # iidda

harmonized_data = harmonize_data(tidy_cdi) # local

metadata = add_column_summaries(harmonized_data, dataset_id, metadata) # iidda

files = write_tidy_data(harmonized_data, metadata) # iidda
