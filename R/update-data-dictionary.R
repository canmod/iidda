library(jsonlite)
("metadata/columns/*.json"
  |> Sys.glob()
  |> lapply(read_json)
  |> write_json(
      "global-metadata/data-dictionary.json"
    , auto_unbox = TRUE, pretty = TRUE
  )
)
