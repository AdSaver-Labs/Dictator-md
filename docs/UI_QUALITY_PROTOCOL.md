# Dictator-md UI Quality Protocol

Every user-facing UI change must be verified before installation or handoff.

## Required checks

1. Build the universal app with `make app`.
2. Test the changed view at compact and large supported window sizes.
3. Confirm important values are readable without hover and never collapse into ellipses.
4. Add accessibility labels to controls and dense data displays used by automated checks.
5. Run `make ui-smoke` after installing the build.
6. Visually inspect a screenshot of each changed responsive state.

## Monthly activity guard

`make ui-smoke` launches Dictator-md, selects the monthly dashboard view, and validates the real macOS accessibility tree at `1400x900` and `900x700`. It fails if the `CAP` or `WPM` metrics are missing or truncated.

New responsive widgets should extend this smoke test or add an equivalent native Accessibility check.
