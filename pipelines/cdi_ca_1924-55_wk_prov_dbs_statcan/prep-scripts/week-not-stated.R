week_not_stated = function(beheaded_sheets) {
  week_not_stated_one_year = function(sheet) {
    (sheet
      |> filter(grepl('^WK', week_ending))
      |> unite(cases_this_period, c(numeric, character), sep='', na.rm=TRUE)
      |> mutate(location=na.locf(location))
      |> dplyr::rename(time_scale = stat_name)
      |> select(location, time_scale, collection_year, cases_this_period)
    )
  }
  week_blank_one_year = function(sheet) {
    (sheet
      |> filter(iidda::is_empty(week_ending))
      |> unite(cases_this_period, c(numeric, character), sep='', na.rm=TRUE)
      |> mutate(location=na.locf(location))
      |> dplyr::rename(time_scale = stat_name)
      |> select(location, time_scale, collection_year, cases_this_period)
    )
  }

  y = sapply(beheaded_sheets, week_not_stated_one_year, simplify = FALSE)
  y = bind_rows(y) |> filter(!iidda::is_empty(cases_this_period))
  dir = file.path("supporting-output", tidy_dataset)
  if (!dir.exists(dir)) dir.create(dir)
  path = file.path(dir, "week-not-stated.csv")
  write_data_frame(y, path)

  y1 = sapply(beheaded_sheets, week_blank_one_year, simplify = FALSE)
  y1 = bind_rows(y1) |> filter(!iidda::is_empty(cases_this_period)) |> anti_join(y)
  path = file.path(dir, "week-blank.csv")
  write_data_frame(y1, path)

  bind_rows(list(not_stated = y, blank_week = y1), .id = "type")
}
