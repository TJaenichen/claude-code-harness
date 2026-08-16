---
name: mm-notify
description: Send a notification message to the user's Mattermost DM. Use when you need to notify the user via Mattermost (e.g., task completion, alerts, stats).
argument-hint: <message>
---

# Mattermost DM Notification

Message to send: $ARGUMENTS

## Your task

Send the provided message to the user's Mattermost self-DM channel.

## Configuration

Read all three from environment variables — never hardcode them in this file:

| Variable | Meaning |
|----------|---------|
| `MM_URL` | Mattermost base URL, e.g. `https://mattermost.example.com` |
| `MM_TOKEN` | Personal access token (Bearer) |
| `MM_CHANNEL_ID` | Channel ID of the user's self-DM (open your DM with yourself and copy the ID from the URL or via the API) |

If any of them is unset, stop and report which one is missing.

## How to send

Use curl to POST to the Mattermost API. Read the variables with `printenv` (not direct shell expansion) so the token never appears in the transcript:

```bash
curl -s -X POST \
  -H "Authorization: Bearer $(printenv MM_TOKEN)" \
  -H "Content-Type: application/json" \
  -d "{\"channel_id\": \"$(printenv MM_CHANNEL_ID)\", \"message\": \"MESSAGE_HERE\"}" \
  "$(printenv MM_URL)/api/v4/posts"
```

For messages with quotes or newlines, write the JSON body to a temp file and use `-d @file` to avoid escaping issues.

## Formatting

- Use Mattermost-flavored markdown in the message
- Use `####` for headers
- Use markdown tables for tabular data
- Use `:emoji:` for emoji (e.g., `:white_check_mark:`, `:warning:`, `:bar_chart:`)

## Output

Report whether the message was sent successfully. Show the HTTP status code if there's an error.
