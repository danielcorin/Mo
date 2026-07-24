---
name: try-it
description: Builds the current Mo working tree and installs it to /Applications so the user can try it as a real app — replaces any running copy and relaunches it. Use when the user says "try it", "try it out", "let me try", or asks to run or install the changes.
---

# Try It: build, install, and relaunch Mo

Run the installer from the repo root:

```sh
bash .agents/skills/try-it/scripts/try-it.sh
```

The script builds Release with manual Developer ID signing, quits any running
copy, atomically replaces `/Applications/Mo.app`, resets the app's TCC
records only when the code signature actually changed, relaunches, and
verifies the app is running. Do not build or install by hand instead — the
signing identity and the TCC-reset comparison are load-bearing (see comments
in the script).

## After it runs

- Tell the user the new build is installed and running.

## Failure notes

- Build failure leaves the installed copy untouched; report the tail of the
  build log and stop.
- Writing to /Applications can be denied by a sandboxed shell — rerun the
  script with the sandbox disabled.
- If the script printed "clearing stale permission records", tell the user to
  re-grant permissions in System Settings → Privacy & Security (use the +
  button in the Accessibility pane if the app isn't listed).
- Local builds are not distributable; use `scripts/publish-release.sh` for
  notarized releases.
