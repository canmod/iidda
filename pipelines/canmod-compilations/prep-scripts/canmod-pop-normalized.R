
# ----------------------------------------
dataset_id = "canmod-pop-normalized"
# ----------------------------------------

options(conflicts.policy = list(warn.conflicts = FALSE))
library(iidda)
library(iidda.analysis)
library(dplyr)
library(lubridate)

filter_pop = function(data) {
  cols = iidda.analysis:::names_to_join_by("location")
  location_lookup = read_lookup("canmod-location-lookup")
  (data
    |> iidda.analysis:::lookup_join(location_lookup, cols)
    |> filter(sex == "Both sexes")
    |> filter(age_group %in% c("all-ages", "All ages"))
    |> mutate(date = as.Date(date))
  )
}

interp_pop = function(tidy_pop){
  start_date = min(tidy_pop$date)
  end_date = max(tidy_pop$date)
  (tidy_pop
    |> group_by(iso_3166_2)
    # make the grid outside and then filter and do the population interpolation here, on the grid
    |> do(
      data.frame(date = iidda.analysis::grid_dates(start_date, end_date)
                 , population = round(approx(x = .data$date
                                             , y = .data$population
                                             , xout = iidda.analysis::grid_dates(start_date
                                                                                 , end_date
                                             )
                 )$y)
      )
    )
    |> replace_na(list(population = 0))

    |> filter(year(as.Date(date)) > 1880)
    |> filter(!is_empty(iso_3166_2)) ## TODO: where do these come from? bad location lookup table?
  )
}

metadata = get_dataset_metadata(dataset_id) # iidda

all_tidy_pop = read_prerequisite_data(dataset_id) # iidda

tidy_pop = filter_pop(all_tidy_pop) # local

population_interpolations = interp_pop(tidy_pop) # local

metadata = add_column_summaries(population_interpolations, dataset_id, metadata) # iidda

files = write_tidy_data(population_interpolations, metadata) # iidda
