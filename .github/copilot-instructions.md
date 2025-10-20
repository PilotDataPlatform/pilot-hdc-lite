# Copilot review instructions for this repository

You are reviewing pull requests in **pilot-hdc-lite**. The repo is primarily **Terraform (HCL)** with supporting **shell**, and includes **Helm chart values** and **Ansible** roles/playbooks.

## What this repo is for
Infrastructure & app deployment “lite” stack:
- Terraform plans/resources live under `/terraform`.
- Helm values/charts under `/helm_charts`.
- Ansible automation under `/ansible`.
- Shell utilities in the repo root (e.g., `bootstrap.sh`, `get-passwords.sh`).
- `.env.example` documents required environment variables.

## How to review changes — priorities
When you review a PR, focus comments on the following. Prefer **concrete, actionable diffs** and **one-line fix suggestions**.

### 1) Terraform (HCL)
- Enforce: `terraform fmt -check`, `terraform validate` pass.
- Ensure `terraform` blocks set `required_version` and **providers are pinned** (no floating `~> x.y` without justification).
- Backends must not be silently changed; call out any backend/state changes and ask for migration notes.
- **Modules and resources**: flag use of deprecated arguments; request references to provider docs in PR if new resources are introduced.
- **Variables/outputs**: if defaults or types change, ask for updates to `.env.example` and README snippets when they surface as environment inputs; Terraform-only knobs (e.g., chart/app version selectors in `terraform/variables.tf`) can stay documented there.
- **Security**: forbid hard-coded secrets; require use of variables, data sources, or K8s Secrets.
- Suggest adding/using `tflint` and `terraform-docs` if not present when drift is likely.

### 2) Helm (values/charts)
- Require **pinned chart versions**; no implicit latest.
- For `helm_release`, require: `atomic=true`, `cleanup_on_fail=true`, and `namespace` must reference an explicit `kubernetes_namespace` resource (e.g., `namespace = kubernetes_namespace.utility.metadata[0].name`) to ensure proper dependency ordering.
- Workloads must have **readiness/liveness probes**, **requests/limits**, and (where applicable) **PodDisruptionBudget**.
- If metrics are exposed, ensure/add **ServiceMonitor/PodMonitor** configuration.

### 3) Ansible
- Enforce **idempotency**: tasks should not report “changed” on re-run without real drift.
- Use modules over `shell/command` where possible; if `shell` is required, justify and add guards.
- No secrets in playbooks; use vault/vars files appropriately.
- Handlers for service restarts; avoid unconditional restarts.

### 4) Shell scripts
- Top of file: `set -euo pipefail` and `IFS` considerations if iterating.
- Quote all variables; check return codes; add `trap` for cleanup on error.
- Add `shellcheck` directives sparingly and always with a reason comment.
- For bootstrap changes, confirm `bootstrap.sh` still accomplishes the single-script offline bootstrap goal.

### 5) General review checklist (apply to every PR)
- ✅ CI/lint steps described in the PR (or provide commands to run locally).
- ✅ All new inputs/outputs documented in `.env.example` and READMEs.
- ✅ Secrets & credentials are **not** committed; `.gitignore` covers local `.env`.
- ✅ Version bumps include CHANGELOG/notes and compatibility rationale.
- ✅ Any destructive change (state, data, or schema) includes a **safe rollout/rollback** note.
- ✅ Makefile defaults (e.g., IPs, SSH keys) stay generic/sanitized before merge.

## Style & conventions
- Prefer small, targeted suggestions rather than sweeping refactors.
- Include links to upstream provider or chart docs when requesting changes.
- If something is ambiguous, ask the author to add a brief doc comment near the change.

## Ready-made comment snippets (use as needed)
- **Terraform pins**: "Please pin provider/module versions (avoid floating) and set/confirm `required_version` in the root `terraform` block."
- **Helm atomic**: "Set `atomic=true` and `cleanup_on_fail=true` in the `helm_release` to ensure safe rollouts/automatic rollback. Ensure `namespace` references an explicit `kubernetes_namespace` resource for proper dependency ordering."
- **Probes/limits**: "Please add readiness/liveness probes and CPU/memory requests/limits to this workload."
- **Ansible idempotency**: "This task looks non-idempotent; please use a module or add `creates/only_if`-style guards."
