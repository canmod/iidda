# Dataset Lifecycle

TODO: I feel like derived data need to figure into this picture somehow. Maybe this fits into the definition of major/minor versions? Could be a gap with the current system.

## State Transitions

![Life Cycle Diagram](../assets/lifecycle.svg)

## State Descriptions

### Submission

Someone has submitted a new dataset that needs to be reviewed by the IIDDA core team (i.e. by someone with push-privileges). When someone from outside of the core team, `Submission`s will be created via a pull request (TODO: should _everyone_ have to submit a pull request to create a `Submission`?).

### Static

Static datasets have matured in that they have been determined to comply with all IIDDA standards, and will only be changed if errors are detected.

### Dynamic

Dynamic datasets are mature and have a stable structure, but will change regularly as new data get added to the sources.

### Classic-IIDDA

This is an initial state for a dataset with source that is uploaded directly as an csv/xlsx file that used to be on the classic IIDDA website https://davidearn.mcmaster.ca/iidda.

Any file that begins in the `Classic-IIDDA` state can programmatically be pulled together.

### Superseded

The data in a Superseded dataset has been added to another dataset because it has been determined that this is a more natural home for the data.

## Dataset Versioning

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
