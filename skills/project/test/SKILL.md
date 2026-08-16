---
name: test
description: Run unit tests or specific integration test categories. Use after making code changes to verify correctness.
argument-hint: "<unit|integration> [category] [api|web]"
allowed-tools: Bash(dotnet:*)
---

# Run Tests

Arguments: $ARGUMENTS

## Test projects

| Project | Type | Path |
|---------|------|------|
| API Unit Tests | Unit | `Contoso.Payments.Api/Contoso.Payments.API.UnitTests/` |
| API Integration Tests | Integration | `Contoso.Payments.Api/Contoso.Payments.API.IntegrationTests/` |
| Web Unit Tests | Unit | `Contoso.Payments/Contoso.Payments.UnitTests/` |
| Web Integration Tests | Integration | `Contoso.Payments/Contoso.Payments.IntegrationTests/` |

## Commands

**Unit tests** (quick, safe to run all):
```bash
dotnet test {test-project-path} -p:WarningLevel=0
```

**Integration tests** (run specific category only!):
```bash
dotnet test {test-project-path} --filter "FullyQualifiedName~{CategoryName}" -p:WarningLevel=0
```

## Integration test categories (API)

List your test fixture classes here, grouped by theme, so the model can pick a category by name instead of running everything. Example shape:

**Core**: `CoreFunctionalityTests`, `SystemValidationTests`
**Business Rules**: `DuplicateTransactionTests`, `VelocityLimitTests`, `GeographicRestrictionTests`
**Routing**: `ProcessorSelectionTests`, `ProcessorCoverageTests`
**Card/Security**: `CardTypeDetectionTests`, `PrepaidCardTests`, `BinRulesTests`
**Errors**: `ErrorCodeValidationTests`

## Your task

1. Parse arguments to determine test type and scope
2. Default to `unit api` if no arguments
3. Run the appropriate test command
4. Set timeout to 600000ms for integration tests

## CRITICAL WARNING

**NEVER run all integration tests** - this takes over 1 hour!
Always specify a category for integration tests.

## Testing guidelines

- Use `Assert.Fail()`, never `Assert.Ignore()` or `Assert.Inconclusive()`
- Integration tests may take 5-10 minutes per category
