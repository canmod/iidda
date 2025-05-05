

# ----------------------------------------
# Information for Locating Metadata
tidy_dataset = "pop_ca_1871-1921_10-yearly_prov_age_sex"
digitization = "pop_ca_1871-1921_10-yearly_prov_age_sex"
metadata_path = "pipelines/cen_ca_1921/tracking"
# ----------------------------------------




options(conflicts.policy = list(warn.conflicts = FALSE))
#remotes::install_github('canmod-eidm/iidda-tools', subdir = 'R/iidda')
library(tidyxl)
#library(plyr)
library(dplyr)
library(iidda)
library(unpivotr)
library(zoo)
library(stringr)
library(lubridate)
library(memoise)


locations_iso = read_data_frame("lookup-tables/canmod-location-lookup.csv")

get_sheet_names = function(data){
  grep("[A-z]+", unique(data$sheet), value = TRUE)
}

make_tidy_data = function(focal_sheet, data){
  x = (data
   %>% filter(sheet == focal_sheet, between(row, 4, 73), between(col, 1, 18))
   %>% select(row, col, data_type, numeric, character, address)

   %>% behead('N', year)
   %>% behead('N', sex)

   %>% mutate(location1 = filter(., address == 'A6')$character)
   %>% mutate(location2 = filter(., address == 'A40')$character)
   #%>% mutate(location2 = str_extract(filter(., col == 1)$character, '[A-Z]+')
   # Extracting locations using regular expressions may be better than using the cell address.

   %>% filter(col != 1, col != 9, row != 7, row != 6, row != 40, row != 41)

   %>% behead('W', age)
   %>% mutate(age = gsub('[.].*', '', age))
   %>% mutate(age = gsub('[…].*', '', age))

   # Formatting location columns: location 1 is for rows 8-39, location 2 for rows 42 to 73
   %>% mutate(location = ifelse(between(row, 8, 39), location1, location2))

   %>% mutate(year = na.locf(year, na.rm = F))

   # Formatting sex column
   %>% mutate(sex = ifelse(sex == 'Total', 'Both sexes', sex))
   %>% mutate(sex = gsub('é', 'e', sex))
   %>% mutate(sex = gsub('-', '', sex))
   %>% mutate(sex = gsub('\\b[A-z]{8,9}\\b$', '', sex))
   %>% mutate(sex = trimws(sex))
   %>% mutate(sex = gsub('Male', 'Males', sex))
   %>% mutate(sex = gsub('Female', 'Females', sex))

   %>% mutate(population = ifelse(is_empty(numeric), character, numeric))
   %>% mutate(population = gsub(',', '', population))
   # Not sure what to do about - here. I don't think they are 0, so I am leaving them in the tidy data.

   # Filtering out empty rows.
   %>% filter(!(is.na(population) & age == ''))

   # Formatting upper_age and lower_age columns
   %>% mutate(age = trimws(age))

   %>% mutate(lower_age = ifelse(grepl('^Under', age), 0, ''))
   %>% mutate(lower_age = ifelse(grepl('^[1-4]', age), age, lower_age))
   %>% mutate(lower_age = ifelse(grepl('⎯[0-9]+', age) , str_extract(age, '^[0-9]{1,2}'), lower_age))
   %>% mutate(lower_age = ifelse(grepl('100', age), 100, lower_age))
   %>% mutate(lower_age = ifelse(grepl('Specified', age), '', lower_age))
   %>% mutate(lower_age = ifelse(grepl('Unspecified', age), '', lower_age))
   %>% mutate(lower_age = ifelse(grepl('Population', age), '', lower_age))

   %>% mutate(upper_age = ifelse(grepl('^Under 1', age), 0, ''))#str_extract(age, '[0-9]'), ''))
   %>% mutate(upper_age = ifelse(grepl('^Under 5', age), 4, upper_age))#str_extract(age, '[0-9]'), ''))
   %>% mutate(upper_age = ifelse(age == '1' | age == '2' | age == '3' | age == '4', age, upper_age)) # NAs introduced by coercion...
   %>% mutate(upper_age = ifelse(grepl('⎯[0-9]+', age), str_extract(age, '[0-9]{1,2}$'), upper_age))
   %>% mutate(upper_age = ifelse(age == '95-99', 99, upper_age))
   %>% mutate(upper_age = ifelse(grepl('100', age), '', upper_age))
   %>% mutate(upper_age = ifelse(grepl('Specified', age), '', upper_age))
   %>% mutate(upper_age = ifelse(grepl('Unspecified', age), '', upper_age))
   %>% mutate(upper_age = ifelse(grepl('Population', age), '', upper_age))

   # For 1891 and 1901, ages 95-99 and 100 and over are grouped into 95 and over.
   %>% filter(!(year == 1891 & lower_age == 100), !(year == 1901 & lower_age == 100))
   %>% mutate(upper_age = ifelse(year == 1891 & upper_age == 99 | year == 1901 & upper_age == 99, '', upper_age))

   # Formatting period_start_date and period_end_date columns
   %>% mutate(date = ymd(paste(year,'01','01', sep = '')))
   #%>% mutate(date = ymd(paste(as.numeric(year)+9, '12','31')))
   %>% mutate(age_group = age)
   %>% mutate(age_group = ifelse(grepl('Specified', age_group), 'all-specified-ages', age_group))
   %>% mutate(age_group = ifelse(grepl('Unspecified', age_group), 'all-unspecified-ages', age_group))
   %>% mutate(age_group = ifelse(grepl('Population', age_group), 'all-ages', age_group))
   %>% mutate(age_group = ifelse(grepl('^[0-9]+$', lower_age) & grepl('^[0-9]+$', upper_age), sprintf("%s-%s", lower_age, upper_age), age_group))
   %>% mutate(age_group = ifelse(grepl('^[0-9]+$', lower_age) & !grepl('^[0-9]+$', upper_age), sprintf("%s-", lower_age), age_group))

   %>% mutate(nesting_age_group = "")
   %>% mutate(nesting_age_group = ifelse(age_group %in% c("all-specified-ages", "all-unspecified-ages"), "all-ages", ""))

   %>% iso_3166_codes(locations_iso)
   %>% rename(historical_age_group = age)

   ## merge age group names that are merged in the source
   %>% mutate(historical_age_group = ifelse(age_group == "95-", "95-99, 100 and over⎯et plus", historical_age_group))

   %>% mutate(
     population = trimws(population),
     population = ifelse(population == "-", "0", population)
   )

   %>% select(date, iso_3166, iso_3166_2, location, sex, age_group, nesting_age_group, historical_age_group, lower_age, upper_age, population)
  )
  age_lookup = select(x, age_group, nesting_age_group, lower_age, upper_age) |> mutate(lower_age = as.numeric(lower_age), upper_age = as.numeric(upper_age) + 1) |> distinct() |> arrange(age_group)
  numeric_nesting = apply(age_lookup, 1L, find_nest, age_lookup)
  age_lookup = (age_lookup
    |> mutate(nesting_age_group = ifelse(is.na(numeric_nesting), nesting_age_group, numeric_nesting))
    |> select(age_group, nesting_age_group)
  )
  (x
    |> select(-nesting_age_group)
    |> left_join(age_lookup, by = "age_group")
    |> relocate(nesting_age_group, .before = lower_age)
    |> identify_scales(time_scale_identifier = force)
  )
}

find_nest = function(x, df_sum, most_recent_numeric_ancestor = "all-specified-ages"){
  upper = as.numeric(x[["upper_age"]])
  lower = as.numeric(x[["lower_age"]])

  df_width = (df_sum
            %>% mutate(bin_width = upper_age - lower_age)
            %>% drop_na(bin_width)
            %>% arrange(bin_width))

  # If numeric age groups, calculate nesting age group
  if(!is.na(lower) & !is.na(upper)){
    df_hold = (df_width
               %>% filter(bin_width > (upper - lower) | is.infinite(bin_width)) # look for bins strictly larger than current
               %>% filter(lower >= lower_age & upper <= upper_age) # Use end points to check which bins encompass
               %>% arrange(bin_width)
               %>% slice_min(order_by = bin_width))

    if(nrow(df_hold) != 0){
      if(nrow(df_hold) > 1){
        warning(paste0("Multiple possible nesting age groups for ", x[["age_group"]], " found.\n Used ", df_hold$age_group[1], " in table."))
      }

      nest_group_name = df_hold$age_group[1]
      return(as.character(nest_group_name))
    }
    return(most_recent_numeric_ancestor)
  }
  return(NA)
}
find_nest = memoise(find_nest)

rep_delimiter = function(x, base_delimiter, escape = FALSE, max_repeats = 5, ...) {
  stopifnot(length(base_delimiter) == 1L)
  regex = base_delimiter
  if (escape) regex = paste("\\", regex, sep = "")
  for(n in 1:max_repeats) {
    regex = sprintf("(%s){%s}", regex, n)
    if (!any(grepl(regex, x, ...))) {
      delimiter = sprintf(" %s ", strrep(base_delimiter, n))
      return(delimiter)
    }
  }
  stop("\n"
       , "The base delimiter ", base_delimiter
       , " requires more than ", max_repeats, " repeats\n"
       , "to avoid clashes with the data.\n"
       , "Please either choose another base delimiter\n"
       , "or increase the max_repeats argument."
  )
}

make_bin_desc = function(df, identifying_columns = c("date", "location", "sex")) {
  bin_delimiter = rep_delimiter(unique(df$age_group), "|", escape = TRUE)

  (age_df_ids = df
    #%>% select(all_of(c(identifying_columns, "age_group")))
    %>% group_by(across(all_of(c(identifying_columns))))
    %>%
      summarise(
        n_bins = n(),
        bin_desc = paste0(sort(unique(age_group)), collapse = bin_delimiter)

      )
    %>% ungroup()
    %>% mutate(bin_id = vctrs::vec_group_id(bin_desc))
    #%>% select(age_group, bin_id)
  )

  (df_new = left_join(df, age_df_ids, by = identifying_columns)
    #%>% distinct()
    #%>% filter(!if_all(.fns = function(x) x == "")) ## remove blank rows
    %>% arrange(bin_desc)
    %>% mutate(default_age_group = NA)
    %>% find_default()
    %>% select(-bin_desc)
  )
}

find_default = function(df){
  id_ls = unique(df$bin_desc)

  for(i in 1:length(id_ls)){
    id = id_ls[i]

    df_hold = filter(df, bin_desc == id)
    nest_struc = unique(df_hold$nesting_age_group)

    # When determining default_age_group, keep any non-empty entries
    default_original = df_hold$default_age_group

    # If no nesting_age_struc, make all bins with numerical meaning part of default
    if(all(is.na(df_hold$nesting_age_group))){
      df_hold = (df_hold
                 %>% mutate(default_age_group = ifelse(is.na(default_age_group),
                                                       ifelse((is.na(upper_age) | is.na(lower_age)),
                                                       FALSE,
                                                       TRUE),
                                                       default_age_group)
                            )
                 )
    } else{
      df_hold = (df_hold
                 %>% mutate(default_age_group = ifelse(is.na(default_age_group),
                                                       ifelse((age_group %in% nest_struc),
                                                       FALSE,
                                                       TRUE),
                                                       default_age_group)
                            )
                 )
    }

    # If new default_age_group was determined, check overlap and range
    # If defined for all groups already, skip over this check
    if(any(is.na(default_original))){
      df_hold = (df_hold
                 %>% check_overlap()
                 %>% check_range())
    }

    if(i == 1){
      df_new = df_hold
    } else{
      df_new = rbind(df_new, df_hold)
    }
  }

  return(df_new)
}

check_overlap = function(df){
  df_new = df
  df_num = df %>%
    filter(default_age_group == TRUE) %>%
    filter(grepl("^[0-9]+$", lower_age)) %>%
    mutate(upper_age = ifelse(grepl("^[0-9]+$", upper_age), upper_age, "200")) %>%
    mutate(
      lower_age = as.integer(lower_age),
      upper_age = as.integer(upper_age)
    )
    select(lower_age, upper_age, age_group, bin_id)

  test_results = (df_num
    |> group_by(bin_id)
    |> summarise(mutually_exclusive = no_overlaps(lower_age, upper_age))
    |> ungroup()
  )
  test_results
}

no_overlaps = function(lower, upper) {
  i = order(lower)
  n = length(lower)

  for (j in 2:n) {
    consistent_bin_bounds = lower[i][j] <= upper[i][j]
    consistent_bin_neighbours = lower[i][j] > upper[i][j - 1L]
    if (!consistent_bin_neighbours | !consistent_bin_bounds) return(FALSE)
  }
  TRUE
}
check_range = function(df){
  df_new = df
  df_fine = df %>%
    filter(default_age_group == TRUE) %>%
    filter(!is.na(upper_age) & !is.na(lower_age))

  if (nrow(df_fine) == 0L) return(df_fine)


  ages_rep = c()
  for(i in 1:nrow(df_fine)){
    up = df_fine$upper_age[i]
    low = df_fine$lower_age[i]

    ages_rep = c(ages_rep, low:up)
  }

  up = max(df_fine$upper_age)
  low = min(df_fine$lower_age)

  if(length(setdiff(low:up, ages_rep)) != 0){
    df_new = (df_new
              %>% mutate(default_age_group = NA))
  }

  return(df_new)
}


## Note:
## Running make_tidy_data produces a warning message for every sheet: NAs
## introduced by coercion. These happen when running as.numeric(age) to form the
## upper age column.
## These NAs are then dealt with in the next steps, when forming the upper_age
## column for other ages, and have no effect on the end result.

## Processing Steps

metadata = get_tracking_metadata(tidy_dataset, digitization, metadata_path, original_format = FALSE) # iidda

data = read_digitized_data(metadata) # iidda

sheets = get_sheet_names(data) # local

tidy_sheet_data = sapply(sheets, make_tidy_data, data, simplify = FALSE) # local

tidy_data = select(bind_rows(tidy_sheet_data, .id = 'sheet'), -sheet)

tidy_data = add_provenance(tidy_data, tidy_dataset) # iidda

metadata = add_column_summaries(tidy_data, tidy_dataset, metadata) # iidda

files = write_tidy_data(tidy_data, metadata) # iidda
