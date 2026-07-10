# Adopting this in another workflow

This is demo code, not a published product or Marketplace action. If you want to reuse it in your own repos there are two options:

- copy the composite actions into another repository and edit them,
- or refer to the actions from this repository by tag or commit SHA, if this repo is public or shared with the caller.

## Option 1: copy the pieces

Copy these directories:

```text
.github/actions/tetragon-setup
.github/actions/tetragon-report
```

The `tetragon-setup` directory includes its own `policies/` directory. If you copy the whole directory, you also copy those bundled policies. The setup action loads every `*.yml` and `*.yaml` file in that bundled directory.

Bundled policies live inside the copied setup action:

```text
.github/actions/tetragon-setup/policies
```

You can also put repo-specific policies in the calling repo:

```text
.github/tetragon-policies
```

If that directory exists, the setup action loads every `*.yml` and `*.yaml` file in it.

If you copy these actions into the same repo that is being checked, the bundled policies are still part of that repo. A PR can change them unless you protect workflow and action changes with review rules.

The local `.github/tetragon-policies` directory is useful for extra repo-specific checks, but again it could be modified by a PR unless you add protections.

Example workflow:

```yaml
name: CI with Tetragon

on:
  pull_request:
  push:
    branches: [ main ]

permissions:
  contents: read

jobs:
  ci:
    runs-on: ubuntu-24.04

    steps:
      - uses: actions/checkout@v5

      - name: Install Tetragon
        uses: ./.github/actions/tetragon-setup
        with:
          tetragon_version: v1.7.0
          enforce_policies: "false"

      - name: Run your normal CI
        run: |
          set -euo pipefail
          make test

      - name: Report Tetragon events
        if: ${{ always() }}
        uses: ./.github/actions/tetragon-report
```

## Option 2: reference this repo

Another repository can call the composite actions directly from this repo if it is public, or if it is private and shared with the caller.

```yaml
      - uses: actions/checkout@v5

      - name: Install Tetragon
        uses: lizrice/tetragon-ci/.github/actions/tetragon-setup@v0.1.0
        with:
          tetragon_version: v1.7.0
          enforce_policies: "true"

      - name: Report Tetragon events
        if: ${{ always() }}
        uses: lizrice/tetragon-ci/.github/actions/tetragon-report@v0.1.0
```

Use a release tag or full commit SHA rather than `@main`, so that CI does not change unexpectedly.

The same policy-source rules apply when another repo references this repo directly. Bundled policies are loaded from this repo's action directory:

```text
lizrice/tetragon-ci/.github/actions/tetragon-setup/policies
```

If the caller repo has `.github/tetragon-policies`, those local policies are loaded as additional policies. A local policy file cannot use the same filename-derived policy name as a bundled policy. For example, a local `sensitive-file.yml` will be rejected because the bundled action already includes `sensitive-file.yml`. The setup action checks filenames, not the YAML `metadata.name` field.

You can see an example of this in the `lizrice/containers-from-scratch` demo. That repo refers to the setup and report actions from `tetragon-ci` and uses the bundled policies as the baseline check.

For the normal build-and-test job, the baseline policies come from the tagged `tetragon-ci` action rather than the PR checkout. That means the consuming repo does not have to duplicate the Tetragon install and reporting steps, but a PR cannot edit away the bundled baseline policy that is checking it.

## Suggested order

Start exploratory runs with `enforce_policies: "false"`. This lets you see what your CI jobs actually do without breaking builds.

After you have reviewed the logs and changed the policies so that normal CI work is allowed, switch to `enforce_policies: "true"` or omit the input. The setup action fails closed: only the literal value `false` disables enforcement. The source policy files are not edited. In monitor mode, the action loads the policies with `tetra tracingpolicy add --mode monitor`; in enforcement mode, it loads the same policy files with enforcement actions intact.

## Protect against merging malicious PRs

If you want GitHub to block a PR from being merged when the Tetragon job fails, configure the target branch to require that job as a status check.

In GitHub, that is configured in the repository settings. Use either `Settings` -> `Branches` -> `Branch protection rules`, or `Settings` -> `Rules` -> `Rulesets`. In either place, look for `Require status checks to pass before merging`, then choose the Tetragon job name after it has run at least once.

## Can a PR turn this off?

Yes, if the workflow relies only on policy files from the PR checkout.

A pull request can change files in its own branch. If the workflow loads `.github/tetragon-policies/network.yml` from that branch, the PR can also change that file.

That's fine for extra repo-specific checks, but it is weak as the only protection for the PR that is being tested.

That's why this workflow supports bundled policies that can be kept in a separate repo where the PR can't rewrite it:

```yaml
- name: Install Tetragon
  uses: lizrice/tetragon-ci/.github/actions/tetragon-setup@v0.1.0
  with:
    enforce_policies: "true"
```

Because the setup action always loads its bundled policies, those baseline policies come from the tagged `tetragon-ci` action repo, not from the checked-out PR branch.

## What about secrets?

For pull requests from forks, GitHub does not pass repository secrets to the runner, apart from `GITHUB_TOKEN`.

That helps, but it does not make PR CI harmless.

PR code can still read the source checkout, generated artifacts, dependency files, and anything the workflow deliberately gives to the job.

The risky case for secrets is a job that legitimately needs access to a value, then runs code that can leak that value. That is most obvious for same-repo pull requests, where the author is a collaborator or automation with permission to push a branch in the repository.

The self-contained `tetragon-ci` workflow uses a deliberately fake value named `CI_DEMO_SECRET` to show a secret being exfiltrated. Preventing unexpected network connections is one layer of defense against this.

## Be careful with `pull_request_target`

`pull_request_target` is one of the events you can put in the `on:` section of a GitHub Actions workflow file.

For example:

```yaml
on:
  pull_request_target:
```

It is different from the more common `pull_request` event.

With `pull_request`, the workflow is for checking the pull request. That is the normal choice for building or testing code from the PR.

With `pull_request_target`, the workflow runs in the context of the base repository. That can be useful for trusted automation that comments on a PR, labels it, or checks metadata without running the PR's code.

The dangerous pattern is:

1. trigger on `pull_request_target`,
2. check out code from the PR branch,
3. run that code while secrets or privileged tokens are available.

That can give untrusted PR code access to things it should not have.

For normal PR checks that build or run code from the PR, prefer `pull_request`.

If a workflow needs secrets, try to keep that work separate from the job that runs PR-controlled code. For example, run build and test jobs without secrets, then use a separate trusted workflow or a post-merge job for steps that need credentials.

This demo uses `pull_request`, not `pull_request_target`.

## Tuning policies

You can run the workflow with enforcement turned off, to observe whether a policy generates logs for something you expect to happen. Turn on enforcement once you're happy with the policies.
