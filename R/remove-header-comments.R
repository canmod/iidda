scripts = Sys.glob("pipelines/**/prep-scripts/*.R") |> lapply(readLines)
scripts[[20]] |> head()
locations = (scripts
  |> lapply(grep, pattern = "This script has been automatically modified")
  |> vapply(\(x) x[1L], numeric(1L))
)
