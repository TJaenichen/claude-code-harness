---
name: council
description: Convene the AI council (Claude + Gemini + Codex) for collaborative deliberation on significant decisions. Use for trade-off analysis, architecture choices, or any high-stakes decision where multiple expert perspectives reduce risk. Skip for trivial decisions.
---

# Council — AI Brain Trust

Convene the AI council (Claude + Gemini + Codex) for collaborative deliberation on important decisions.

## Usage

Use this skill for significant decisions: trade-off analysis, and any decision where multiple expert perspectives reduce risk.

## Process

### 1. Frame the Question
Write a clear problem statement with:
- Context 
- The specific decision or question
- Constraints and requirements
- Any options already under consideration

### 2. Gather Perspectives
Call Gemini and Codex **in parallel** with the same framed question. Include:
- "You are one of three AI advisors."
- "Provide your honest, specific recommendation with reasoning."
- "Flag any risks or concerns the team should consider."
- The full context from step 1

### 3. Synthesize & Deliberate
Compare all three perspectives (yours included):
- **Agreement zones**: Where all three align — these are high-confidence decisions
- **Disagreement zones**: Where opinions diverge — these need deeper analysis
- **Unique insights**: Novel points raised by only one advisor

### 4. Resolve Disagreements
If there's a significant disagreement:
- Identify the root cause (different assumptions? different priorities?)
- If needed, do a second round: share the disagreement with the other AIs and ask them to respond to the opposing view
- Maximum 2 rounds of deliberation to avoid circular debate

### 5. Decide & Document
Claude makes the final call. Document in the council log:
- The question posed
- Each AI's position (summarized)
- The final decision and rationale
- Any dissenting opinions worth noting for future reference

## Rules

- Claude leads the council and makes all final decisions
- Every council member's input is treated with equal initial weight
- Decisions are based on technical merit, not consensus for its own sake
- If two AIs agree and one dissents with weak reasoning, go with the majority
- If one AI raises a critical risk the others missed, that can override majority
- Council decisions are logged in `docs/council-log.md` for traceability
- Don't convene the council for trivial decisions — use judgment
