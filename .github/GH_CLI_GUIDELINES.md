GH CLI Guidelines for workflows

This repository uses the GitHub CLI (`gh`) in a few places. To avoid "401 Bad credentials" errors in Actions, follow these rules when adding `gh` commands to workflows:

1. Ensure workflow permissions allow the required actions. Example at the top of your workflow:

permissions:
  actions: write
  contents: read

2. Provide the built-in token to `gh` explicitly in any step that runs `gh`:

env:
  GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
run: |
  echo "$GH_TOKEN" | gh auth login --with-token > /dev/null
  gh auth status
  # now run gh commands safely

3. Prefer using the GitHub Actions REST API or `actions/github-script` for small tasks where possible (no CLI auth needed).

4. For local helper scripts (in `scripts/`), document that `gh auth login` must be run by a user before use. This repository includes a CI safety check that flags `gh` usages without auth/token - see `.github/workflows/gh-cli-safety.yml`.

5. When in doubt, add a single-step authentication line before using `gh` in a workflow step.

If you want, I can open a PR with these changes and run the safety check in CI to verify. 