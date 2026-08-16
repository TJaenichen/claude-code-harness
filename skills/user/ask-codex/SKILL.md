---
name: ask-codex
description: Consult OpenAI's Codex (ChatGPT) for a second opinion during planning, architecture decisions, code review, or any situation where a diverse AI perspective adds value. Runs `codex exec` and returns Codex's response for critical evaluation.
---

# Ask Codex

Consult OpenAI's Codex (ChatGPT) for its perspective on a topic.

## Usage

Use this skill when you need Codex's opinion during planning, architecture decisions, code review, or any situation where a diverse AI perspective adds value.

## Instructions

1. Formulate a clear, specific prompt that includes relevant context
2. Run the command below with your prompt
3. Parse and critically evaluate Codex's response
4. Incorporate useful insights into your reasoning

## Command

```bash
codex exec --skip-git-repo-check "<your prompt here>"
```

## Guidelines

- Always include sufficient context in the prompt (project details, constraints, what's already been decided)
- Frame questions to get actionable, specific answers rather than generic advice
- When Codex's response conflicts with your own analysis, flag the disagreement for council discussion
- Do NOT blindly accept Codex's output — treat it as one voice in the council
- For multi-part questions, break them into separate calls for clearer responses
- Keep prompts under 4000 characters for best results
- Timeout: allow up to 60 seconds for a response
