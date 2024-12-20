
# ----------------------------------------
dataset_id = "cdi_ca_1924-55_wk_prov_dbs_statcan_harmonized"
# ----------------------------------------

options(iidda_api_date_sort = FALSE)
options(iidda_api_all_char = TRUE)

options(conflicts.policy = list(warn.conflicts = FALSE))
library(iidda)
library(iidda.analysis)
library(dplyr)

missing_handlers = iidda::MissingHandlers(
    unclear = c("Unclear", "unclear", "uncleaar", "uncelar")
  , zeros = c("\u2014", "\u23BB", "\u002D", "\u203E", "\u005F", "\u2013")
 #, zeros = c("—"     , "⎻"     , "-"     , "‾"     , "_"     , "–"     )
)

get_hidden_numbers = missing_handlers$get_hidden_numbers
is_reported = missing_handlers$is_reported
get_numbers_with_preceeding_footnotes_if_you_want_them = function(x) {
  ## for now just keep all numbers, which is consistent (i think) with
  ## what we do for numbers with footnotes that follow the number.
  x = trimws(sub("^\\([0-9]\\)", "", x))
  x = trimws(sub("^\u25CF", "", x)) # ● -- think this means cases reported by armed forces in one year in one scan
  x = trimws(sub("^\u2713", "", x)) # ✓ --
  x = trimws(sub("^[*]", "", x))

  return(x)
}


location_lookup = read_lookup("canmod-location-lookup")
disease_lookup = read_lookup("canmod-disease-lookup")
harmonize_data = function(part_harm, aggregate_tb = FALSE){
  if (nrow(part_harm) == 0L) stop("no data to harmonize")

  initial_harm = (part_harm

   # remove tuberculosis unspecified monthly data for 1951 as it has
   # different timescales than other tuberculosis sub-diseases
   |> filter(!(original_dataset_id == 'cdi_tbunspec_ca_1933-55_wk_prov' & time_scale == 'mo'
               & as.Date(period_end_date) >= as.Date("January 6 1951", format="%B %d %Y")
               & as.Date(period_end_date) <= as.Date("December 29 1951", format="%B %d %Y")))

   # remove smallpox yearly data for 1942, as it is unclear whether reporting
   # began in January or March
   |> filter(!(time_scale == 'yr' & disease == 'smallpox'
               & period_start_date == '1942-03-01'))

   # remove 'syphilis other' yearly data for 1944, as it is unclear whether reporting
   # began in January or September
   |> filter(!(time_scale == 'yr' & nesting_disease == 'syphilis'
               & period_start_date == '1944-08-27'))

    ## these are not data entry errors, and so we keep them in the unharmonized
    ## data, but they are clearly wrong so we adjust them here in the
    ## harmonized data
    |> mutate(
        bad_aug_14 = period_end_date == "1942-08-14"
      , bad_oct_31 = period_end_date == "1943-10-31" & disease == "whooping-cough"
    )
    |> mutate(
        period_end_date = ifelse(bad_aug_14, "1942-08-15", period_end_date)
      , period_start_date = ifelse(bad_aug_14, "1942-08-09", period_start_date)
    )
    |> mutate(
        period_end_date = ifelse(bad_oct_31, "1943-10-30", period_end_date)
      , period_start_date = ifelse(bad_oct_31, "1943-10-24", period_start_date)
    )
    |> select(-bad_aug_14, -bad_oct_31)
  )


  # no need to do this anymore - it will be done in normalize_time_scales
  if (aggregate_tb) {
    # calculating tuberculosis unspecified monthly data by summing weekly data
    # over the same monthly periods as the other TB sub-classes have

    # getting the 4wk timescales for all other TB diseases in 1951
    motimescales =
      (initial_harm
       %>% filter(
            original_dataset_id == 'cdi_tbpulm_ca_1933-55_wk_prov'
          & time_scale == 'mo'
          & period_end_date > '1950-12-31'
          & period_end_date < '1952-01-01')

       %>% select(period_start_date, period_end_date)
       %>% rename(
         mo_start_date = period_start_date,
         mo_end_date = period_end_date)
       %>% unique()
      )

    tbunspecmt =
      (initial_harm
       %>% filter(original_dataset_id == 'cdi_tbunspec_ca_1933-55_wk_prov'
          & time_scale == 'wk'
          & period_end_date > '1950-12-31'
          & period_end_date < '1952-01-01')

       %>% rowwise()
       %>% mutate(mo_start = pull(
         filter(motimescales, period_end_date >= mo_start_date
         & period_end_date <= mo_end_date), mo_start_date)
       )

       %>% mutate(mo_end = pull(
         filter(motimescales, period_end_date >= mo_start_date
         & period_end_date <= mo_end_date), mo_end_date)
       )

       # sum cases_this_period over month & location
       %>% group_by(iso_3166_2, mo_start, mo_end)
       %>% mutate(cases_this_period = sum(as.numeric(cases_this_period)))
       %>% ungroup()

       %>% select(-period_end_date, -period_start_date)
       %>% rename(period_start_date = mo_start, period_end_date = mo_end)
       %>% distinct()
       %>% mutate(time_scale = 'mo')
      )

    initial_harm = rbind(initial_harm, tbunspecmt)
  }

  harmonized =
    (initial_harm
     ## effectively convert any case numbers that are not yet numeric
     |> mutate(string_cases_this_period = cases_this_period)
     |> mutate(cases_this_period = readr::parse_number(cases_this_period))
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
       ,collection_year
     )
    )

  return(harmonized)
}


# Processing Steps

metadata = get_dataset_metadata(dataset_id) # iidda

tidy_cdi = read_prerequisite_data(dataset_id) # iidda

part_harm = (tidy_cdi
  |> lookup_join(location_lookup, names_to_join_by("location"))
  |> lookup_join(disease_lookup, names_to_join_by("disease"))
  |> mutate(year = substr(collection_year, 1L, 4L))
  |> mutate(cases_this_period = get_numbers_with_preceeding_footnotes_if_you_want_them(cases_this_period))
  |> mutate(cases_this_period = get_hidden_numbers(cases_this_period))
  |> filter(is_reported(cases_this_period))
)

# i = select(part_harm, period_start_date, period_end_date, iso_3166_2, disease, nesting_disease) |> duplicated()
# View(part_harm[i, ])
# View(filter(part_harm, period_end_date == "1955-01-01"))

sum_of_timescales = sum_timescales(
  filter(part_harm, !iidda::is_empty(collection_year)),
  filter_out_bad_time_scales = FALSE
)

time_scale_cross_check = do_time_scale_cross_check(sum_of_timescales)

good_wk_zero_mo = (time_scale_cross_check
  |> filter(cases_this_period_wk == cases_this_period_yr, cases_this_period_mo == 0)
  |> select(year, iso_3166_2, original_dataset_id, historical_disease, historical_disease_subclass, historical_disease_family)
  |> mutate(time_scale = "mo")
)
good_mo_zero_wk = (time_scale_cross_check
  |> filter(cases_this_period_mo == cases_this_period_yr, cases_this_period_wk == 0)
  |> select(year, iso_3166_2, original_dataset_id, historical_disease, historical_disease_subclass, historical_disease_family)
  |> mutate(time_scale = "wk")
)

part_harm_rm_sus_zeros = (part_harm
  |> anti_join(good_wk_zero_mo)
  |> anti_join(good_mo_zero_wk)
)

harmonized_data = harmonize_data(part_harm_rm_sus_zeros) # local

harmonized_data = (harmonized_data
  ## review of the data source suggest that the weekly data
  ## for the polio sub-diseases are not reliable. we could
  ## keep the monthly all-polio data in addition to the monthly
  ## sub-diseases, but I think weekly is more important than
  ## a breakdown for now.
  ## (but doing this filter might be causing a problem for location cross checks,
  ## which are off without the quebec data even though there are no data
  ## entry errors)
#  |> filter(!(iso_3166_2 == "CA-QC" & time_scale == "wk" & collection_year == "1952" & nesting_disease == "poliomyelitis"))

  ## poor data quality. crossed out data with illegible footnotes about
  ## what it means.
  |> filter(!(iso_3166_2 == "CA-AB" & collection_year == "1939" & disease == "tuberculosis_unspecified"))

  ## week ending 1955-01-01 is given at the end of
  ## collection_year == "1954", but there are blank
  ## entries for this week in collection_year == "1955"
  ## so we need to remove them.
  |> filter(!((collection_year == "1955") & (period_end_date == "1955-01-01")))

  ## looks like an error in the source given the various marginal
  ## totals on the data sheet
  |> filter(!((scan_id == "cdi_pneu_ca_1924-55_wk_prov") & (period_end_date == "1955-01-01") & (iso_3166_2 == "CA-SK")))

  ## too many cross-out corrections in this part of the data to believe
  |> filter(!((scan_id == "cdi_typh_ca_1924-52_wk_prov") & (iso_3166_2 == "")))
)

# x = (harmonized_data
#   |> mutate(cases_int = as.integer(cases_this_period, na.rm = TRUE))
#   |> group_by(across(c(-collection_year, -cases_this_period)))
#   |> mutate(
#       cases_max = max(cases_int, na.rm = TRUE)
#     , cases_sum = sum(cases_int, na.rm = TRUE)
#     , cyear_max = collection_year[order(cases_int, decreasing = TRUE)][1L] ## fancy which.max
#   )
#   |> ungroup()
#   |> mutate(match = (cases_max == cases_this_period) & (cases_sum == cases_this_period))
# )
# View(filter(x, !match))

metadata = add_column_summaries(harmonized_data, dataset_id, metadata) # iidda

files = write_tidy_data(harmonized_data, metadata) # iidda
