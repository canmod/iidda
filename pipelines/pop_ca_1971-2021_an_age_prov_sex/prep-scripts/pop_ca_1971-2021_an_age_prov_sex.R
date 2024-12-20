## ======================================================
## This script has been automatically modified,
## so please do not manually modify it.
## ======================================================


# ----------------------------------------
# Information for Locating Metadata
tidy_dataset = "pop_ca_1971-2021_an_age_prov_sex"
digitization = "pop_ca_1971-2021_an_age_prov_sex"
metadata_path = "pipelines/pop_ca_1971-2021_an_age_prov_sex/tracking"
# ----------------------------------------

options(conflicts.policy = list(warn.conflicts = FALSE))
#remotes::install_github('canmod/iidda-tools', subdir = 'R/iidda')
library(iidda)
library(dplyr)
library(tidyxl)
library(unpivotr)
library(tidyr)
library(zoo)
library(lubridate)

make_tidy_data = function(data) {

  ## separate records with different units of measure (UOM)
  persons = filter(data, UOM == "Persons")

  ## join this back in at some point as `median_age` and `average_age`,
  ## and put these columns into the data dictionary
  years = filter(data, UOM == "Years")

  tidy_data = transmute(
    persons,
    #period_start_date = ymd(paste0(REF_DATE, "0101")),
    date = ymd(paste0(REF_DATE, "0101")),
    location = GEO,
    sex = Sex,
    age_group = Age.group,
    population = VALUE
  )

  # order matters!  the first match is used, so this would fail if
  # 'single_year' came before 'over'
  age_bound_re_templates = list(
    over = "%{left}s[0-9]+%{right}s years and over",
    single_year = "%{left}s[0-9]+%{right}s years?",
    to = "%{lower_left}s[0-9]+%{lower_right}s to %{upper_left}s[0-9]+%{upper_right}s(?: years)?",
    all_ages = "^All"
  )

  # TODO: check that these hash tables result in the correct age bins
  ll = make_age_hash_table(unique(tidy_data$age_group), age_bound_re_templates, "lower")
  uu = make_age_hash_table(unique(tidy_data$age_group), age_bound_re_templates, "upper")
  #browser()
  (tidy_data
    # %>% mutate(nesting_age_group = case_when(
    #   grepl("^[0-9]+ to [0-9]+ years", age_group) ~ "All ages",
    #   grepl("^[0-9]+ years?$", age_group) ~ ,
    # ))
    %>% mutate(age_grouping_scheme = case_when(
      grepl("^[0-9]+ to [0-9]+ years", age_group) ~ "5-year bins from 0-99+",
      age_group == "100 years and over" ~ "5-year bins from 0-99+",
      grepl("^[0-9]+ years?$", age_group) ~ "1-year bins from 0-99",
      .default = "all ages"
    ))
    %>% mutate(
      lower_age = ll(age_group),
      upper_age = uu(age_group)
    )
    #%>% select(-age_group)
    %>% relocate(population, .after = last_col())
    |> identify_scales(time_scale_identifier = force)
  )
}

metadata = get_tracking_metadata(tidy_dataset, digitization, metadata_path, original_format = FALSE) # iidda

data = read_digitized_data(metadata) # iidda

tidy_data = make_tidy_data(data) # local

metadata = add_column_summaries(tidy_data, tidy_dataset, metadata) # iidda

files = write_tidy_data(tidy_data, metadata) # iidda
