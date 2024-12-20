library(iidda)
library(readr)
library(dplyr)
lookup_dataset = "canmod-location-lookup"
derived_path = "derived-data/canmod-location-lookup/canmod-location-lookup.csv" ## depends only on automation
lookup_path = "lookup-tables/canmod-location-lookup.csv" ## depends on automation and manual edits
join_cols = c("location", "location_type")
id_cols = c("original_dataset_id", "scan_id", "digitization_id")


all_join_cols = c(join_cols, id_cols)
datasets_to_harmonize = read_prerequisite_data(lookup_dataset)[, all_join_cols, drop = FALSE]
location_summary = (datasets_to_harmonize
  %>% distinct()
  %>% filter(!if_all(.cols = everything(), .fns = function(x) x == "")) ## remove blank rows
  %>% replace(is.na(.), "")
  %>% filter(!is_empty(location))
  %>% filter(location_type != "municipality")
)
trash = iidda::fix_csv(lookup_path)
location_lookup = (lookup_path
  |> read_data_frame()
  |> filter(!is_empty(location))
  |> mutate(original_dataset_id = "", scan_id = "", digitization_id = "")
  #filter(!is_empty(location_type)) ## sometimes it is interesting to turn this filter on
)

lookup_with_ids = left_join(
    select(location_lookup, !any_of(id_cols)) |> distinct()
  , location_summary
  , by = join_cols
)
# sanity_check = identical(
#     select(lookup_with_ids, !any_of(id_cols)) |> distinct()
#   , select(location_lookup, !any_of(id_cols))
# )
# if (!sanity_check) {
#   setdiff(names(location_summary), names(location_lookup))
#   stop("adding id columns to existing lookup tables is not working as expected")
# }

new = anti_join(location_summary, location_lookup, by = join_cols)

new_location_lookup = (location_lookup
  |> bind_rows(new)
  %>% replace(is.na(.), "")
  |> arrange(iso_3166, iso_3166_2)
)
if (nrow(new) > 0L) {
  trash = write_data_frame(distinct(new_location_lookup), lookup_path)
  stop(
      "\n----------------------------------------------------"
    , "\nError -- But you can and should do something about it."
    , "\nNew historical location names have been added to "
    , lookup_path
    , "\nPlease go there and add iso-3166  codes"
    , "\nfor locations at the top of the list."
    , "\n----------------------------------------------------\n"
  )
}
distinct_location_lookup = distinct(new_location_lookup)
if (!identical(distinct_location_lookup, new_location_lookup)) {
  trash = write_data_frame(select(distinct_location_lookup, !any_of(id_cols)), lookup_path)
}

new_location_lookup_with_ids = bind_rows(lookup_with_ids, new) %>% replace(is.na(.), "") |> arrange(iso_3166, iso_3166_2)
#old_location_lookup_with_ids = read_data_frame(derived_path)
trash = write_data_frame(new_location_lookup_with_ids, derived_path)
# if (!identical(old_location_lookup_with_ids, new_location_lookup_with_ids)) {
# }
