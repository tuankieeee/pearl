# Release Pearl

Create a new release for Pearl. Handles version bumping, changelog updates, git tagging, and GitHub release creation.

**Arguments:** $ARGUMENTS (optional: `--dry-run` to only run pre-flight checks without making changes)

---

## Procedure

### Step 1: Pre-flight Checks

Run these checks before proceeding:

1. **Clean working directory** — Run `git status --porcelain`. If there are uncommitted changes, stop and ask the user to commit or stash them first.
2. **Branch check** — Run `git branch --show-current`. If not on `main`, warn the user and ask whether to continue.
3. **Fetch tags** — Run `git fetch --tags`.
4. **Get latest tag** — Run `git describe --tags --abbrev=0 2>/dev/null`. If no tags exist, use `v0.0.0` as the baseline.
5. **Verify new commits** — Run `git log <LATEST_TAG>..HEAD --oneline`. If there are no commits since the last tag, stop and tell the user there's nothing to release.

### Step 2: Analyze Commits

1. Get all commit messages since the last tag:
   ```
   git log <LATEST_TAG>..HEAD --format="%s"
   ```

2. Categorize each commit using conventional commit prefixes:
   - **Breaking** (`BREAKING CHANGE:`, `!:` suffix, or `breaking:`) → triggers MAJOR bump
   - **Features** (`feat:`) → triggers MINOR bump
   - **Fixes** (`fix:`) → triggers PATCH bump
   - **Other** (`chore:`, `docs:`, `refactor:`, `style:`, `test:`, `ci:`, `perf:`, `build:`) → no bump on their own

3. Determine the bump type using the highest-priority change:
   - Any breaking change → **MAJOR**
   - Any feature (no breaking) → **MINOR**
   - Only fixes/other → **PATCH**

### Step 3: Calculate New Version

1. Parse the current version from the latest tag (strip the `v` prefix).
2. Apply the bump:
   - **MAJOR**: increment major, reset minor and patch to 0
   - **MINOR**: increment minor, reset patch to 0
   - **PATCH**: increment patch
3. If the bump type is ambiguous or you're unsure, ask the user to choose.

### Step 4: Confirm with User

Present a release summary using AskUserQuestion:
- Current version (from latest tag)
- Proposed new version
- Commit counts by category (e.g., "2 features, 1 fix, 3 chores")
- List of all commit messages grouped by category

Options: **Proceed** / **Use different version** / **Cancel**

If the user chooses "Use different version", ask them for the version string.

**If `$ARGUMENTS` contains `--dry-run`, stop here.** Report the summary and exit without making any changes.

### Step 5: Update Version in `pearl/mix.exs`

Edit the `version:` line in the `project/0` function of `pearl/mix.exs`:
- Change `version: "X.Y.Z"` to the new version string
- Use the Edit tool to make this change

### Step 6: Update CHANGELOG.md

1. **Build the changelog entry** from the categorized commits in Step 2. Use these section headers (only include sections that have commits):
   - `### Breaking Changes` — for breaking changes
   - `### Added` — for `feat:` commits
   - `### Fixed` — for `fix:` commits
   - `### Changed` — for `refactor:`, `perf:` commits
   - `### Documentation` — for `docs:` commits
   - `### Other` — for `chore:`, `style:`, `test:`, `ci:`, `build:` commits

2. **Format each entry** as a bullet point with the commit message (strip the conventional commit prefix).

3. **Update CHANGELOG.md**:
   - Replace `## [Unreleased]` with the new version heading: `## [X.Y.Z] - YYYY-MM-DD` (use today's date)
   - Add a fresh `## [Unreleased]` section above it (with a blank line between)
   - Update the comparison links at the bottom of the file:
     - Change the `[Unreleased]` link to compare from the new tag: `[Unreleased]: https://github.com/existential-birds/pearl/compare/vX.Y.Z...HEAD`
     - Add a new version link: `[X.Y.Z]: https://github.com/existential-birds/pearl/compare/vPREVIOUS...vX.Y.Z`
     - If there's no previous tag (first release), use: `[X.Y.Z]: https://github.com/existential-birds/pearl/releases/tag/vX.Y.Z`

### Step 7: Commit and Tag

Run these commands:
```bash
git add pearl/mix.exs CHANGELOG.md
git commit -m "chore: release vX.Y.Z"
git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

### Step 8: Push

Ask the user for confirmation, then:
```bash
git push origin main
git push origin vX.Y.Z
```

### Step 9: GitHub Release

1. Extract the release notes for this version from CHANGELOG.md (everything between the version heading and the next version heading or end of entries).
2. Write the release notes to a temporary file.
3. Create the GitHub release:
   ```bash
   gh release create vX.Y.Z --title "vX.Y.Z" --notes-file /tmp/pearl-release-notes.md
   ```
4. Clean up the temporary file.

### Step 10: Done

Report to the user:
- The release URL (from `gh release view vX.Y.Z --json url -q .url`)
- Rollback commands in case something went wrong:
  ```
  git tag -d vX.Y.Z
  git push origin :refs/tags/vX.Y.Z
  git revert HEAD
  gh release delete vX.Y.Z --yes
  ```
