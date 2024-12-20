## creates the file called global-metadata/r-package-recommendations.R

library_calls = ("pipelines/*/prep-scripts/*.R"
  |> Sys.glob()
  |> lapply(readLines)
  |> lapply(grep, pattern = "library", value = TRUE)
  |> unlist()
  |> unique()
)
for (line in library_calls) eval(parse(text = line))
info = sessionInfo()
pkgs = c(names(info$loadedOnly), names(info$otherPkgs))
vers = lapply(pkgs, packageVersion) |> lapply(as.character) |> setNames(pkgs) |> unlist()
dput(vers, file = "global-metadata/r-package-recommendations.R")
