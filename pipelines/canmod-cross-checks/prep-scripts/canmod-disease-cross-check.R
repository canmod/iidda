# Data quality cross checks
# Cross check 3) sub-disease data compared to nesting disease data

options(conflicts.policy = list(warn.conflicts = FALSE))
library(iidda.analysis)
library(dplyr)
library(lubridate)
library(purrr)

disease_lookup = read_data_frame("lookup-tables/canmod-disease-lookup.csv")
location_lookup = read_data_frame("lookup-tables/canmod-location-lookup.csv")
harm = ("derived-data/canmod-cdi-unharmonized/canmod-cdi-unharmonized.csv"
  |> read_data_frame()
  |> iidda.analysis::lookup_join(disease_lookup,
                                 c("historical_disease_family",
                                   "historical_disease", "historical_disease_subclass",
                                   "icd_7", "icd_7_subclass", "icd_9", "icd_9_subclass"))
  |> iidda.analysis::lookup_join(location_lookup,
                                 c("location", "location_type"))
  |> add_provenance("canmod-cdi-unharmonized")

  ## filter out data that we did not enter
  ## (might be interesting to leave this in to detect issues in disease name
  ## harmonization, but that is for another day)
  |> filter(!digitization_id %in% c("cdi_on_1990-2021_wk"))
)
digis = harm$digitization_id |> unique()

sources = source_from_digitization_id(digis)

tidy_cdi = mutate(harm, iidda_source_id = sources[digitization_id])

clean_cdi = (
  tidy_cdi

  # when cases_this_period is 'one number (unclear)', keep the one number,
  # when it is 2 numbers then (unclear), keep the first number
  |> mutate(cases_this_period = ifelse(grepl("[0-9]", cases_this_period),
                                        gsub("[^0-9].*$", "", cases_this_period),
                                        cases_this_period)
  )


  |> mutate(cases_this_period = ifelse(cases_this_period == '(unclear)',
                                        'unclear',
                                        cases_this_period))


  # FIXME: need to fix mort_on_1903-1939_mn prep script.
  |> filter(historical_disease != 'Rate per 1,000 per annum')

  # these occur either because of issues, or because of cases in
  # other case statistic columns (prev period, cumulative, etc.)
  |> filter(cases_this_period != '')
)


# -------------------------------------------------------------------------------

clean_cdi_with_disease = (
  clean_cdi
  |> filter(original_dataset_id != 'mort_on_1903-1939_mn')

  # remove AIDS from ontario 1990-2021 source as it is not mutually exclusive from HIV
  |> filter(!(disease == 'AIDS' & original_dataset_id == "cdi_on_1990-2021_wk"))

  |> filter(!diagnosis_certainty %in% c("probable")) ## also exclude "suspect c"?

  |> add_basal_disease(disease_lookup)

  |> mutate(nesting_disease = ifelse(
        disease == 'congenital-rubella'
      , ''
      , nesting_disease
  ))

  |> mutate(basal_disease = ifelse(
        disease == 'congenital-rubella'
      , 'congenital-rubella'
      , basal_disease
  ))
  |> distinct()
)

sum_of_leaf = (
  clean_cdi_with_disease
  |> filter(disease != basal_disease)

  |> group_by(iso_3166_2, period_start_date, period_end_date,
               basal_disease, iidda_source_id)

  |> filter(!disease %in% unique(nesting_disease))

  # Exclude groups where any cases_this_period is 'unclear' or another type of missing value
  |> filter(!any(cases_this_period %in% c('unclear', 'Not available', 'Not reportable',
                                           'missing', 'not received')))

  |> mutate(cases_this_period = as.numeric(cases_this_period))

  |> summarise(cases_this_period = sum(as.numeric(cases_this_period)))

  |> ungroup()
)

reported_totals = (
  clean_cdi_with_disease
  |> filter(nesting_disease == '')
  |> filter(disease %in% sum_of_leaf$basal_disease)
  |> select(-basal_disease)
  |> rename(basal_disease = disease)
)

disease_cross_check = (sum_of_leaf
  |> inner_join(
      reported_totals, by = c(
          'iso_3166_2', 'period_start_date', 'period_end_date'
        , 'basal_disease', 'iidda_source_id'
      )
    , suffix = c('_sum', '_reported')
  )

 |> mutate(cases_this_period = as.numeric(cases_this_period_reported),
            cases_this_period_sum = as.numeric(cases_this_period_sum))

 |> mutate(percent_error = ifelse(cases_this_period == 0, NA,
                                   abs((cases_this_period - cases_this_period_sum) / cases_this_period * 100)),
            discrepancy = cases_this_period - cases_this_period_sum)

 |> filter(discrepancy < 0) ## positive discrepancies will just become *_unaccounted sub-diseases anyways
 |> select(-cases_this_period)
 |> dplyr::rename(cases_this_period = cases_this_period_reported)

 |> select(iso_3166_2, basal_disease, period_start_date, period_end_date,
           iidda_source_id, historical_disease, historical_disease_subclass,
           historical_disease_family, cases_this_period_sum, cases_this_period,
           percent_error, discrepancy, digitization_id, scan_id)
 |> arrange(desc(percent_error))

)

disease_cross_check = (disease_cross_check
  ## priority is for sub-national data
  |> filter(!iidda::is_empty(iso_3166_2))

  ## TODO: filter out checks on annual data too (why is time_scale not here?)
)

metadata = get_dataset_metadata("canmod-disease-cross-check")
files = write_tidy_data(disease_cross_check, metadata)

if (interactive()) {
  over = (disease_cross_check
     |> filter(cases_this_period_sum > cases_this_period)
  )
  under = (disease_cross_check
     |> filter(cases_this_period_sum < cases_this_period)
  )
}
