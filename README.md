# ffxiv-workflows

What the FFXIV repos' GitHub workflows share, so each piece is written once rather than copied into every repo:

- [`ffxiv_api`](https://github.com/lavaskin/ffxiv_api): the API
- [`mentor-roulette-tracker`](https://github.com/lavaskin/mentor-roulette-tracker): the website
- [`mentor-roulette-plugin`](https://github.com/lavaskin/mentor-roulette-plugin): the Dalamud plugin
- [`ffxiv_makeplace_price_tool`](https://github.com/lavaskin/ffxiv_makeplace_price_tool): the MakePlace price tool
- [`ffxiv-hub`](https://github.com/lavaskin/ffxiv-hub): the repos' tickets and shared rules

It's public because the plugin and the price tool are: a public repo can only call workflows and actions that live in a public repo.

Every repo calls these at `@main`, so a change reaches all of them as soon as it's merged. Test a change before merging it (below).

## Link ticket

`.github/workflows/link-ticket.yml` links a pull request to its ticket in `ffxiv-hub`, so it shows in the ticket's Development section. GitHub only does that itself for closing keywords in pull requests into the default branch, and the repos' pull requests go into `dev`. It calls the `addCloseIssueReferences` GraphQL mutation, which is what the issue sidebar's Development menu does.

The ticket comes from the branch name: `feature/<n>-<desc>` is `ffxiv-hub#<n>`. Any other branch is skipped, and a skip passes the check, so a green check doesn't mean it linked: the run's summary says "Linked to" or "Already linked". A ticket that doesn't exist, is closed or is a pull request fails the check, as does a missing or rejected token.

Each repo calls it from its own `.github/workflows/link-ticket.yml`:

```yaml
name: Link ticket

on:
  pull_request:
    branches: [dev]
    types: [opened, reopened, edited, synchronize]

permissions: {}

jobs:
  link:
    uses: lavaskin/ffxiv-workflows/.github/workflows/link-ticket.yml@main
    with:
      self-hosted: true
    secrets:
      token: ${{ secrets.TICKET_LINK_TOKEN }}
```

- **`branches`** is the branch ticket pull requests go into: `dev`, or `main` in a repo with no `dev` (`ffxiv-hub`, this one).
- **`synchronize`** because workflows don't run while a pull request has a merge conflict, so one opened with a conflict is linked by the push that fixes it. **`edited`** catches a base changed to `dev`, when a pull request stacked on another's branch is retargeted.
- **`self-hosted: true`** runs it on the repo's self-hosted runners (`[self-hosted, linux, x64]`), for a private repo that has them, so it costs none of the account's Actions minutes. Leave it out to run on GitHub's: public repos' minutes are free, and self-hosted runners shouldn't take public repos' jobs.
- **Pull requests from forks are skipped,** since they don't get the token.

### The token

`TICKET_LINK_TOKEN` is a fine-grained personal access token, because `GITHUB_TOKEN` only reaches its own repo and the tickets are in `ffxiv-hub`. It has Issues read and write and Pull requests read on `ffxiv-hub` and every repo that calls the workflow, doesn't expire, and each of those repos holds it as a secret: personal accounts have no secrets shared between repos. A repo that starts calling the workflow needs adding to the token, and the secret setting in it.

Fine-grained tokens can't reach a Projects board owned by a personal account, so the workflow never changes a ticket's status.

## Release plan

`release-plan/` is a composite action for the Release workflows, which run on every push to `main`. Given the version pushed, it says whether to release it (no `vX.Y.Z` tag on `origin` yet) and, if so, writes the version's section of the changelog to a file, to be the release's notes:

```yaml
- uses: actions/checkout@v7

- name: What to do
  id: plan
  uses: lavaskin/ffxiv-workflows/release-plan@main
  with:
    version: ${{ ... }}
    version-file: version in package.json

- name: Make the GitHub release
  if: steps.plan.outputs.release == 'true'
  env:
    GH_TOKEN: ${{ github.token }}
    TAG: ${{ steps.plan.outputs.tag }}
    NOTES: ${{ steps.plan.outputs.notes }}
  run: gh release create "$TAG" --target "$GITHUB_SHA" --title "$TAG" --notes-file "$NOTES"
```

| Input | |
|---|---|
| `version` | The version pushed, `X.Y.Z` |
| `version-file` | Where it's set, for the error when it isn't `X.Y.Z` (`version in package.json`) |
| `changelog` | Defaults to `CHANGELOG.md` |

| Output | |
|---|---|
| `release` | `'true'` when `vX.Y.Z` isn't tagged yet, `'false'` when it is (a merge that didn't bump the version, or a release made by hand) |
| `tag` | `vX.Y.Z` |
| `notes` | The notes file, written only when `release` is `'true'` |

It reads the changelog before the workflow makes anything, so a version bumped without its changelog section releases nothing. It fails when:

- **The version isn't `X.Y.Z`.**
- **`origin`'s tags can't be read.** `git ls-remote --exit-code` exits 2 when no tag matches and anything else nonzero when the remote couldn't be asked, so an unreachable remote is never mistaken for a version not tagged yet.
- **The changelog has no section for the version, or it's empty.** The section is the lines after `## [X.Y.Z]` up to the next `## [` heading or the link references at the bottom, trimmed of blank lines at both ends.

Its two scripts can be run on their own: `release-plan/release-action.sh <version> <version file> [remote]` prints `release` or `none`, and `release-plan/changelog-section.sh <version> [changelog]` prints the section.

## Changing them

CI runs actionlint (with shellcheck on the workflows' scripts), shellcheck on the scripts and `tests/release-plan.sh` on every pull request.

To try a change to the Link ticket workflow before merging, point one repo's caller at the branch (`@<branch>`) on a throwaway pull request, or run its script locally:

1. Extract it: `python3 -c "import yaml; print(yaml.safe_load(open('.github/workflows/link-ticket.yml'))['jobs']['link']['steps'][0]['run'])" > /tmp/link-ticket.sh`
2. Run it with `GH_TOKEN=$(gh auth token) OWNER=lavaskin HUB=ffxiv-hub BRANCH=feature/<n>-x PR_ID=<pull request node id> RUNNER_TEMP=/tmp GITHUB_STEP_SUMMARY=/tmp/summary.md bash /tmp/link-ticket.sh`. A pull request's node id is `gh pr view <n> -R lavaskin/<repo> --json id`.

The workflows have no comments: why they work the way they do is here.
