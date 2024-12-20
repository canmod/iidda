# Data quality cross checks
# Cross check 2) sub-annual data compared to annual data
# (or any comparison over timescales)

options(conflicts.policy = list(warn.conflicts = FALSE))
library(iidda.analysis)
library(dplyr)
library(lubridate)
library(purrr)

disease_lookup = read_data_frame("lookup-tables/canmod-disease-lookup.csv")
location_lookup = read_data_frame("lookup-tables/canmod-location-lookup.csv")

full_harm = (read_data_frame("derived-data/canmod-cdi-harmonized/canmod-cdi-harmonized.csv")
  |> mutate(year = ifelse(iidda::is_empty(collection_year), lubridate::year(period_end_date), substr(collection_year, 1L, 4L)))
#  |> mutate(iidda_source_id = iidda::source_from_digitization_id(digitization_id))
)

## these are counts that for some reason the original
## source apparently did not include in yearly sums
excluded_periods = (full_harm
  |> filter(
    (
      ((period_end_date == "1954-01-02") & (collection_year == "1954") & (digitization_id == "cdi_wc_ca_1924-55_wk_prov"))
    )
  )
  |> mutate(cases_excluded_periods = as.numeric(cases_this_period), year = collection_year)
  |> select(original_dataset_id, year, cases_excluded_periods, iso_3166_2)
)

week_not_stated_files = Sys.glob("supporting-output/*/week-not-stated.csv")
week_not_stated_ids = week_not_stated_files |> dirname() |> basename() |> tools::file_path_sans_ext()
week_not_stated_frames = lapply(week_not_stated_files, read_data_frame) |> setNames(week_not_stated_ids)
week_not_stated = (week_not_stated_frames
  |> bind_rows(.id = "original_dataset_id")
  |> mutate(cases_this_period = as.numeric(cases_this_period))
  |> filter(!is.na(cases_this_period))
  |> filter(time_scale == "wk")
  |> rename(cases_this_period_wk_not_stated = cases_this_period)
  |> left_join(location_lookup)
  |> rename(year = collection_year)
  |> select(-iso_3166, -location_type, -location, -time_scale)
)

blank_week_files = Sys.glob("supporting-output/*/week-blank.csv")
blank_week_ids = blank_week_files |> dirname() |> basename() |> tools::file_path_sans_ext()
blank_week_frames = lapply(blank_week_files, read_data_frame) |> setNames(blank_week_ids)
blank_week = (blank_week_frames
  |> bind_rows(.id = "original_dataset_id")
  |> mutate(cases_this_period = as.numeric(cases_this_period))
  |> filter(!is.na(cases_this_period))
  |> filter(time_scale == "wk")
  |> rename(cases_this_period_blank_wk = cases_this_period)
  |> left_join(location_lookup)
  |> rename(year = collection_year)
  |> select(-iso_3166, -location_type, -location, -time_scale)
)


sum_of_timescales = sum_timescales(mutate(full_harm, year = collection_year))

initial_time_scale_cross_check = do_time_scale_cross_check(sum_of_timescales)

time_scale_cross_check = (initial_time_scale_cross_check
  |> left_join(
      y = week_not_stated
    , by = c("original_dataset_id", "iso_3166_2", "year")
  )
  |> left_join(
      y = blank_week
    , by = c("original_dataset_id", "iso_3166_2", "year")
  )
  |> left_join(
      y = excluded_periods
    , by = c("original_dataset_id", "iso_3166_2", "year")
  )
  |> mutate(cases_this_period_yr_corrected = ifelse(is.na(cases_this_period_wk_not_stated)
    , cases_this_period_yr
    , cases_this_period_yr - cases_this_period_wk_not_stated
  ))
  |> mutate(cases_this_period_wk = ifelse(is.na(cases_excluded_periods)
    , cases_this_period_wk
    , cases_this_period_wk + cases_excluded_periods
  ))
  |> relocate(cases_this_period_yr_corrected, .after = cases_this_period_yr)
  |> filter(cases_this_period_yr_corrected != cases_this_period_wk)
  |> select(-cases_this_period_yr_corrected, -cases_this_period_wk_not_stated, -cases_excluded_periods)
  |> lookup_join(disease_lookup, names_to_join_by("disease"))
  |> add_basal_disease(disease_lookup)
  |> select(
      year, iso_3166_2, basal_disease
    , historical_disease, historical_disease_subclass, historical_disease_family
    , cases_this_period_wk, cases_this_period_mo, cases_this_period_yr
    , percent_error, discrepancy, distinct_values
    , original_dataset_id, scan_id, digitization_id
  )

  ## these are not data entry errors but instead are wayward weeks.
  ## still haven't figured out how to correct for this issue in
  ## these cross-checks but for now we will just declare explicitly
  ## that they are good.
  |> filter(!((year == "1954") & (iso_3166_2 == "CA-ON") & (scan_id == "cdi_wc_ca_1924-55_wk_prov")))
  |> filter(!((year == "1937") & (iso_3166_2 == "CA-MB") & (scan_id == "cdi_wc_ca_1924-55_wk_prov")))
  |> mutate(iidda_source_id = source_from_digitization_id(digitization_id))
)



metadata = get_dataset_metadata("canmod-time-scale-cross-check")
files = write_tidy_data(time_scale_cross_check, metadata)
