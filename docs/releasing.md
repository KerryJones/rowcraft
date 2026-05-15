# Releasing rowcraft-mobile

Manual release runbook. The `release-please` and `mobile-build` GitHub Actions
workflows are disabled (renamed to `*.disabled` in `.github/workflows/`) to
preserve the free Actions quota. Everything below runs locally.

See "Re-enabling release-please later" at the bottom if you want to switch
back to the automated flow.

## When to release

Cut a new release when there's a meaningful change for testers in the alpha
track — a new feature, a fix for a reported bug, or a notable polish pass.
There's no fixed cadence; release when you have something worth shipping.

## Prerequisites (one-time)

- `apps/mobile/android/key.properties` exists and points at the Play Store
  signing keystore. (Already set up locally.)
- `gh` CLI is installed and authenticated (`gh auth status`).
- Working tree is on `main` and clean (`git status`).
- You can sign in to the Google Play Console for the rowcraft project.

## Per-release procedure

### 1. Sync main

```sh
git checkout main
git pull
```

### 2. Inspect commits since the last tag

```sh
make release
```

Prints the current version, the last tag, the commits since that tag scoped
to `apps/mobile` and `packages/shared`, and an abridged checklist of the
steps below. Does no destructive actions — safe to run any time.

### 3. Decide the semver bump

Use the Conventional Commits prefixes in the log above:

- `feat!:` or `fix!:` (breaking change) → **major** bump (`1.0.0 → 2.0.0`)
- any `feat:` → **minor** bump (`0.6.0 → 0.7.0`)
- only `fix:` / `chore:` / `refactor:` / `docs:` / `test:` → **patch** bump (`0.6.0 → 0.6.1`)

Pre-1.0, treat breaking changes as a minor bump. We're at `0.x` and that's
fine for an alpha-track app.

### 4. Bump version in `apps/mobile/pubspec.yaml`

Bump both the semver and the build number. The build number must increase on
every Play Console upload, even across rebuilds of the same semver.

```diff
- version: 0.6.0+17
+ version: 0.7.0+18
```

### 5. Update `apps/mobile/CHANGELOG.md`

Paste a new section at the top, matching the format that release-please was
generating. Use the compare-link form so existing entries stay consistent.

```markdown
## [0.7.0](https://github.com/KerryJones/rowcraft/compare/rowcraft-mobile-v0.6.0...rowcraft-mobile-v0.7.0) (2026-05-15)


### Features

* short description from the commit ([abc1234](https://github.com/KerryJones/rowcraft/commit/abc1234...))

### Bug Fixes

* short description from the commit ([def5678](https://github.com/KerryJones/rowcraft/commit/def5678...))
```

- Section headers: `### Features` for `feat:` commits, `### Bug Fixes` for
  `fix:` commits. Skip empty sections.
- One bullet per commit, body taken from the conventional-commit subject (no
  prefix), trailing `([short-sha](commit-url))` link.
- `short-sha` is 7 characters; get the full SHA from `git log`.
- Date is today, ISO format.

### 6. Update `.release-please-manifest.json`

Bump `"apps/mobile"` to match the new semver so the manifest stays accurate
in case release-please is re-enabled later.

```diff
- { "apps/mobile": "0.6.0" }
+ { "apps/mobile": "0.7.0" }
```

### 7. Commit the bump

```sh
git commit -am "chore: release rowcraft-mobile 0.7.0"
```

Conventional-commits compliant per `CLAUDE.md`. No `Co-Authored-By` lines.

### 8. Tag the release

```sh
git tag rowcraft-mobile-v0.7.0
```

Tag name matches the prefix used by previous tags (`rowcraft-mobile-v` —
see `git tag --list`).

### 9. Build the signed AAB

```sh
make release-build
```

Produces `releases/rowcraft-0.7.0+18.aab`. Signed via
`apps/mobile/android/key.properties`.

Quick sanity-check the signature (optional — `flutter build appbundle`
will fail loudly if signing didn't work):

```sh
jarsigner -verify releases/rowcraft-0.7.0+18.aab
```

Expected output: `jar verified.`

### 10. Push the commit and tag

```sh
git push
git push origin rowcraft-mobile-v0.7.0
```

### 11. Create the GitHub release

```sh
gh release create rowcraft-mobile-v0.7.0 \
  --notes-file <(awk '/^## /{n++} n==1' apps/mobile/CHANGELOG.md) \
  releases/rowcraft-0.7.0+18.aab
```

The `awk` snippet extracts just the topmost `## […]` section from the
changelog (the one you just added) and uses it as the release notes. The
AAB is attached as a release artifact for traceability.

### 12. Upload the AAB to Play Console

1. Open the Google Play Console → RowCraft → **Testing → Closed testing**
   (alpha track).
2. **Create new release**.
3. Upload `releases/rowcraft-0.7.0+18.aab`.
4. Paste the release notes (same content used for the GitHub release).
5. **Save → Review release → Start rollout to Closed testing**.

Propagation to testers takes anywhere from a few minutes to a few hours.

### 13. Smoke test

Once the Play Store has propagated, install the update on a test device and
verify the golden path (start a workout, complete a segment, finish, sync).

## Re-enabling release-please later

When you want the automated flow back:

```sh
git mv .github/workflows/release-please.yml.disabled .github/workflows/release-please.yml
git mv .github/workflows/mobile-build.yml.disabled .github/workflows/mobile-build.yml
```

Confirm `.release-please-manifest.json` matches the current
`apps/mobile/pubspec.yaml` semver — release-please uses the manifest as the
source of truth for "what was last released". If you bumped the manifest
manually on every release per step 6, it should already be in sync.

Commit and push:

```sh
git commit -am "chore: re-enable release-please and mobile-build workflows"
git push
```

## Troubleshooting

### "Last git tag" is `rowcraft-mobile-v0.5.0` but pubspec says `0.6.0+17`

When the workflows were disabled, the `0.6.0` release-please PR had been
merged (the `chore(main): release rowcraft-mobile 0.6.0` commit landed and
the changelog was updated) but the post-merge tag job either didn't run or
didn't push the `rowcraft-mobile-v0.6.0` tag. That's why `git describe`
reports `v0.5.0` as the latest tag even though we're on `0.6.0` in
`pubspec.yaml` and the manifest.

You have two options for the first manual release:

1. **Tag v0.6.0 retroactively, then move forward.** Find the merge commit
   for the 0.6.0 release (`git log --oneline --grep "release rowcraft-mobile
   0.6.0"`), tag it, push the tag, and then bump to 0.6.1 / 0.7.0 from there.
   ```sh
   git tag rowcraft-mobile-v0.6.0 <sha>
   git push origin rowcraft-mobile-v0.6.0
   ```
2. **Skip the retroactive tag.** Just bump straight to the next version and
   create that tag normally. The `v0.6.0` tag stays missing forever, which
   is fine — the CHANGELOG entry still exists.

Recommendation: option 1, so `git describe` and the changelog stay aligned.

### "AAB rejected by Play Console: version code already used"

Bump the `+buildnum` portion of `version:` in `pubspec.yaml` and rebuild.
Every uploaded AAB needs a higher build number than any previous upload,
even for re-rolls of the same semver.

```sh
make bump-version
make release-build
```

`make bump-version` increments only the build number (e.g. `0.7.0+18` →
`0.7.0+19`), leaving the semver alone.

### "gh release create" fails with auth error

Run `gh auth login` and retry. The Play Console upload is a separate manual
step and doesn't use `gh`.
