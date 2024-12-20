## recommended version numbers, just because these are the versions
## that sw happens to have. this sourced r file is automatically
## produced using R/update-r-package-recommendations.R
dependencies = source("global-metadata/r-package-recommendations.R")$value

inst_deps = names(dependencies) %in% installed.packages()[, "Package"]
if (!all(inst_deps)) {
  missing_pkgs = names(dependencies)[!inst_deps]
  message(
      "------------\n"
    , "attempting to install the following r packages because they\nare required for at least some scripts:\n"
    , paste0(sprintf("  %s", missing_pkgs), collapse = "\n")
    , "\n------------"
  )
  canmod = c("iidda", "iidda.analysis", "iidda.api", "rapiclient", "LBoM.tools") ## can we drop LBoM.tools?
  missing_canmod = intersect(missing_pkgs, canmod)
  missing_cran = setdiff(missing_pkgs, missing_canmod)
  install.packages(missing_cran, repos = list(CRAN = "https://cran.r-project.org"))
  install.packages(missing_canmod
    , repos = c("https://canmod.r-universe.dev", "https://cran.r-project.org")
  )
}

dependencies = dependencies[inst_deps]
versions = (dependencies
  |> names()
  |> lapply(packageVersion)
  |> vapply(as.character, character(1L))
  |> setNames(names(dependencies))
)

if (!identical(dependencies, versions)) {
  for (dep in names(dependencies)) {
    if (as.package_version(dependencies[dep]) > as.package_version(versions[dep])) {
      warning(
          "package "
        , dep
        , " is older than is recommended. "
        , "you might want to update it. "
        , "see https://github.com/canmod/iidda#requirements for details."
      )
    }
  }
}
