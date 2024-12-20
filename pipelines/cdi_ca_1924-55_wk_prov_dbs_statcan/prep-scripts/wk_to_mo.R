rollforward_to_same_weekday = function(x) {
  x = as.Date(x)
  y = rollforward(x)
  y - days((wday(y) - wday(x)) %% 7)
}

rollbackward_to_same_weekday = function(x) {
  x = as.Date(x)
  y = rollbackward(x)
  y + days((wday(x) - wday(y)) %% 7)
}
