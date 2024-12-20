library(iidda)
library(readr)
library(dplyr)
lookup_dataset = "canmod-disease-lookup"
derived_path = "derived-data/canmod-disease-lookup/canmod-disease-lookup.csv" ## depends only on automation
lookup_path = "lookup-tables/canmod-disease-lookup.csv" ## depends on automation and manual edits
join_cols = c(
    "historical_disease_family", "historical_disease"
  , "historical_disease_subclass", "icd_7", "icd_9"
  , "icd_7_subclass", "icd_9_subclass"
)
id_cols = c("original_dataset_id", "scan_id", "digitization_id")


all_join_cols = c(join_cols, id_cols)
datasets_to_harmonize = read_prerequisite_data(lookup_dataset)[, all_join_cols, drop = FALSE]
disease_summary = (datasets_to_harmonize
  %>% distinct()
  %>% filter(!if_all(.cols = everything(), .fns = function(x) x == "")) ## remove blank rows
  %>% replace(is.na(.), "")
)
trash = iidda::fix_csv(lookup_path)
disease_lookup = (lookup_path
  |> read_data_frame()
  |> filter(!is_empty(disease))
  |> mutate(original_dataset_id = "", scan_id = "", digitization_id = "")
  #distinct()
)
# add_basal_disease(disease_lookup, disease_lookup)
# existing_and_not_obsolete = semi_join(disease_lookup, disease_summary, by = join_cols)
# existing_and_obsolete = anti_join(disease_lookup, disease_summary, by = join_cols)
lookup_with_ids = left_join(
    select(disease_lookup, !any_of(id_cols)) |> distinct()
  , disease_summary
  , by = join_cols
)
# sanity_check = identical(
#     select(lookup_with_ids, !any_of(id_cols)) |> distinct()
#   , select(disease_lookup, !any_of(id_cols))
# )
# if (!sanity_check) {
#   setdiff(names(disease_summary), names(disease_lookup))
#   stop("adding id columns to existing lookup tables is not working as expected")
# }

new = (disease_summary
  |> anti_join(disease_lookup, by = join_cols)

  ## comment out these next two lines if you do not want identifiers
  ## to produce multiple records per disease during manual lookup.
  |> mutate(original_dataset_id = "", scan_id = "", digitization_id = "")
  |> distinct()
)

new_disease_lookup = (disease_lookup
  |> bind_rows(new)
  %>% replace(is.na(.), "")
  |> arrange(disease, nesting_disease)
)
if (nrow(new) > 0L) {
  write_data_frame(distinct(new_disease_lookup), lookup_path)
  stop(
      "\n----------------------------------------------------"
    , "\nError -- But you can and should do something about it."
    , "\nNew historical disease names have been added to "
    , lookup_path
    , "\nPlease go there and add disease (and if appropriate nesting_disease)"
    , "\nnames for diseases at the top of the list. These disease and"
    , "\nnesting_disease columns contain names that harmonize the historical"
    , "\nnames so that multiple sources of data can be combined."
    , "\n----------------------------------------------------\n"
  )
}

distinct_disease_lookup = distinct(new_disease_lookup)
if (!identical(distinct_disease_lookup, new_disease_lookup)) {
  trash = write_data_frame(select(distinct_disease_lookup, !any_of(id_cols)), lookup_path)
}

new_disease_lookup_with_ids = bind_rows(lookup_with_ids, new) %>% replace(is.na(.), "") |> arrange(disease, nesting_disease)
#old_disease_lookup_with_ids = read_data_frame(derived_path)
trash = write_data_frame(new_disease_lookup_with_ids, derived_path)
# if (!identical(old_disease_lookup_with_ids, new_disease_lookup_with_ids)) {
# }
