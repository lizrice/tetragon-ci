# Tetragon CI demo

This repo shows how Tetragon can be used in GitHub Actions, using some example policies to spot and even prevent unexpected behaviours.

> [!IMPORTANT]
> This is demo code. You can use this pattern or refer to the GitHub actions in this repo, but you are responsible for choosing policies that match the behaviours you want to detect or block in your own repos.

To run the demo yourself, you'll need to fork this repo to your own GitHub account (unless you already have `workflow_dispatch` and write access to the repo where you're reading this).

See [docs/adopting-this.md](docs/adopting-this.md) for information on using this Tetragon pattern in your own repos.

## What is the threat?

CI runners (such as GitHub Actions) execute code with access to source, tokens, filesystems and network.

A pull request can add code that (either deliberately or inadvertently) behaves badly, for example exfiltrating a secret during a CI run. Depending on settings in a repo, contributors may be able to trigger a CI run simply by creating a PR, before code review.

Tetragon can be used to protect these CI runs. Given the right policy files, Tetragon can observe and even prevent unexpected behaviours.

## How it works

A workflow uses `tetragon-setup` at the start of a GitHub Actions job to install Tetragon and load a set of policies.

The main Actions workflow then runs whatever CI steps you wish in that job.

At the end of the job `tetragon-report` prints Tetragon events so you can see the output in the Actions logs.


```text
GitHub Actions workflow
        |
        v
GitHub-hosted Ubuntu runner
        |
        +--> tetragon-setup composite action
        |       |
        |       +--> load bundled and local tracing policies
        |       +--> install Tetragon
        |       +--> start compact event stream
        |
        +--> demo CI script
        |       |
        |       +--> benign or suspicious CI activity
        |
        +--> tetragon-report composite action
                |
                +--> print policy list, compact events, full JSON events, and service logs
```

## Inputs for `tetragon-setup`

The setup action always loads every `*.yml` and `*.yaml` file from its own bundled `policies/` directory. If the repo calling the action has a `.github/tetragon-policies` directory, every policy file in that directory is loaded as well.

| Input | Default | Purpose |
| --- | --- | --- |
| `tetragon_version` | `v1.7.0` | Tetragon release tarball to install. |
| `enforce_policies` | `true` | Literal `false` loads policies in monitor mode; any other value loads policies with enforcement actions intact. |
| `debug` | `false` | Enables debug-level Tetragon logging during setup. |
| `event_stream_timeout` | `180s` | Maximum lifetime for the background compact event stream. |
| `policy_ready_timeout` | `30s` | Maximum time to wait for installed Tetragon policies to become enabled. |


## Enforcement and monitor modes

The same source policy files are used for monitor mode and enforcement mode. In enforcement mode, the setup action copies the bundled and local policies into Tetragon's startup policy directory before Tetragon starts. In monitor mode, it starts Tetragon first and loads the same policies with `tetra tracingpolicy add --mode monitor`.


## Example bundled policies

This repo has bundled Tetragon policies:

* `sensitive-file.yml` detects/prevents access to some sensitive files `/etc/shadow` and `/root/.ssh`, with an exception allowing `sudo` to access `/etc/shadow`

* `curl-network.yml` detects/prevents using `curl` to make a network connection.

These may or may not be useful protections for other repos.

## Trivy phase separation demo

This repo also has a separate **Trivy phase separation demo** workflow. It downloads the Trivy databases in one job, passes that warmed data to a second job, then starts Tetragon and runs Trivy again with updates, version checks, and telemetry disabled. The second phase uses the local `.github/tetragon-policies/trivy-no-network.yml` policy to enforce that Trivy does not make network connections during the protected scan.

## Static checks

This repo also has a separate **Static checks** workflow. It runs on pull requests and on pushes to `main` in this repo, to use `shellcheck` and `actionlint` to lint the workflow/action YAML and the demo shell scripts. I don't run Tetragon in that workflow because it only executes known executables, not arbitrary test code.

## Documentation

- [Adopting this in another workflow](docs/adopting-this.md)
- [Demo runbook](docs/demo-runbook.md)
- [Security audit](docs/security-audit.md)

## Useful upstream references

- [GitHub composite actions](https://docs.github.com/en/actions/sharing-automations/creating-actions/creating-a-composite-action)
- [GitHub reusable workflows](https://docs.github.com/en/actions/sharing-automations/reusing-workflows)
- [Tetragon package installation](https://tetragon.io/docs/installation/package/)
- [Tetragon enforcement mode](https://tetragon.io/docs/concepts/tracing-policy/enforcement-mode/)
