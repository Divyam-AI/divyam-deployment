---
name: agent-operating-loops
description: >-
  The shared operating loops for long-running operations — (A) monitor the authoritative signal
  granularly + self-heal only safe idempotent retries; (B) on an unresolved failure, a background,
  double-gated failure→bug loop (search the owning repo first so we never re-diagnose, else a write-gated
  bug); (C) a background, double-gated self-learning loop that distills durable lessons into a skill PR.
  Load when running or supervising a stack install/upgrade / deploy / IaC apply, or when something fails
  or a durable lesson is learned.
allowed-tools: Read, Grep, Glob, Bash
---

# Agent operating loops

> **Canonical source of truth:** `divyam-sandbox/.claude/skills/agent-operating-loops/SKILL.md`. This is
> a mirror so the `divyam-deployment` agents (which can't load a sibling-repo skill) carry the same
> loops. **Keep in sync** — edit the canonical first, then reflect material changes here.

The common discipline for **long-running operations** and what happens **when they fail or teach us
something**. Reuses the GitHub write-gate + 📦 footer + hidden-marker idempotency conventions.

## A. Long-running ops — monitor granularly, self-heal only what's safe
- Monitor the **authoritative signal** at a **granular interval (~20–30s)** for the whole op — for a
  Helmfile install/upgrade: `make k8s -- status` (`helm ls -A`) + `kubectl get pods -A | grep -vE
  'Running|Completed'`; for IaC: the `make status` step ledger (`--porcelain`). A release can **hang up
  to the 1200s atomic timeout, then roll back and abort every release after it** — catch the stuck
  release early; the **first** failing release is the real one. **Never** `-w/--watch`/`--tui`/
  `--dashboard` from a tool shell (offer to the user for their terminal).
- **Self-heal only safe idempotent retries** — re-running `make k8s -- install/upgrade` is safe
  (already-deployed releases no-op; transient pull/timeout often clears). Anything else → surface +
  approval-gate. **Never auto-remediate**; never hand-`kubectl apply/delete` (helmfile owns manifests).

> ## Housekeeping = background + double-gated (the user controls token spend)
> Loops **B** and **C** are token-spendy housekeeping. Run them as **background tasks** (never block
> foreground work) and gate **twice**: (1) **ask before starting** ("file a bug / capture this lesson? —
> runs in background, costs tokens"); (2) the **GitHub write-gate** (show exact text + approve) before
> posting/opening. Never kick off background housekeeping un-asked.

## B. Failure → bug loop (background; ask-before-run, then write-gate)
When a deploy/IaC op fails and can't be safely self-healed, **ask** whether to file a bug; on yes, run
**in the background**:
1. **Summarize**: the **first** failing release/layer + root-cause **signature** (match against
   `divyam-tooling/references/debugging.md` + `known-gotchas.md`) + a *bounded* log excerpt + what was
   tried.
2. **Search the owning repo first** — `gh issue list --repo Divyam-AI/divyam-deployment --state open
   --label box-autofiled --search "<signature>"`, matched on a hidden `<!-- box-bug:<signature-hash> -->`
   marker. **Match → reference it and STOP re-diagnosing**; read its **Workaround/Fix** section and
   **apply a recorded one** (idempotent inline; risky approval-gated) instead of re-solving.
3. **Else draft a bug** routed to the owning repo (helm/deploy/IaC → `divyam-deployment`; a service image
   build → its source repo). **Issue type = Bug** (`gh issue create --type Bug`, not just a label).
   Title `[<area>] <signature>`; body = when • env • failing release • signature • bounded log •
   self-heal attempted • **Workaround/Fix** (REQUIRED: the workaround that worked, and/or how you fixed
   it — commands/diff — so the next agent applies it directly; else "none found yet") • next step •
   hidden marker; label `box-autofiled`; footer `📦 via Box · divyam-sre`.
4. **Post only through the write-gate** — show exact type + title + body + target repo, get approval,
   offer to edit. If you later find a workaround/fix for an open bug, update its Workaround/Fix section
   (write-gated) so knowledge compounds.

## C. Self-learning loop (background; ask-before-run, then PR write-gate)
When a **durable, higher-dimension, decision-shaping** fact is learned (still true in ~3 months; not a
fix-of-the-week — that's a bug), **ask** whether to capture it; on yes, in the background: pick the
target (`divyam-tooling` / `divyam-deploy` / a persona, or `references/debugging.md` for a new
signature), **propose the exact edit**, and on approval **raise a gated PR** (`learn/<slug>`).

---
**Reads are free; writes (GitHub posts, PRs) and token-spendy background work are gated. When in doubt, ask.**
