# Claude Fable 5 — model note & prompting principles

A working reference for driving this project's autonomous crew/goal runs with Anthropic's
current frontier model, **Claude Fable 5**. Written 2026-07-11 from the official launch and
prompting docs (linked below). Scope: what the model *is*, and how to instruct it *well* — the
second half is the part that changes how we write our mission briefs and skills.

> **Naming, to end a running confusion in this repo:** **Fable 5** is a *model*
> (`claude-fable-5`). **`fable-v1`** is separately a *run name* in this project — the
> Opus-authored fable-form manuscript draft (`manuscript/chapters/fable-v1-*`). They share a
> word and nothing else. Don't conflate them.

---

## 1. What Claude Fable 5 is

- **Tier.** A **Mythos-class** model — a new tier *above* Opus — released **June 9, 2026**.
  `claude-mythos-5` is the same underlying model without the public safety classifiers
  (limited release, Project Glasswing); `claude-fable-5` is the generally-available, safeguarded
  sibling. Anthropic's **most capable widely released model**, built for demanding reasoning and
  **long-horizon agentic work**.
- **API model ID:** `claude-fable-5`.
- **Context:** **1M-token** window by default; **up to 128k output tokens** per request.
- **Pricing:** **$10 / M input**, **$50 / M output** (90% prompt-cache input discount);
  ~2× Opus 4.8.
- **Thinking:** **Adaptive thinking is always on** — there is no "disabled" thinking mode.
  Depth is controlled by the **`effort`** parameter, not a token budget. **Raw chain-of-thought
  is never returned** (`thinking.display` yields a *summary* or an *empty* block).
- **Safeguards & fallback.** Classifiers can decline requests (`stop_reason: "refusal"`, an
  HTTP 200) in offensive-cybersecurity, biology/life-sciences, and reasoning-extraction domains;
  declined requests **fall back to Claude Opus 4.8**. Benign work occasionally trips them
  (<5% of sessions). Irrelevant to this project's literary work, but see the `reasoning_extraction`
  note in §2.
- **History note.** Pulled offline June 12 under a US export-control directive; controls lifted,
  **restored globally July 1, 2026** on the Claude API, claude.ai, Claude Code, and Cowork.
- **In Claude Code:** select it with `/model` (choose Claude Fable 5). Set **effort `high`** as
  the working default, **`xhigh`** for the hardest, most capability-sensitive passes.

## 2. Prompting principles (what actually changes how we write instructions)

The through-line of Anthropic's Fable-5 guidance: **smarter models need less prescriptive
scaffolding.** Enumerating every step and rule — the way we wrote prompts for earlier models —
now *degrades* output. Instruct the goal and the boundaries; trust the model to find the path.

1. **Goals and boundaries, not procedure.** *"You can steer most behaviors with a brief
   instruction rather than enumerating each behavior by name."* State the objective, the
   constraints, and what "done" means — then get out of the way. Do **not** script a 12-step
   execution flow; the model plans its own and does it better than the script would.
2. **Aim high.** *"Start at the top of your difficulty range."* Fable 5 is undersold on easy
   tasks. Hand it the hard, ambiguous, end-to-end problem and let it scope, ask, and execute.
3. **Trust instruction-following; keep the boundaries explicit.** Brevity, checkpoint, and
   scope behaviors each yield to a *single* short instruction. But **do** still state hard
   constraints plainly — what it must not touch, what irreversible actions require a human. A
   boundary is not scaffolding; it's a fact the model needs.
4. **Longer turns by default.** Individual requests can run many minutes; autonomous runs, hours
   to days. Structure harnesses to **check asynchronously**, not block. Tell an ambiguous task:
   *"When you have enough information to act, act."*
5. **Ground progress in evidence.** On long runs, instruct: *"Before reporting progress, audit
   each claim against a tool result from this session… if tests fail, say so with the output."*
   This nearly eliminates fabricated status.
6. **For autonomous / goal runs, say so.** *"You are operating autonomously. The user is not
   watching… for reversible actions that follow from the original request, proceed without
   asking."* And guard the tail: *"Before ending your turn, if your last paragraph is a plan, a
   question, or a promise ('I'll…'), do that work now with tool calls."*
7. **Reassure on context.** In very long sessions Fable 5 may offer to summarize/hand off if it
   sees a token countdown. *"You have ample context remaining. Do not stop… Continue the work."*
   Avoid surfacing remaining-token counts to it where possible.
8. **Give the reason, not only the request.** *"I'm working on [larger task] for [who]; they
   need [what the output enables]. With that in mind: [request]."* Intent lets it connect the
   task to the right context.
9. **Subagents, freely.** Fable 5 dispatches and sustains parallel subagents reliably; fresh-context
   **verifier subagents beat self-critique**. Delegate high-volume side work; keep the main
   context lean.
10. **Memory across runs.** It performs well with a place to record lessons — one lesson per
    file, a one-line summary on top, update-don't-duplicate. (This project already has that
    discipline in `.claude` memory and `reports/missions/` logs.)
11. **Readable final summaries.** After long unwatched work, the closing message is the reader's
    *first* look: outcome first, plain sentences, no arrow-chains or invented shorthand.
12. **Refactor old prompts — and one Fable-specific trap.** *"Skills developed for prior models
    are often too prescriptive for Claude Fable 5 and can degrade output quality. Review and
    consider removing older instructions."* **Do not instruct the model to echo/transcribe/explain
    its internal reasoning** — that can trigger the `reasoning_extraction` refusal and elevate
    fallbacks to Opus. If you need reasoning visibility, read the structured `thinking` blocks
    instead. (Audit our hooks/agents/skills for "show your reasoning" phrasing when we enable.)

## 3. What this means for The Uninsurable

- **Mission briefs (`reports/missions/*-brief-*`) state goals + principles + boundaries, not a
  step-by-step how-to.** The `crew-deep-review` brief was rewritten on 2026-07-11 to this form:
  objectives and invariants kept (D-072 silence, frozen paths, branch discipline, deliverables);
  the 12-dimension checklist and per-command verify script demoted to a coverage map the model
  works at its own discretion. This note is why.
- **The crew itself is a scaffold — re-examine it against Fable 5.** Rules and agent prompts
  authored for weaker models may now be *too prescriptive*. The deep-review mission is the place
  to prune what the model no longer needs and to scrub any "reproduce your reasoning" phrasing
  (the `reasoning_extraction` trap in §2.12).
- **Guardrails stay.** Trusting capability is not loosening the boundaries: `reference/**` and
  the live `.claude/` stay frozen; the finished manuscript stays silent (0/38); locked canon
  still defers upward. State them once, plainly; the model will hold them.

---

*Sources:* [Introducing Claude Fable 5 and Mythos 5](https://platform.claude.com/docs/en/about-claude/models/introducing-claude-fable-5-and-claude-mythos-5)
· [Prompting Claude Fable 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5)
· [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)
· [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
· [Claude Fable 5 & Mythos 5 (news)](https://www.anthropic.com/news/claude-fable-5-mythos-5)
· [Redeploying Fable 5](https://www.anthropic.com/news/redeploying-fable-5)
