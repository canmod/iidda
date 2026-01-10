library(jsonlite)

dictionary_list = ("metadata/columns/*.json"
  |> Sys.glob()
  |> lapply(read_json)
)

# vapply(dictionary_list, getElement, character(1L), "name") |> cat(sep = "\n")

write_json(
    dictionary_list
  , "global-metadata/data-dictionary.json"
  , auto_unbox = TRUE, pretty = TRUE
)
