## trivial automated lookup processing -- this should really be automated
file.copy(                       "lookup-tables/phac-to-canmod-disease-lookup.csv"
  , "derived-data/phac-to-canmod-disease-lookup/phac-to-canmod-disease-lookup.csv"
  , overwrite = TRUE
)
