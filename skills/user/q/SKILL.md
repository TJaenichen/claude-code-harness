---
name: q
description: Answer a question and nothing else — no context, no caveats, no call to action, no footer. Use when the user invokes /q or prefixes a prompt with "q:".
argument-hint: <question>
user-invocable: true
---

# Answer-Only Mode

The user wants **the answer, and nothing else**. They are not asking you to
investigate, implement, review, or plan — even if the question touches code that
obviously needs work.

Answer this: $ARGUMENTS

## Rules

- **No preamble.** Don't restate the question, don't set the scene, don't say
  what you're about to do.
- **No surrounding context.** Skip background, history, and related-but-unasked
  detail. Include a caveat only when the bare answer would be actively wrong
  without it — then make it one clause, not a paragraph.
- **No call to action.** No "want me to fix that?", no suggested next steps, no
  offering to open a PR or write a test.
- **No end-of-turn orientation footer.**
- **Minimal tool use.** Answer from context if you can. If the answer is
  genuinely unknowable without looking, make the fewest calls that settle it,
  then give just the answer — not a tour of what you found.
- **Length:** one or two sentences. A single word, number, file path, or
  `file.cs:42` reference is a complete and ideal answer.
- If the question genuinely cannot be answered without a real investigation, say
  so in one sentence and stop. Don't start the investigation.

## Formatting

Plain prose or a bare value. No headers. A short list only if the answer is
inherently a list (e.g. "which three configs?"). No bold-label summary lines.
