---
name: optimize-prompt
description: Rewrite vague prompts into clear, actionable instructions for Claude Code.
argument-hint: <your prompt text>
---

# Optimize Prompt for Claude Code / AI

Input prompt: $ARGUMENTS

## Your Task

Take the user's raw prompt and rewrite it into an optimized version that will get significantly better results from Claude Code and AI assistants in general. Output ONLY the optimized prompt — no explanations, no preamble, no "here's your optimized prompt" wrapper.

## Optimization Principles

Apply ALL of the following transformations where relevant:

### 1. Clarity & Specificity
- Replace vague language with precise instructions
- "Make it better" → specify WHAT to improve and HOW to measure success
- "Fix the bug" → specify the symptom, expected behavior, and where to look
- Eliminate ambiguity — if a phrase could mean two things, pick the right one or split into two instructions

### 2. Structure
- Break complex requests into numbered steps
- Group related instructions together
- Use headers/sections for multi-part requests
- Lead with the goal, then provide context, then constraints

### 3. Context & Scope
- Add relevant technical context the AI needs (language, framework, patterns)
- Define boundaries — what's in scope and what's NOT
- Specify which files, directories, or components are involved
- Reference existing patterns to follow ("follow the same pattern as X")

### 4. Output Format
- Specify what the output should look like (code, explanation, list, diff)
- Define any constraints on the response (concise, detailed, with examples)
- If code: specify language, style, error handling expectations

### 5. Constraints & Guardrails
- State what NOT to do (equally important as what to do)
- Mention backward compatibility requirements
- Specify testing expectations
- Note any dependencies or prerequisites

### 6. AI-Specific Optimizations
- Use imperative verbs: "Create", "Implement", "Find", "Fix", "Add"
- Front-load the most important instruction (AI attention is strongest at the start)
- For Claude Code specifically:
  - Reference file paths when known
  - Mention which solution/project when the repo has multiple
  - Specify if you want a plan first vs immediate implementation
  - Indicate if you want changes committed or just made

### 7. Examples (when helpful)
- Include input/output examples for transformations
- Show the expected behavior for edge cases
- Reference similar existing code as a model

## Rules

1. **Preserve intent** — never change what the user is asking for, only HOW they ask
2. **Don't over-engineer** — if the original prompt is already clear and specific, make minimal changes
3. **Don't add requirements** — only make implicit requirements explicit; never invent new ones
4. **Keep it natural** — the result should read like something a skilled developer would type, not a formal specification document
5. **Be concise** — an optimized prompt should be as short as possible while being unambiguous. Don't pad with unnecessary words.
6. **Output only the prompt** — no meta-commentary, no "Here's the optimized version:", just the prompt text itself
