---
name: dd-errors
description: Query Datadog logs for recent errors, error rates, or specific exceptions.
argument-hint: "<service> <timerange> [search terms]"
allowed-tools: Bash(curl:*)
---

# Query Datadog Errors

Arguments: $ARGUMENTS

## Argument parsing

Parse the arguments flexibly. They can appear in any order:

| Argument | Detection | Default |
|----------|-----------|---------|
| **Service** | Matches a known service alias (see table below) | `api` |
| **Time range** | Matches pattern like `1h`, `30m`, `24h`, `7d` | `1h` |
| **Search terms** | Anything else — added to the Datadog query as-is | *(none)* |

### Service aliases

| Alias | Datadog service name |
|-------|---------------------|
| `api` | `Contoso.Payments.API` |
| `web` | `Contoso.Web.Presentation` |
| `deposit` | `Contoso.Deposit.API` |

Adjust this table to your own service names; the alias is just a short handle for the prompt.

If no arguments are provided, default to: API errors in the last 1 hour.

### Examples

- `/dd-errors` → API errors, last 1h
- `/dd-errors deposit 24h` → Contoso.Deposit.API errors, last 24h
- `/dd-errors api 4h OperationCanceledException` → API errors matching that exception, last 4h
- `/dd-errors 30m NullReferenceException` → API errors (default) with that search term, last 30m
- `/dd-errors deposit 7d GetCustomerAccountInfo` → Contoso.Deposit.API, last 7 days, matching that method

## API call

Build and execute a POST request to the Datadog EU Logs Search API.

**Endpoint**: `https://api.datadoghq.eu/api/v2/logs/events/search`

**Authentication** (via environment variables — use `printenv` not direct expansion):
```
DD-API-KEY: $(printenv DD_API_KEY)
DD-APPLICATION-KEY: $(printenv DD_APP_KEY)
```

**Required flags**: `-s -k` (silent + skip SSL verification for corporate proxy)

**Request body**:
```json
{
  "filter": {
    "query": "<build query below>",
    "from": "now-<timerange>",
    "to": "now"
  },
  "sort": "-timestamp",
  "page": {"limit": 25}
}
```

### Building the query

Always include:
- `service:<datadog service name>`
- `@Properties.EnvironmentName:Production`
- `-status:(info OR warn)` (excludes info and warn — shows errors only)

If search terms were provided, append them to the query string.

**Example query**: `-status:(info OR warn) @Properties.EnvironmentName:Production service:Contoso.Payments.API OperationCanceledException`

### Important: use a temp file for the JSON body

To avoid shell escaping issues, write the JSON body to a temp file and use `-d @file`:
```bash
# Write JSON to temp file, then curl with -d @file
```

## Output formatting

Parse the JSON response and present a clean summary:

1. **Header**: Service name, time range, total matches found
2. **Error table** (for each log entry):
   - Timestamp (converted to local-friendly format)
   - Status/level
   - Message (first 120 chars, trimmed)
   - Host (if available)
3. If no results: report "No errors found" clearly
4. If the response contains a `page.after` cursor, mention there are more results available

### Error handling

- If `DD_API_KEY` or `DD_APP_KEY` are not set, report clearly: "Datadog API keys not configured. Set DD_API_KEY and DD_APP_KEY environment variables."
- If the API returns an error, show the error message
- If curl fails (network issue), report the connection error
