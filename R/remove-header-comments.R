paths = Sys.glob("pipelines/**/prep-scripts/*.R")
scripts = lapply(paths, readLines)
locations = (scripts
  |> lapply(grep, pattern = "This script has been automatically modified")
  |> vapply(\(x) x[1L], numeric(1L))
)

for (i in seq_along(paths)) {
  if (!is.na(locations[i])) {
    lines_to_remove = locations[i] + (-1:2)
    writeLines(scripts[[i]][-lines_to_remove], paths[i])
  }
}
