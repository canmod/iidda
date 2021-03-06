# Dataset Lifecycle

## Life Cycle States

![Life Cycle Diagram](../assets/lifecycle.svg)

### Unreleased

All datasets begin their life in an `Unreleased` state. To be in this state the only requirements are
1. At least one source data file is located in the `source-data` folder of the dataset project
2. A `README.md` file is located in the top-level of the dataset project with a Lifecycle badge in `Unreleased` state

To get out of this state the dataset must comply with all of the requirements given in the [guidelines for contributors](https://github.com/davidearn/iidda/blob/main/CONTRIBUTING.md) (note: this is currently in draft. todo: add checklist for requirements to leave `Unreleased` state). Once these requirements are satisfied, a pull request should be made with only a single change -- the lifecycle badge gets modified. A member of the IIDDA core team will review the pull request and merge it as either a `Static` or `Dynamic` dataset.

### Static

Static datasets have matured in that they have been determined to comply with all IIDDA standards, and will only be changed if errors are detected.

### Dynamic

Dynamic datasets are mature and have a stable structure, but will change regularly as new data get added to the sources.

### Superseded

The data in a Superseded dataset has been added to another dataset because it has been determined that this is a more natural home for the data.

## Dataset Versioning

Datasets in the `Unreleased` state do not have versions, apart from their `git` commit hash. Datasets in `Static` and `Dynamic` state ...

`major.minor`

* `major` version changes indicate a lifecycle transition
* `minor` version changes indicate that the source data have changed

Commit hashes are used for finer-grained changes, so there is no need for a `patch` number.

TODO: Where does the dataset version live? Either a small top-level file or buried in the metadata?

TODO: Consider how semantic versioning maps onto dataset versioning.  https://semver.org/:

Given a version number MAJOR.MINOR.PATCH, increment the:
1. MAJOR version when you make incompatible API changes,
2. MINOR version when you add functionality in a backwards compatible manner, and
3. PATCH version when you make backwards compatible bug fixes.

For datasets we might think like this:

Given a version number MAJOR.MINOR.PATCH, increment the:
1. MAJOR version when you make incompatible ...,
2. MINOR version when you add functionality in a ...,
3. PATCH version when you make ...

What are the ...'s?





## Dataset State History

All datasets should contain a JSON file `lifecycle-states.json` that lists the state transitions and the times that they happened.

The format of `lifecycle-states.json` is a list of dictionaries, where each dictionary represents a state transition and has the following keys and valid values:
* `date`:  `YYYY-MM-DD` (only the last transition in a day is recorded)
* `from`: state at the beginning of the day
* `to`: state at the end of the day

TODO: Define a process for automatically generating these files.

TODO: GitHub actions sort of make sense, but not until the process is mature and I'm a little concerned that GitHub actions itself is likely to introduce breaking changes in the medium-term.

# References

Inspiration from https://lifecycle.r-lib.org/articles/stages.html.
