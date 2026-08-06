# Next steps — dev-workflow cursor

Thin, live cursor for whoever picks up this repo next. Points into the deep record
(`docs/hardening_roadmap.md`, the sprint plans, the issues) — it does not copy them.
Regenerate this at the end of every working session.

## Now

**`implementing` — `ST` (organization transfer, `Seuss27/` → `glunk-works/`).**

The planning-review gate is **closed** — the human signed off on a reshaped ST on 2026-08-06.

## Just done

**ST was reshaped at its pre-implementation review, and three of its tasks are complete.**

- **F45 is now closed by *removal*, not correction.** The sprint had gated an irreversible
  repository transfer on its own hardest task — a full permissions-boundary construction
  upstream, merged *and* human-applied. Since the upstream role is **inert today** (F44),
  deleting the project entry closes F45 outright at a fraction of the risk. Full reasoning,
  and every downstream plan the change falsified, is in `docs/hardening_roadmap.md` § 10
  (2026-08-06 entry) — **read that before touching ST, S1, S2 or MW.**
- **T0 done** — `iam:ListAttachedRolePolicies` committed; `tofu plan` in `bootstrap/` reports
  `No changes.` **It needed no apply**: the drift was *code behind live*, so it closed in the
  direction that writes nothing. The sprint dropped from four human applies to **three**.
- **T1 verified against live state** — `tofu plan -destroy` on the OIDC provider fails with
  `Instance cannot be destroyed … lifecycle.prevent_destroy set`.
- **T2a′ done** — `path = "/bedrock-rag/"` on the module's role, so **MW** rebuilds at the
  right path and it is not replaced twice. The `permissions_boundary` half moved to S2.

**`ST-T2′` is prepared.** Upstream PR **`glunk-works/global-bootstrap#5`** deletes the
`bedrock-serverless-rag` entry from `var.projects` along with `bedrock_rag_policy` and its
attachment; `tofu validate` and `tofu fmt -check -recursive` pass upstream. The org-wide F41
issue is filed as **`glunk-works/global-bootstrap#6`** and linked from roadmap § 9.4.

## Next

**A human merges and applies `glunk-works/global-bootstrap#5`** (admin SSO, never CI —
BR-D1). Then verify against **live AWS**, not the merged HCL:

```
aws iam get-role --role-name github-actions-bedrock-serverless-rag   # must be NoSuchEntity
```

Record the applied timestamp in ST's PR body. **Only then does `ST-T3` start.**
**Model: `opus` (architect).**

## Open gates and blockers

**HITL Gate: OPEN.** The next action is human-only. Three remain, in order:

1. **merge + `tofu apply`** of `global-bootstrap#5`;
2. **T3's two `bootstrap/` applies (widen, then narrow)** — **blocked on F48**: an
   off-workstation, verified-restorable copy of `bootstrap/terraform.tfstate` **does not yet
   exist**, and that file is the only record of the org-shared OIDC provider;
3. **the transfer itself** — a Settings UI action, irreversible in practice.

An agent may prepare files and draft commands for all three; it may execute none of them.

⚠️ **T3's narrow must complete in the same session as the transfer.** GitHub usernames are
reclaimable, so the widen leaves a dangling-subject trust policy standing until it does.

## Pointers

- `docs/hardening_roadmap.md` — reference of record **and** threat model; § 10's 2026-08-06
  entry is the authoritative record of the reshape.
- `sprints/ST_org_transfer/sprint_plan.md` — **the active sprint.** It carries a **reshape
  banner**; where the banner and a task body disagree, **the banner wins**. Task 2 is retained
  but marked **SUPERSEDED** — implementing it re-creates the role F45 is about.
- `sprints/S2_identity_least_privilege/sprint_plan.md` — new blocking **S2-T0** re-creates the
  upstream entry *with* the boundary. **ST Task 2b is normative for it.**
- `sprints/MW_make_it_work/sprint_plan.md` — F55 re-pointed at this repo's own
  `state_access_policy`; MW's "adopt the upstream role first" option is **struck**.
- `.ai/archive/S0-next-steps.md` — S0's final cursor, frozen for history.
