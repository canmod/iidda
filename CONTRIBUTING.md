# Contributing Data to IIDDA

TODO


# Contributing Code to IIDDA

## Derived Data

### Derived Data Column Name Conventions

#### Aggregated Case and Mortality Counts

##### Time variables

Separate columns for `Year`, `Month`, `Day of Month`, `Day of Year` with these names.  A `Year` column must be included for _every_ dataset, even if it is constant.  In general, all derived dataset of case and/or mortality counts must include one of the following sets of time variables:
* `Year`
* `Year`, `Month`
* `Year`, `Month`, `Day of Month`
* `Year`, `Day of Year`

The week-of-year style is being considered (https://en.wikipedia.org/wiki/ISO_week_date#:~:text=An%20ISO%20week%2Dnumbering%20year,Monday%20and%20end%20on%20Sunday).

##### Disease names/codes

We will be building a list of IIDDA-standard disease names, which should be used in every case when this standard is in place. Current status of this feature is here https://github.com/davidearn/iidda/issues/7.

# Tasks

Almost nothing here:  https://github.com/davidearn/iidda/projects/1.
