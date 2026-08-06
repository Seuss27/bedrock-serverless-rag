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

**`ST-T2′` is COMPLETE and verified.** Upstream PR **`glunk-works/global-bootstrap#5`** merged
**2026-08-06T15:42:55Z** and was applied by a human. Verified against **live AWS, not the
merged HCL**: `aws iam get-role --role-name github-actions-bedrock-serverless-rag` returns
**`NoSuchEntity`**. **F45 is closed by removal.** The org-wide F41 issue is filed as
**`glunk-works/global-bootstrap#6`** and linked from roadmap § 9.4.

**F48's blocker is cleared** — `bootstrap/terraform.tfstate` and its `.backup` are copied
out-of-band. That was the last thing standing between here and T3.

## Next

**`ST-T3` — widen → transfer → narrow.** Nothing blocks it. **Model: `opus` (architect).**

⚠️ **Do not start T3 without the runway to finish it.** The narrow is a blocking acceptance
criterion that must land in the **same working session as the transfer** — see the gate below.

The three steps, in order, never combined:

1. **Widen** (human apply, `bootstrap/`) — add the new owner as a *second* value on the single
   `…:sub` key in `bootstrap/oidc-setup.tf`. **A list value, not two `StringLike` blocks** —
   the latter is a duplicate-key error. Keep the existing `Seuss27` entry; do not edit it.
   Then verify CI still authenticates **on the old owner**.
2. **Transfer** — Settings → Danger Zone → Transfer, target `glunk-works`. **Human only**, and
   irreversible in practice.
3. **Verify, then narrow** (second human apply) — once a PR run *and* a merge-to-`main` run
   have both authenticated under `glunk-works/…`, remove the old-owner entry.

**Re-run `tofu plan` in `bootstrap/` immediately before each apply** — not once at the start.
That root has no CI and no review, so drift can reappear between steps.

## Open gates and blockers

**HITL Gate: OPEN.** T3's first action is a human `tofu apply`. Two human-only acts remain:

1. **T3's two `bootstrap/` applies** (widen, then narrow) — admin SSO, never CI (BR-D1);
2. **the transfer itself** — a Settings UI action, irreversible in practice.

An agent may prepare files and draft commands for both; it may execute neither.

⚠️ **The narrow must complete in the same working session as the transfer.** Everything works
without it and nothing gates it, so by default it slips — and the reason it matters is that
**GitHub usernames are reclaimable**. Until it lands, a trust policy with a dangling
`repo:Seuss27/bedrock-serverless-rag:*` glob stands against a role holding `iam:CreateRole`
on `*` in the shared account.

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
