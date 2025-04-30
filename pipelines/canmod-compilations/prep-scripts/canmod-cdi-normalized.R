# ----------------------------------------
input_dataset = "canmod-cdi-harmonized"
output_dataset = "canmod-cdi-normalized"
pop_dataset = "canmod-pop-normalized"
basal_diseases_to_prune = "venereal-diseases"
# ----------------------------------------


library(iidda)
library(iidda.analysis)
library(dplyr)
year = lubridate::year
month = lubridate::month
filter = dplyr::filter

hook = mock_api_hook(".")

read_cdi = function(input_dataset) {
  (input_dataset
    |> hook$raw_csv()
    |> mutate(dataset_id = input_dataset)
    |> mutate(record_origin = "historical")
    |> mutate(source_id = source_from_digitization_id(digitization_id))
  )
}

read_pop = function(pop_dataset) hook$raw_csv(pop_dataset)

is_overlap = function(start, end) {
  x = dplyr::lead(start) < end
  x[is.na(x)] = FALSE
  x
}
overlap_group_by = function(data) {
  (data
    |> group_by(disease, iso_3166_2)
    |> arrange(period_end_date)
  )
}
rm_overlap = function(data) {
  # note that the temporally first overlapping record is removed
  # and the subsequent record is retained. this could cause overlap
  # chains to be completely removed even in cases where outer
  # records do not overlap and could/should therefore be retained
  # after inner overlapping records are removed. this is why
  # overlap should be resolved using get_overlap, investigation,
  # and fixing of pipeline resources.
  (data
    |> overlap_group_by()
    |> filter(!is_overlap(period_start_date, period_end_date))
    |> ungroup()
  )
}
get_overlap = function(data) {
  o = (data
    |> overlap_group_by()
    |> filter(is_overlap(period_start_date, period_end_date))
    |> ungroup()
  )
  arrange(o, disease, iso_3166_2, period_start_date, period_end_date)
}
n_overlap = function(data) data |> get_overlap() |> nrow()
get_complement = function(new, existing) {
  anti_join(
      new
    , existing
    , join_by(
          x$basal_disease == y$basal_disease
        , x$iso_3166_2 == y$iso_3166_2
        , overlaps(
              x$period_start_date
            , x$period_end_date
            , y$period_start_date
            , y$period_end_date
          )
      )
  )
}
bind_complement = function(existing, new) {
  new = get_complement(new, existing)
  bind_rows(existing, new) |> arrange(period_start_date)
}

remove_national_data = function(data) {
  (data
    |> mutate(source_location_scale = ifelse(
        grepl("^cdi[_a-zA-Z]*_ca", digitization_id)
      , "national"
      , "sub-national"
    ))
    |> filter(!iidda::is_empty(iso_3166_2))
    |> mutate(cases_this_period = as.numeric(cases_this_period))
  )
}

rm_basal_disease_lookup = function(lookup, basal_diseases_to_prune) {
  (lookup
    |> filter(!nesting_disease %in% basal_diseases_to_prune)
    |> filter(!disease %in% basal_diseases_to_prune)
    |> mutate(nesting_disease = ifelse(
          nesting_disease %in% basal_diseases_to_prune
        , ""
        , nesting_disease
    ))
  )
}

rm_basal_disease_data = function(data, basal_diseases_to_prune) {
  (data
    |> filter(!disease %in% basal_diseases_to_prune)
    |> mutate(nesting_disease = ifelse(
          nesting_disease %in% basal_diseases_to_prune
        , ""
        , nesting_disease
    ))
    |> select(-basal_disease)
  )
}

separate_by_scale = function(data) {
  source_location_scales = c("national", "sub-national")
  time_scales = c("wk", "2wk", "mo", "qr", "3qr")
  data_list = list()
  for (loc in source_location_scales) {
    for (tim in time_scales) {
      nm = gsub("-", "_", sprintf("%s_%s", loc, tim))
      data_list[[nm]] = (data
        |> filter(time_scale == tim)
        |> filter(source_location_scale == loc)
      )
    }
  }

  data_list$national_mo = rm_overlap(data_list$national_mo)
  data_list
}

normalize_cdi = function(data_list, disease_lookup, harmonized_pop, output_dataset) {
  ## implied zeros ------------------
  mo_zeros = (data_list$national_mo
    |> filter(cases_this_period == "0")
  )
  wk_dates = (data_list$national_wk
    |> select(period_start_date, period_end_date)
    |> distinct()
    |> arrange(period_end_date)
  )
  national_wk_implied_zeros = (inner_join(
        mo_zeros
      , wk_dates
      , join_by(within(
            y$period_start_date
          , y$period_end_date
          , x$period_start_date
          , x$period_end_date
      ))
      , multiple = "all"
      , suffix = c("_mo", "")
    )
    |> mutate(record_origin = "derived-implied-zeros")
    |> mutate(time_scale = "wk")
    |> mutate(days_this_period = 7)
  )

  ## put things together and flatten the disease hierarchy ----------
  normalized_cdi = (data_list$national_wk
    |> bind_complement(data_list$sub_national_wk)
    |> bind_complement(data_list$national_2wk)
    |> bind_complement(data_list$sub_national_2wk)
    |> bind_complement(national_wk_implied_zeros)
    |> bind_complement(data_list$national_mo)
    |> bind_complement(data_list$sub_national_mo)
    |> bind_complement(data_list$national_qr)
    |> bind_complement(data_list$national_3qr)

    # remove AIDS from ontario 1990-2021 source as it is not mutually exclusive from HIV
    |> filter(!(disease == 'AIDS' & original_dataset_id == "cdi_on_1990-2021_wk"))

    |> normalize_disease_hierarchy(disease_lookup
       #, basal_diseases_to_prune = c("hepatitis", "venereal-diseases")
       , find_unaccounted_cases = FALSE
       , grouping_columns = c("period_start_date", "period_end_date", "iso_3166_2")
      )
    |> select(-any_of(c(
        "dataset_id"
      , "source_location_scale"
      , "period_start_date_mo"
      , "period_end_date_mo"
      , "collection_year"
      , "source_id"
    )))
  )
  # TODO: sanity checks that should be printed out somewhere
  normalized_cdi$record_origin |> table()
  normalized_cdi$period_end_date |> is.na() |> mean()

  report = iidda::empty_column_report(normalized_cdi, c(
      "cases_this_period"
    , "period_start_date"
    , "period_end_date"
    , "iso_3166_2"
    , "disease"
  ), output_dataset)

  normalized_cdi
}

## experimental optional function that will aggregate 'isolated' weekly data
## to 4-weekly. if some locations have weekly data when others
## have 4-weekly, this function will do its best to aggregate
## the weekly data to be more comparable across locations.
aggregate_isolated_weekly = function(normalized_cdi) {
  typed = mutate(normalized_cdi, cases_this_period = as.numeric(cases_this_period))
  four_weekly_avail = (typed
    |> filter(days_this_period == 28L)
    |> select(basal_disease, period_start_date, period_end_date)
    |> distinct()
  )
  monthly = filter(typed, time_scale == "mo")
  weekly = filter(typed, time_scale == "wk")
  four_weekly_agg = (inner_join(
        four_weekly_avail
      , weekly
      , join_by(
            basal_disease
          , within(
              y$period_start_date, y$period_end_date
            , x$period_start_date, x$period_end_date
          )
      )
      , suffix = c("", "_wk")
    )
    |> mutate(cases_this_period = as.numeric(cases_this_period))
    |> mutate(days_this_period = as.numeric(days_this_period))
    |> mutate(population = as.numeric(population))
    |> group_by(
          basal_disease, nesting_disease, disease
        , historical_disease, historical_disease_subclass, historical_disease_family
        , location, location_type, iso_3166_2, iso_3166
        , period_start_date, period_end_date
        , scan_id, digitization_id, original_dataset_id
      )
    |> summarise(
        cases_this_period = sum(cases_this_period)
      , days_this_period = sum(days_this_period)
      , population = round(mean(population))
    )
    |> ungroup()
    |> filter(days_this_period == 28L)
    |> mutate(
        time_scale = "mo"
      , record_origin = "derived-agg-weeks"
      , period_mid_date = mid_times(period_start_date, period_end_date, days_this_period)
    )
  )
  (typed
    |> filter(time_scale != "wk")
    |> bind_complement(four_weekly_agg)
    |> bind_complement(weekly)
  )
}

get_nesting_disease_totals = function(harmonized_cdi) {
  (harmonized_cdi
    |> mutate(cases_this_period = as.numeric(cases_this_period))
    |> mutate(source_id = source_from_digitization_id(digitization_id))
    |> filter(nesting_disease != "")
    |> group_by(period_start_date, period_end_date, iso_3166, iso_3166_2, source_id, nesting_disease)
    |> summarise(cases_this_period = sum(cases_this_period, na.rm = TRUE))
    |> ungroup()
    |> rename(disease = nesting_disease)
  )
}

add_unaccounted = function(harmonized_cdi, nesting_disease_totals) {
  (harmonized_cdi

    ## join the totals of the children of each disease. asserting one-to-one is
    ## important because each disease should only have at most one sum of
    ## children diseases and at most one reported total.
    |> inner_join(nesting_disease_totals
      , by = c(
            "period_start_date", "period_end_date"
          , "iso_3166", "iso_3166_2"
          , "source_id", "disease"
        )
      , suffix = c("_reports", "_totals")
      , relationship = "one-to-one"
    )

    ## get rid of all instances where the total doesn't make it to the reports.
    ## these records are those that contain unaccounted cases.
    |> filter(cases_this_period_reports > cases_this_period_totals)

    ## the number of these unaccounted cases is the difference between the
    ## report and the total of the children.
    |> mutate(
        cases_this_period = cases_this_period_reports - cases_this_period_totals
      , nesting_disease = disease
      , disease = sprintf("%s_unaccounted", disease)
    )

    ## get rid of intermediate numbers
    |> select(-cases_this_period_totals, -cases_this_period_reports, -source_id)

    ## clarify that these records do not originate directly from a
    ## historical source, but rather are derived (potentially from several
    ## documents/datasets.
    |> mutate(
        original_dataset_id = ""
      , historical_disease = ""
      , original_dataset_id = ""
    )
    |> mutate(record_origin = 'derived-unaccounted-cases')

    ## join back the historical data
    |> bind_rows(harmonized_cdi)
  )
}



# Processing Steps

metadata = get_dataset_metadata(output_dataset) # iidda

harmonized_cdi = read_cdi(input_dataset) # local

nesting_disease_totals = get_nesting_disease_totals(harmonized_cdi) # local

# inner_join(harmonized_cdi, nesting_disease_totals
#   , by = c(
#         "period_start_date", "period_end_date"
#       , "iso_3166", "iso_3166_2"
#       , "source_id", "disease"
#     )
#   , suffix = c("_reports", "_totals")
#   , relationship = "one-to-one"
# )
# i = 123158
# semi_join(harmonized_cdi, nesting_disease_totals[i,], by = c(
#       "period_start_date", "period_end_date"
#     , "iso_3166", "iso_3166_2"
#     , "source_id", "disease"
#   )
# ) |>View()
#
# x = select(harmonized_cdi, -collection_year)
# i = duplicated(x)
# x[i, ] |> View()
#
# filter(harmonized_cdi, period_end_date == "1955-01-01") |> View()

harmonized_cdi_unaccounted = add_unaccounted(harmonized_cdi, nesting_disease_totals) # local

harmonized_pop = read_pop(pop_dataset) # local

joined_cdi = normalize_population(harmonized_cdi_unaccounted, harmonized_pop)

no_canada = remove_national_data(joined_cdi) # local

disease_lookup = read_lookup("canmod-disease-lookup") |> rm_basal_disease_lookup(basal_diseases_to_prune)

no_canada_pruned = rm_basal_disease_data(no_canada, basal_diseases_to_prune) |> add_basal_disease(disease_lookup)

no_canada_separated = separate_by_scale(no_canada_pruned) # local

normalized_cdi = normalize_cdi(no_canada_separated, disease_lookup, harmonized_pop, output_dataset) # local

metadata = add_column_summaries(normalized_cdi, output_dataset, metadata) # iidda

files = write_tidy_data(normalized_cdi, metadata) # iidda
