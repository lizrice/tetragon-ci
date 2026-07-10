# Demo runbook

## Storyline

The demo has five parts:

1. Baseline visibility: install Tetragon in a normal CI run and show the captured events.
2. Fake secret exfiltration in monitor mode: show the suspicious `curl` command and network event.
3. Fake secret exfiltration in enforcement mode: show Tetragon killing `curl`.
4. Sensitive-file access as a separate case: show `/etc/shadow` access without hiding it behind the network example.
5. Consumer repo: show `containers-from-scratch` using the shared actions in a normal build-and-test workflow.


## Preflight

- Open the public repo: `lizrice/tetragon-ci`.
- Confirm GitHub Actions are enabled.
- Open the Actions tab in a browser tab before the demo.
- Have this repo open locally in a second tab or terminal, especially:
  - `.github/workflows/tetragon_policy.yml`
  - `.github/actions/tetragon-setup/action.yml`
  - `.github/actions/tetragon-setup/policies/curl-localhost-only.yml`
  - `.github/actions/tetragon-setup/policies/sensitive-file.yml`

## Demo 1: baseline visibility

GitHub UI:

1. Go to **Actions**.
2. Select **Tetragon CI demo**.
3. Select **Run workflow**.
4. Choose scenario `baseline`.
5. Run it.

Expected result:

- Workflow succeeds.
- The setup step installs Tetragon.
- The report step prints compact events, full JSON events, and service logs.
- The workflow summary shows the first 30 compact event lines and says how many more are in the job logs.

Point at:

- `Install Tetragon`
- `Run demo CI activity`
- the workflow summary's `Tetragon compact events` section
- `Report Tetragon activity`, then the `Show compact events` log group

## Demo 2: monitoring fake secret exfiltration

GitHub UI:

1. Run the workflow again.
2. Choose scenario `monitor-exfiltration`.
3. Run it.

Expected result:

- Workflow succeeds.
- The script attempts to send a fake CI secret to `https://example.com/`.
- Tetragon reports the `curl` process and outbound TCP connection, but does not kill the process.

Point at:

- `Install Tetragon`
- `Run demo CI activity`
- the workflow summary's `Tetragon compact events` section
- `Report Tetragon activity`, then the `Show loaded Tetragon policies` log group
- `Report Tetragon activity`, then the `Show compact events` log group
- event lines for `/usr/bin/curl`, `example.com`, `ci_demo_secret`, or `tcp_connect`

## Demo 3: enforcing fake secret exfiltration

GitHub UI:

1. Run the workflow again.
2. Choose scenario `enforce-exfiltration`.
3. Run it.

Expected result:

- The workflow fails during `Run demo CI activity`.
- The failure is expected.
- The report action still runs because it uses `if: always()`.
- Tetragon events show the fake secret URL, the external connection, and the enforcement action.

Point at:

- `Run demo CI activity`, showing the killed `curl` command,
- `Report Tetragon activity`, then the `Show compact events` log group,
- `Report Tetragon activity`, then the `Show full Tetragon JSON events` log group,
- compact event lines for `/usr/bin/curl` and `example.com`,
- JSON event details such as `KPROBE_ACTION_SIGKILL`.

## Demo 4: sensitive-file access

GitHub UI:

1. Run the workflow again.
2. Choose scenario `monitor-sensitive-file`.
3. Run it.
4. Optionally run it again with scenario `enforce-sensitive-file`.

Expected result:

- In monitor mode, the workflow succeeds and reports the `/etc/shadow` read.
- In enforcement mode, the workflow fails during `Run demo CI activity`.
- This is separate from the fake secret exfiltration case, so the file-access event is not hidden behind the first killed process.

Point at:

- `Run demo CI activity`, showing the attempted sensitive file access,
- `Report Tetragon activity`, then the `Show compact events` log group,
- `Report Tetragon activity`, then the `Show full Tetragon JSON events` log group,
- event lines for `/usr/bin/head`, `security_file_permission`, or `/etc/shadow`.

## Demo 5: applying the idea to containers-from-scratch

GitHub UI:

1. Open the consumer repo `lizrice/containers-from-scratch`.
2. Open the workflow that references `lizrice/tetragon-ci/.github/actions/tetragon-setup`.
3. Show that the same `build-and-test` job runs for `push` and `pull_request`.
4. Show the normal project check script, `ci/check.sh`.

Expected result:

- The workflow checks out `containers-from-scratch`.
- It installs Tetragon by referencing the setup action from this repo.
- The same workflow shape runs for main and for pull requests.
- It builds the Go program while Tetragon is running.
- It uses the trusted bundled `curl-localhost-only.yml` and `sensitive-file.yml` policies from this repo.
- The report action prints events that show what this ordinary CI job actually did.

Point at:

- the remote `uses:` lines for `tetragon-setup` and `tetragon-report`,
- the Tetragon setup step before `go build`,
- the single `build-and-test` job,
- `ci/check.sh`.
