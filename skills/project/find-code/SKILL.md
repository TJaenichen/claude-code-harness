---
name: find-code
description: Find controllers, services, models, and views by feature name in the Payments projects.
argument-hint: <feature-name> [api|web]
---

# Find Code by Feature

Feature: $ARGUMENTS

## Your task

Search for code related to the feature in the appropriate project.

## API project locations (`Contoso.Payments.Api/`)

| Component | Pattern | Example |
|-----------|---------|---------|
| Controller | `Contoso.Payments.API/Controllers/{Feature}Controller.cs` | `BonusesController.cs` |
| Service Interface | `Contoso.Payments.API.Application/Interfaces/I{Feature}Service.cs` | `IBonusService.cs` |
| Service Implementation | `Contoso.Payments.API.Infrastructure/Services/` | Search for `{Feature}Service.cs` |
| Domain Models | `Contoso.Payments.API.Domain/Models/{Feature}/` | `Models/Bonus/` |
| EF Models | `Contoso.Payments.API.EFModels/` | Search for `{Feature}*.cs` |
| CQRS Commands/Queries | `Contoso.Payments.API.Application/` | Search for `{Feature}Command.cs`, `{Feature}Query.cs` |

## Web admin project locations (`Contoso.Payments/`)

| Component | Pattern | Example |
|-----------|---------|---------|
| Controller | `Contoso.Payments.Web/Controllers/{Feature}Controller.cs` | `ProcessorsController.cs` |
| Views | `Contoso.Payments.Web/Views/{Feature}/` | `Views/Processors/` |
| Services | `Contoso.Payments.Application/Services/` | Search for `{Feature}Service.cs` |

## Search strategy

1. **Glob for exact matches**:
   ```
   **/Controllers/*{Feature}*.cs
   **/Services/*{Feature}*.cs
   **/Models/*{Feature}*/**
   ```

2. **Grep for references**:
   ```bash
   rg -l -i "{feature}" --type cs
   ```

## Output

Report found files organized by component type (Controller, Service, Model, etc.)
