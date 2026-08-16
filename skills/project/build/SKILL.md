---
name: build
description: Build the solutions with warnings suppressed. Use when you need to compile the project to check for errors.
argument-hint: [api|web|hangfire|payment|widget|crypto|all]
allowed-tools: Bash(dotnet:*)
---

# Build Solution

Target: $ARGUMENTS (defaults to `api` if not specified)

## Solutions

| Target | Solution | Path |
|--------|----------|------|
| `api` | Contoso.Payments.API.sln | `Contoso.Payments.Api/Contoso.Payments.API.sln` |
| `web` | Contoso.Payments.sln | `Contoso.Payments/Contoso.Payments.sln` |
| `hangfire` | Contoso.Payments.Hangfire.sln | `Contoso.Payments.Hangfire/Contoso.Payments.Hangfire.sln` |
| `payment` | Contoso.Payments.Payment.Api.sln | `Contoso.Payments.Payment.Api/Contoso.Payments.Payment.Api.sln` |
| `widget` | Contoso.Payments.DepositWidget.sln | `Contoso.Payments.DepositWidget/Contoso.Payments.DepositWidget.sln` |
| `crypto` | Contoso.CryptoCashier.sln | `Contoso.CryptoCashier/Contoso.CryptoCashier.sln` |
| `all` | All of the above | - |

## Build command

```bash
dotnet build {solution-path} -p:WarningLevel=0
```

## Your task

1. Determine which solution(s) to build based on arguments
2. If no argument or empty, default to `api`
3. If `all`, build each solution sequentially
4. Run the build command(s)
5. Report success or failures

## Important

- Do NOT run the application after building
- If build fails, report the errors clearly
