# Build Doctor — Blame Correlation Rules

`log_filtering_rules.md` covers the case where the log contains the answer. These
rules cover the case where it does not: the failing assertion is real, the stack
trace is accurate, the named file is genuinely where the wrong value came from —
and none of it is the cause.

Apply these rules whenever the input includes repository history alongside the
log. The deliverable is a **verdict about attribution**, not just a diagnosis.

---

## Rule 1 — Locate the failure before assigning it

Establish, from the log alone:
- the failing command and exit code,
- the first failing assertion (not the cascade after it),
- the source file and line the runtime names.

Write this down. It is evidence, not a conclusion.

## Rule 2 — The pull request is presumed innocent

Compare the files the failure names against the files the pull request changes.

- If the failing test, the code under test, and their transitive imports are all
  **outside** the pull request diff, the pull request is presumptively not the
  cause. Say so explicitly and go looking elsewhere.
- A pull request that adds new files and changes nothing existing cannot alter
  the behaviour of code that does not import those files.
- Check when the blamed file last changed. Code that has been untouched for
  weeks and is failing today changed environment, not implementation.

## Rule 3 — Recognise the silent-fallback failure shapes

Some subsystems degrade quietly instead of erroring. The code is deterministic;
the *data the runtime was built with* is not. These produce assertion failures
that look like application bugs and leave nothing in the log:

| Shape | Symptom | Actual dependency |
| :--- | :--- | :--- |
| Templating on a missing value | Helm/Jinja/Go templates render a missing key as empty. The manifest is valid, `lint` passes, the render exits 0, and a whole block is simply gone | the values key the chart or template actually reads |
| ICU / locale data | non-English locales format as `en-US`; English passes | full ICU data in the image (`icu-data-full`, `full-icu`, `NODE_ICU_DATA`) |
| Timezone database | date arithmetic off by an hour, or `RangeError` on a zone | `tzdata` in the image |
| CA trust store | TLS handshake failures against valid endpoints | `ca-certificates` in the image |
| Character encoding | mangled non-ASCII output | locale env (`LANG`, `LC_ALL`) |
| Float/BLAS backend | last-digit numeric drift | pinned numeric library build |

**The tell**: something is *absent* rather than wrong, or a subset of cases fails
along a data axis (locale, zone, charset) while the default passes. A logic bug
does not usually respect that line, and it rarely exits 0.

When a rendered or generated artifact is missing a section, compare the key the
consumer reads against the key the producer sets. A rename on either side
produces exactly this, with no diagnostic anywhere.

## Rule 4 — Correlate against environment provenance

The runtime is a build artifact with its own history. When the input carries a
container digest, image build time, lockfile, or resolved dependency version:

- Find every commit touching CI, container, or dependency-pinning paths
  (`ci/`, `Dockerfile*`, `.github/`, `Chart.yaml`, `Chart.lock`, `.gitignore`,
  lockfiles, `*.nix`, base image tags).
- Compare their timestamps against the artifact's build or resolution time. A
  commit that landed **before** the artifact was built is inside it, whether or
  not anyone connected the two.
- **Compare what was pinned against what was resolved.** If a lockfile was
  deleted, un-tracked, or a version range widened, the last committed lockfile
  is the record of what used to be installed - diff it against what this run
  actually pulled in. A floating range (`^`, `~`, `*`, `latest`, a mutable tag)
  means the pipeline picks a different answer on different days from identical
  source.
- Expect lag. A floating range or a nightly image rebuild delivers a change from
  days ago to today's run. That lag is exactly why nobody suspects the commit:
  it was green when it merged.
- Read the deleted lines in the culprit diff. A removed pin, comment, or package
  is frequently the entire explanation.

## Rule 5 — Never propose a patch that only silences the detector

If the check is right and the artifact is wrong, anything that makes the check
stop complaining ships the defect and removes the thing that would have caught
it next time. Refuse those fixes explicitly and name what they would cost:

- editing a correct assertion to match an incorrect value,
- skipping the test, marking it flaky, or wrapping it in a retry,
- adding a policy exception, waiver, or `--set` override for the failing rule,
- hardcoding downstream what a shared component stopped supplying — it fixes one
  repository and leaves every other consumer of that component broken and
  undiagnosed.

Fix it where it broke, not where it surfaced.

## Rule 6 — Name the owner and the correct file

A verdict that ends at "the environment changed" is not actionable. State:
- the culprit commit (sha, subject, author, age),
- the file and line to change to fix it properly,
- who is blocked besides the pull request author — if the cause is on the main
  branch, every other open pull request is failing the same way,
- whether the pull request should be merged, held, or is simply unrelated.

## Rule 7 — Be honest about confidence

Report `HIGH` only when a specific commit, a specific mechanism, and a timeline
that fits are all present. When history offers no candidate, say the cause is not
recoverable from the supplied context and state what additional input would
settle it — a fabricated culprit is worse than an open question.
