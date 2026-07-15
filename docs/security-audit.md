# Security audit

Reviewed by: Codex, an AI coding assistant based on GPT-5.

Date reviewed: 8 July 2026.

This is an AI-assisted security review of the demo/reference approach in this repository. It is not a professional penetration test, a formal threat model, or a certification that the approach is production-safe.

## Short version

This repository is a useful demo/reference for Tetragon as a CI runtime policy gate. It shows Tetragon starting inside a GitHub-hosted Ubuntu runner, watching what happens during a CI job, and blocking a specific suspicious action.

The most important limitation is that this is not a complete sandbox for untrusted code. Tetragon can block behaviour that matches a policy. It does not remove all the risks of running pull request code with access to secrets, network, files, or passwordless `sudo`.

The safe security claim is:

> Tetragon can turn specific runtime behaviours into CI policy gates.

Do not rely on this repo as proof that:

- Tetragon makes it safe to run untrusted pull request code with secrets.
- Tetragon prevents all secret leaks.
- A pull request cannot bypass or tamper with the CI guard.
- This is a complete production security control as-is.

## Main findings

### 1. Passwordless sudo is the biggest gap

GitHub-hosted Linux runners allow the CI job to run commands with passwordless `sudo`. This matters because Tetragon is installed on the same runner that later runs the PR-controlled code.

A malicious PR step could try to interfere with Tetragon before leaking data, for example by stopping the service, killing the process, deleting policy files, or using Tetragon's own CLI to remove policies.

The current demo blocks the demonstrated suspicious `curl` command. It does not currently prove that Tetragon cannot be tampered with by later root-capable PR code.

What to do:

- Document this as runtime policy enforcement, not a sandbox.
- Do not expose real production secrets to PR-controlled jobs.
- Consider an anti-tamper policy if you want to make this part of the demo. For example, detect or block `systemctl`, `service`, `kill`, `pkill`, `tetra`, `bpftool`, and writes under `/etc/tetragon` during the protected part of the job.
- Test any anti-tamper policy carefully, because the setup and report actions may legitimately need some privileged commands.
- For stronger real-world isolation, run PR-controlled code somewhere it cannot control the host runner.

### 2. A policy only blocks what it matches

The default network policy, `curl-network.yml`, is intentionally simple. It matches `curl` TCP connections, and kills them in enforcement mode.

That is good for a reference example because it is easy to understand. But it does not block every way to leak a secret.

It does not stop, for example:

- `python`, `node`, `perl`, `ruby`, `openssl`, `git`, `ssh`, or a custom binary making network connections
- shell tricks such as `/dev/tcp`
- DNS-based leaks
- writing a secret into logs, artifacts, caches, or test reports
- sending data through a service that the policy allows

What to do:

- Treat `curl-network.yml` as a demo policy, not a general data-loss prevention policy.
- Observe normal CI behaviour first, then enforce rules for behaviour that should not happen in that part of the workflow.
- Split jobs or steps so that dependency download, build, test, upload, and deploy phases can have different expectations.
- Keep secrets out of PR jobs where possible.

### 3. Trusted policies help, but only if the workflow is protected

The strongest part of this design is that the baseline PR-blocking policies come from the trusted `tetragon-ci` action repo, not from files in the PR checkout.

That means a PR cannot simply edit `.github/tetragon-policies/network.yml` in its own branch to weaken the baseline policy.

However, a PR can still try to change the workflow itself. For example, it could:

- delete the Tetragon setup step
- set `enforce_policies: "false"`
- change the action reference to another repo or branch
- move sensitive commands so they run before Tetragon starts

What to do:

- Configure branch protection or a repository ruleset in GitHub so the Tetragon check must pass before merge.
- Use a stable, unique job name for that required check.
- Require review for changes under `.github/workflows/`.
- Use `CODEOWNERS` so workflow and policy changes need review from the right maintainers.
- Do not let broad groups bypass branch protection.
- For security-sensitive use, pin the action to a full commit SHA. A tag such as `@v0.1.0` is easier for a demo, but a full SHA is harder to move.

### 4. Secrets in PR jobs are still risky

GitHub does not normally pass repository secrets to workflows triggered by pull requests from forks, except for `GITHUB_TOKEN`. That is helpful, but it is not the whole story.

The demo scenario is a same-repo PR from a collaborator or automation account. In that case, the workflow can expose a repository secret to code from the PR branch. Tetragon can block the specific leak it is configured to catch, but the secret is still present in the job environment.

What to do:

- Use fake secrets for demos and examples.
- Avoid real production secrets in PR-controlled jobs.
- Prefer short-lived credentials and OpenID Connect for cloud access.
- Put deployment credentials behind GitHub environment protection rules.
- Split secret-using work away from scripts that come from the PR branch.

### 5. The installer and action reference are part of the trust chain

A consumer repo that uses this repo's composite actions is trusting this repo.

The setup action also downloads a Tetragon release tarball and runs its installer with `sudo`. The default version is pinned to `v1.7.0`, but the demo does not currently verify the downloaded asset with a checksum or signature.

What to do:

- Pin action references to a commit SHA for stronger security.
- Keep GitHub Actions permissions minimal.
- Consider checksum or signature verification for the Tetragon download if this becomes more than a demo.
- Do not let untrusted users choose `tetragon_version` in a required security check.

### 6. Logs can leak information

Tetragon logs can include process arguments. In this repo's exfiltration demo, the suspicious command includes a deliberately fake secret in a URL.

GitHub masks configured secrets in logs. That is useful, but it is not a complete guarantee. If a value is encoded, split, transformed, or not registered as a GitHub secret, it may still appear in logs or artifacts.

What to do:

- Do not put real secrets in command-line arguments.
- Keep the full JSON log output as a demo/debug feature, not a production default.
- For real workflows, print only the policy events needed to explain the failure.
- Use GitHub's `::add-mask::VALUE` for sensitive values that are not already GitHub secrets.

## What the current approach gets right

### Tetragon starts before protected code

In this repo's demo workflow, Tetragon starts before `demo/benign-ci.sh`, `demo/exfiltrate-secret.sh`, or `demo/sensitive-file.sh` runs.

In the staged `containers-from-scratch` workflow, Tetragon starts before `go build` and before the project check in `ci/check.sh`. That is the right order. If Tetragon starts after the build or test step, it is only reporting later activity.

### The consumer workflow uses a trusted baseline policy

The consumer workflow uses:

```yaml
enforce_policies: "true"
```

This means the bundled baseline policies are loaded from the referenced `tetragon-ci` action repo, not from the PR checkout. The workflow may also load extra repo-specific policies from `.github/tetragon-policies`, but those are additional policies rather than the trusted baseline.

### The default demo policy is understandable

`curl-network.yml` is specific enough to understand quickly:

- `curl` TCP connections are reported in monitor mode
- `curl` TCP connections are killed in enforcement mode

This is clearer than a broad policy that matches every TCP connection and also catches background runner traffic.

### The workflow avoids `pull_request_target`

The consumer workflow uses `pull_request`, not `pull_request_target`.

That is the right default when the workflow checks out and runs code from the PR. GitHub's docs warn that `pull_request_target` runs in the context of the base repository and can expose secrets or write privileges if it is combined with untrusted PR code.

### Repository permissions are limited

The demo workflow sets:

```yaml
permissions:
  contents: read
```

That keeps the `GITHUB_TOKEN` narrower than broader defaults. It does not solve every problem, but it is the right baseline.

### The report runs after failure

The report action uses `if: always()`. That matters because the enforcement scenario is supposed to fail. The job still prints the useful Tetragon evidence after the suspicious process is killed.

## Notes on the current implementation

### Monitor mode uses Tetragon's policy mode

The source policy files are not modified.

In enforcement mode, the setup action copies bundled and local policies into Tetragon's startup policy directory before Tetragon starts. In monitor mode, it starts Tetragon first and loads the same source policies with `tetra tracingpolicy add --mode monitor`.

This is simpler than editing policy files, and it keeps the demo closer to Tetragon's own policy-mode model. It also removes the risk that the action's own policy-editing code accidentally changes the meaning of a policy.

There is one important ordering detail: in monitor mode, the policies are loaded after Tetragon starts. The setup action waits until the policies appear as `enabled` before the CI step runs. If that readiness check fails, the protected CI step should not run.

One thing can look surprising in detailed logs: a monitor-mode policy may still show the action configured in the policy, such as `KPROBE_ACTION_SIGKILL`, even though the policy mode prevents enforcement. For the clearest security signal, check `tetra tracingpolicy list`; it shows whether the policy is in `monitor` or `enforce` mode.

### The setup action is intentionally simple

The setup action is written as a demo/reference, not a hardened configuration validator. It still checks one safety property that matters for this repo: a local policy file cannot use the same filename-derived policy name as a bundled baseline policy. For example, a local `sensitive-file.yml` is rejected because the bundled action already includes `sensitive-file.yml`. The setup action checks filenames, not the YAML `metadata.name` field.

It does not try to catch every possible misconfiguration before running `cp` or `tetra`. That is acceptable for this demo because the workflow stops before running the protected CI step. A production tool would probably give more carefully designed error messages and more complete validation.

### Broad policies can break the runner

A policy that matches every `tcp_connect` can kill runner or platform processes in enforcement mode, not just the suspicious demo step.

That is why the current bundled network policy is `curl-network.yml`, which only talks about `curl`.

### Manual workflow inputs are for the demo

The self-contained demo exposes inputs such as `tetragon_version` and `debug`.

That is useful for trying different scenarios. It is not ideal for a required security gate where many people can choose the inputs. In consumer repos, keep required PR checks fixed and predictable.

## Sources checked

- GitHub docs: [`pull_request_target`](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request_target)
- GitHub docs: [using secrets in GitHub Actions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)
- GitHub docs: [secure use reference for GitHub Actions](https://docs.github.com/en/actions/reference/security/secure-use)
- GitHub docs: [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- GitHub docs: [protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- GitHub docs: [sharing actions and workflows from a private repository](https://docs.github.com/en/actions/how-tos/reuse-automations/share-across-private-repositories)
- Tetragon docs: [Tracing Policy](https://tetragon.io/docs/concepts/tracing-policy/)
- Tetragon docs: [selectors and actions](https://tetragon.io/docs/concepts/tracing-policy/selectors/)
- Tetragon docs: [daemon configuration](https://tetragon.io/docs/reference/daemon-configuration/)

## Conclusion

This is a useful reference pattern if it is understood as one layer of defence, not as a complete CI security boundary.

The core idea is sound: install Tetragon before PR-controlled behaviour, load a trusted policy that the PR cannot edit, run the code, and fail the job if Tetragon blocks something.

The boundary is narrower than it first appears. The current policies block the demonstrated `curl` leak, not every leak. GitHub-hosted runners also give job code passwordless `sudo`, so a malicious PR with arbitrary shell execution may try to tamper with Tetragon itself.

The practical advice for readers is: observe first, enforce specific unexpected behaviour, keep baseline policies trusted, protect the workflow that loads those policies, and do not treat runtime policy enforcement as a substitute for removing secrets and privileges from untrusted CI code.
