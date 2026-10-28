# myerscode/workflows

Shared, reusable GitHub Actions workflows for the [myerscode](https://github.com/myerscode) organization.

Write CI once here, call it everywhere. Each workflow is a [reusable workflow](https://docs.github.com/en/actions/using-workflows/reusing-workflows) invoked with `uses:` from a consumer repo and pinned to a release tag.

## Available workflows

| Workflow | File | Purpose |
|----------|------|---------|
| Dependabot Auto-merge | `.github/workflows/dependabot-auto-merge.yml` | Approve + auto-merge Dependabot PRs when checks pass and there are no conflicts |
| PHP Tests | `.github/workflows/php-tests.yml` | PHPUnit across an OS + PHP-version matrix |
| Lint & Analyse | `.github/workflows/php-lint.yml` | Pint (code style) + PHPStan (static analysis) |
| Security Audit | `.github/workflows/php-security-audit.yml` | `composer audit` |
| Code Coverage | `.github/workflows/php-coverage.yml` | PHPUnit coverage + Codecov upload |

## Usage

Add a workflow to a consumer repo (`.github/workflows/ci.yml`) that calls these. A full example lives in [`examples/consumer-ci.yml`](examples/consumer-ci.yml):

```yaml
name: CI

on:
  push:
    branches: [ main, develop, feature/** ]
  pull_request:
    branches: [ main, develop, feature/** ]

permissions:
  contents: read

jobs:
  quality:
    uses: myerscode/workflows/.github/workflows/php-lint.yml@v1

  tests:
    uses: myerscode/workflows/.github/workflows/php-tests.yml@v1
    with:
      php-versions: "['8.5']"
      os: "['ubuntu-latest', 'macos-latest', 'windows-latest']"

  audit:
    uses: myerscode/workflows/.github/workflows/php-security-audit.yml@v1

  coverage:
    uses: myerscode/workflows/.github/workflows/php-coverage.yml@v1
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
```

## Inputs

Every workflow ships defaults that match current myerscode conventions (PHP 8.5; `ctype, iconv, json, mbstring`; `composer install --prefer-dist --no-progress --no-interaction`), so most repos can call them with no `with:` block. Override only what differs.

### `dependabot-auto-merge.yml`

Approves and enables auto-merge on Dependabot PRs. GitHub completes the merge
only once branch protection's required checks pass **and** the branch has no
conflicts, so the "no conflicts" rule is enforced by GitHub itself.

Only **one** run proceeds at a time per repo (shared concurrency group,
`cancel-in-progress: false`): if several Dependabot PRs open at once they are
processed serially and none are dropped.

Grouped (multi-dependency) PRs are handled: Dependabot leaves `update-type`
empty for a group, so the gate reads `updated-dependencies-json` and judges the
PR by the **highest** bump in the group (e.g. a group containing a major bump
is blocked under `highest-auto-merge: minor`). An unparsable group fails closed.

The caller **must** trigger on `pull_request_target` — see
[`examples/consumer-dependabot-auto-merge.yml`](examples/consumer-dependabot-auto-merge.yml).
Dependabot's `pull_request` token is read-only and has no secret access, so it
cannot merge; `pull_request_target` runs in the base repo with a writable
token. This workflow never checks out or runs PR code, so that is safe.

Repo prerequisites:
- Settings → General → **Allow auto-merge** enabled.
- Branch protection with required status checks on the default branch (else
  `--auto` merges immediately with nothing to gate on).

| Input | Default | Notes |
|-------|---------|-------|
| `merge-method` | `squash` | `merge`, `squash`, or `rebase` |
| `highest-auto-merge` | `minor` | `patch`, `minor`, or `major`. Caps the semver bump that may auto-merge |
| `approve` | `true` | Also submit an approving review |

### `php-tests.yml`
| Input | Default |
|-------|---------|
| `php-versions` | `['8.5']` (JSON array) |
| `os` | `['ubuntu-latest', 'macos-latest', 'windows-latest']` (JSON array) |
| `extensions` | `ctype, iconv, json, mbstring` |
| `composer-flags` | `--prefer-dist --no-progress --no-interaction` |
| `test-command` | `vendor/bin/phpunit --testdox --no-coverage` |

### `php-lint.yml`
| Input | Default |
|-------|---------|
| `php-version` | `8.5` |
| `lint-command` | `vendor/bin/pint --test` |
| `analyse-command` | `vendor/bin/phpstan analyse --no-progress` |

### `php-security-audit.yml`
| Input | Default |
|-------|---------|
| `php-version` | `8.5` |
| `audit-command` | `composer audit` |

### `php-coverage.yml`
| Input / Secret | Default |
|----------------|---------|
| `php-version` | `8.5` |
| `coverage-command` | `vendor/bin/phpunit --testdox --coverage-clover ./coverage.xml` |
| `coverage-file` | `./coverage.xml` |
| `CODECOV_TOKEN` (secret) | **required** |

## Versioning

Consumers pin to a tag. Cut a release tag and move a floating major alias so repos can track `@v1`:

```bash
git tag -a v1.0.0 -m "v1.0.0"
git tag -f v1            # floating major alias
git push origin v1.0.0
git push -f origin v1
```

Pin to `@v1` for automatic minor/patch updates, or to an exact `@v1.0.0` for a frozen contract. Avoid `@main` in consumers — an unversioned change here would hit every repo at once.

## License

MIT
