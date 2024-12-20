# Data quality cross checks
# Cross check 1) sub-national sum compared to national total

options(conflicts.policy = list(warn.conflicts = FALSE))
library(iidda.analysis)
library(dplyr)
library(lubridate)
library(purrr)

disease_lookup = read_data_frame("lookup-tables/canmod-disease-lookup.csv")
location_lookup = read_data_frame("lookup-tables/canmod-location-lookup.csv")

full_harm = ("derived-data/canmod-cdi-harmonized/canmod-cdi-harmonized.csv"
  |> read_data_frame()
  |> mutate(iidda_source_id = source_from_digitization_id(digitization_id))
)
tidy_cdi = ("derived-data/canmod-cdi-unharmonized/canmod-cdi-unharmonized.csv"
  |> read_data_frame()
  |> iidda.analysis::lookup_join(disease_lookup,
                                 c("historical_disease_family",
                                   "historical_disease", "historical_disease_subclass",
                                   "icd_7", "icd_7_subclass", "icd_9", "icd_9_subclass"))

  |> iidda.analysis::lookup_join(location_lookup,
                                 c("location", "location_type"))

  |> add_provenance("canmod-cdi-unharmonized")
  |> mutate(iidda_source_id = source_from_digitization_id(digitization_id))
)

grp_columns <- c(
    "period_start_date", "period_end_date", "time_scale", "collection_year"
  , "original_dataset_id", "digitization_id", "scan_id", "iidda_source_id"
  , "disease", "nesting_disease", "basal_disease"
  , "historical_disease", "historical_disease_family", "historical_disease_subclass"
)
national_total = (full_harm
  |> filter(original_dataset_id != "cdi_qc_1915-1925_mn_county_municipality")
  |> filter(iso_3166_2 == '')
  |> select(all_of(c(grp_columns, "cases_this_period")))

  |> mutate(cases_this_period = as.numeric(cases_this_period)) # Convert to numeric, 'unclear' becomes NA
  |> filter(!is.na(cases_this_period)) # Remove rows with NA values in cases_this_period
)

national_totals_check = (full_harm
  |> filter(original_dataset_id != "cdi_qc_1915-1925_mn_county_municipality")
  |> filter(iso_3166_2 != '')
  |> mutate(cases_this_period = as.numeric(cases_this_period))
  |> group_by(across(all_of(grp_columns)))
  |> summarise(cases_this_period_sum = sum(cases_this_period))
  |> ungroup()
  |> inner_join(y = national_total)#, by = c('period_start_date', 'period_end_date',
                                    #    'original_dataset_id', 'digitization_id', 'scan_id',
                                    #    'disease", "nesting_disease", "basal_disease'))

  |> filter(cases_this_period != cases_this_period_sum)
  |> mutate(
        discrepancy = cases_this_period - cases_this_period_sum
      , percent_error = ifelse(cases_this_period == 0
          , NA
          , abs((cases_this_period - cases_this_period_sum) / cases_this_period * 100)
      )
  )
  |> arrange(desc(percent_error))
)



clean_cdi = (tidy_cdi
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

  |> filter(time_scale != "yr")

  |> add_basal_disease(disease_lookup)
)

# In "cdi_qc_1915-1925_mn_county_municipality" , check if sum of municipalities = quebec total
qc_total = (clean_cdi
  |> filter(original_dataset_id == "cdi_qc_1915-1925_mn_county_municipality", location_type == 'province')
  |> mutate(cases_this_period = as.numeric(cases_this_period)) # Convert to numeric, 'unclear' becomes NA
  |> filter(!is.na(cases_this_period)) # Remove rows with NA values in cases_this_period
)

qc_check = (clean_cdi
      # filter for municipal data
      |> filter(location_type == 'municipality')

      |> group_by(across(all_of(grp_columns)))

      # Exclude groups where any cases_this_period is 'unclear'
      |> filter(!any(cases_this_period == 'unclear'))
      |> summarise(cases_this_period_sum = sum(as.numeric(cases_this_period)))
      |> ungroup()

      |> inner_join(qc_total, by = grp_columns)

      |> filter(cases_this_period != cases_this_period_sum)
      |> mutate(
            discrepancy = cases_this_period - cases_this_period_sum
          , percent_error = ifelse(cases_this_period == 0
              , NA
              , abs((cases_this_period - cases_this_period_sum) / cases_this_period * 100)
          )
      )
      |> select(names(national_totals_check))
)

# for data sources with national-level-data (DBS, statcan and health canada sources),
# for a period_start_date, period_end_date, original_dataset_id, disease
# sum provincial data, compare to Canadian data, return data frame of instances
# where sum ! = national total

# national_total = (clean_cdi
#   |> filter(original_dataset_id != "cdi_qc_1915-1925_mn_county_municipality")
#   |> filter(iso_3166_2 == '')
#   |> select(period_start_date, period_end_date, original_dataset_id, digitization_id, scan_id, iidda_source_id, cases_this_period,
#              historical_disease, historical_disease_family, historical_disease_subclass)
#
#   |> mutate(cases_this_period = as.numeric(cases_this_period)) # Convert to numeric, 'unclear' becomes NA
#   |> filter(!is.na(cases_this_period)) # Remove rows with NA values in cases_this_period
# )
#
# national_totals_check = (clean_cdi
#   |> filter(iso_3166_2 != '') # Provincial data
#   |> filter(original_dataset_id != "cdi_qc_1915-1925_mn_county_municipality")
#   |> mutate(cases_this_period = as.numeric(cases_this_period))
#   |> group_by(period_start_date, period_end_date, original_dataset_id, digitization_id, scan_id, iidda_source_id,
#                historical_disease, historical_disease_subclass, historical_disease_family)
#
#   # Exclude groups where any cases_this_period is 'unclear'
#   |> filter(!any(cases_this_period == 'unclear'))
#   |> summarise(cases_this_period_sum = sum(cases_this_period))
#   |> ungroup()
#
#   |> inner_join(national_total, by = c('period_start_date', 'period_end_date',
#                                         'original_dataset_id', 'digitization_id', 'scan_id', "iidda_source_id", 'historical_disease',
#                                         'historical_disease_subclass', 'historical_disease_family'))
#
#   |> filter(cases_this_period != cases_this_period_sum)
# )


location_cross_check = (rbind(national_totals_check, qc_check)
  ## focused on sub-annual scales so not a priority
  |> filter(time_scale != "yr")

  ## usually indicates national data entry problem, so it is not
  ## a priority given focus on sub-national
  |> filter(cases_this_period != "0")

  ## missing pages for some provinces make location cross check impossible
  |> filter(!((digitization_id == "cdi_ca_1960_wk_prov_dbs") & (period_end_date == "1960-04-09")))

  ## location totals totally messed up
  |> filter(!((scan_id == "cdi_poliopar_ca_1949-55_wk_prov") & (collection_year %in% c("1949", "1950", "1951", "1952"))))
  |> filter(!((scan_id == "cdi_polionpar_ca_1949-55_wk_prov") & (collection_year %in% c("1954", "1955"))))
  |> filter(!((scan_id == "cdi_poliounspec_ca_1949-55_wk_prov") & (collection_year %in% c("1953"))))
  |> filter(!((scan_id == "cdi_wc_ca_1924-55_wk_prov") & (collection_year %in% c("1945"))))

  ## mix of scales makes yearly roll-ups of limited utility for cross checking
  |> filter(!((scan_id == "cdi_polio_ca_1924-55_wk_prov") & (collection_year %in% c("1924", "1925", "1926", "1927", "1928", "1929", "1930", "1931", "1932"))))
  |> filter(!((scan_id == "cdi_tbunspec_ca_1933-55_wk_prov") & (collection_year == "1953")))
  |> filter(!((scan_id == "cdi_mumps_ca_1924-55_wk_prov") & (collection_year == "1955")))
  |> filter(!((scan_id == "cdi_tbunspec_ca_1933-55_wk_prov") & (collection_year == "1952")))

  |> arrange(desc(percent_error))  ## focus on the biggest problems first
)

metadata = get_dataset_metadata("canmod-location-cross-check")
files = write_tidy_data(location_cross_check, metadata)
