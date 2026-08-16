<!--
Repo-level CLAUDE.md for a large .NET / SQL Server monorepo (payments platform).
Everything named Contoso.*, MainDb/AccountsDb, *.example.com is a placeholder.
The point of this file is the shape: what the repo is, hard safety rules learned
the hard way (never query prod, STG is the SP source of truth), coding standards,
testing conventions, and the honesty/anti-hallucination rules at the bottom.
-->

# Payments - Payment Processing Platform

## Project Overview

Payments is a payment processing and financial management platform built with .NET 8.0 and Clean Architecture principles. It handles card processing, ACH, cryptocurrency and various other payment methods.

## Wiki

- **Team Wiki**: https://devops.example.com/DefaultCollection/MyProject/_wiki/wikis/Team%20Wiki/Wiki-Home

## Payment Processing/Deposits

Deposits are handled in an engine in the Payment processing project (`\Contoso.Payments.Api\Contoso.Payments.API.PaymentProcessing\Contoso.Payments.API.PaymentProcessing.csproj`)
as part of the Contoso.Payments.API.

## Solutions in This Repository

| Solution | Location | Description |
|----------|----------|-------------|
| **Contoso.Payments.API.sln** | `Contoso.Payments.Api/` | Main RESTful API |
| **Contoso.Payments.sln** | `Contoso.Payments/` | Admin web application (MVC/Razor Pages) |
| **Contoso.Payments.Payment.Api.sln** | `Contoso.Payments.Payment.Api/` | Dedicated payment processing API |
| **Contoso.Payments.Hangfire.sln** | `Contoso.Payments.Hangfire/` | Background job processing |
| **Contoso.Payments.DepositWidget.sln** | `Contoso.Payments.DepositWidget/` | Standalone deposit widget |
| **Contoso.CryptoCashier.sln** | `Contoso.CryptoCashier/` | Cryptocurrency management (.NET 6.0) |
| **Contoso.Crypto.Api.sln** | `Contoso.Crypto.Api/` | Cryptocurrency API (.NET 10.0) |

**Shared Libraries**:
- `Contoso.Payments.Core/` - Core libraries, EntityFramework, Logging, WCFClient
- `Contoso.Payments.EntityFramework.Services/` - EF models for the MainDb and AccountsDb databases
- `LegacyCode/` - WCF services (Legacy1, Legacy2, Legacy3) and Windows services

## Databases

### Primary Databases
- **MainDb** - Customer and payment data (~1,000 tables, ~2,000 stored procedures)
- **AccountsDb** - Agent and account data (~600 tables, ~3,000 stored procedures)

### Connection
All connections use **Windows Integrated Security**:
- **Dev**: `sql-dev.example.com` (shared, may be inconsistent)
- **Staging**: `sql-staging.example.com` (preferred for testing)
- **Prod read mirror**: `sql-prod-mirror.example.com` (read-only replica of prod, for ad-hoc reads + ML training source)

### ⚠ NEVER query prod directly
- **DO NOT** run any query — no matter how small, no matter "just a SELECT TOP 5" — against **`sql-prod.example.com`** (the prod primary).
- A past incident had a ~30-minute query running against prod that caused real operational problems on the live production database. This rule has no exceptions.
- For "ground truth" reads, use `sql-prod-mirror` (the read mirror). It can lag — sometimes hours on individual tables (observed ~5h lag on one table). The correct response to mirror lag is to accept it with a caveat and/or ask the human to run the query, **never** to fall back to prod.
- This rule also applies to automated workloads: do not propose pointing ML training, batch jobs, or anything else at prod. If the mirror keeps choking, the team picks a different non-prod alternative — never prod.

### Key Tables (Payment Processing)
- `Processors`, `CardTypesProcessors`, `ProcessorGroups`
- `Transactions_Card`, `Transactions_ACH`, `Transactions_Crypto`
- `BlockedBins`, `BlockedBinProcessors`
- `ProcessorBusinessRules`, `BusinessRules`

### Stored Procedures — STG is the source of truth
- **Always pull SP definitions from the staging DB** (`sql-staging.example.com`), never from the `StoredProcedures/*.sql` files in the repo. The `.sql` files routinely drift behind STG (DBAs apply hotfixes directly to the database without round-tripping through git), so the repo copy can be missing branches, parameters, or whole code paths.
- This applies to: migrating an SP to C#, auditing an SP, comparing implementations, or reasoning about runtime behavior. If you base work on the repo file, you will silently miss logic.
- Query the live definition with:
  ```sql
  SELECT definition FROM sys.sql_modules
  WHERE object_id = OBJECT_ID('dbo.usp_ExampleProcedure');
  ```
- Use `sqlcmd -S sql-staging.example.com -d MainDb -E -i <script>.sql` (Windows integrated auth).

## Payment Processing Pipeline

The **migrated C# pipeline** (`Contoso.Payments.Api/Contoso.Payments.API.PaymentProcessing/`) is the **source of truth** for deposit routing, processor selection, and business rules. The legacy SQL stored procedures (e.g., `Legacy_ProcessorAutoSelect.sql`) are kept for reference but are not authoritative. When in doubt about routing logic, thresholds, or eligibility rules, refer to the C# pipeline rules in `PaymentProcessing/Rules/`.

## Development Guidelines

### General Practices
1. **Build with warnings suppressed** (`-p:WarningLevel=0`) unless told otherwise
2. **Don't use try-catch** unless you can actually handle the exception
3. **Follow existing patterns** - search before creating new ones
4. **NEVER introduce new patterns/projects** without confirmation
5. **Python is not available** — use PowerShell for scripting tasks

### Architecture Standards
- Follow **Clean Architecture**: Domain -> Application -> Infrastructure -> Presentation
- Follow **SOLID principles** and **DRY**
- All services are .NET 8.0 (except CryptoCashier which is .NET 6.0)

### C# Code Style Conventions

Based on [Microsoft C# Coding Conventions](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/coding-conventions).

#### Layout & Formatting
- Use **4 spaces** for indentation (no tabs)
- Use **Allman style braces**: opening and closing brace each on its own line, aligned with the current indentation level
- **Never** put braces on the same line as code — even for single statements:
  ```csharp
  // GOOD
  if (condition)
  {
      DoSomething();
      return;
  }

  // BAD
  if (condition) { DoSomething(); return; }
  ```
- One statement per line
- One declaration per line
- Add at least one blank line between method definitions and property definitions
- Indent continuation lines one tab stop (4 spaces)
- Use parentheses to make clauses in expressions apparent: `if ((a > b) && (c > d))`

#### Naming ([Microsoft Identifier Naming Rules](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/identifier-names))

**PascalCase** — use for:
- Classes, structs, interfaces, delegates, enums, namespaces
- All public/protected/internal members (methods, properties, fields, events)
- Local functions
- Constants (both fields and local): `const int MaxRetries = 3;`
- Record positional parameters (they become public properties): `public record Person(string FirstName, string LastName);`

**camelCase** — use for:
- Local variables, method parameters
- Primary constructor parameters on `class`/`struct` types (not records)

**Prefixes:**
- Private instance fields: `_camelCase` (underscore + camelCase): `private IWorkerQueue _workerQueue;`
- Private/internal static fields: `s_camelCase`: `private static IWorkerQueue s_workerQueue;`
- Thread-static fields: `t_camelCase`: `[ThreadStatic] private static TimeSpan t_timeSpan;`
- Interfaces: prefix with `I`: `public interface IWorkerQueue`
- Generic type parameters: prefix with `T`: `ISessionChannel<TSession>`, or single `T` if self-explanatory

**Other rules:**
- Attribute types end with `Attribute`
- Enum types: singular noun for non-flags, plural for flags
- Avoid abbreviations/acronyms except widely accepted ones (e.g., `Id`, `Url`, `Html`)
- Avoid single-letter names except simple loop counters (`i`, `j`, `k`)
- No two consecutive underscores (`__`) — reserved for compiler-generated identifiers
- Prefer clarity over brevity

#### Language Usage
- Use language keywords instead of runtime types: `string` not `String`, `int` not `Int32`
- Use `var` only when the type is obvious from the right side of the assignment
- Don't use `var` when the type isn't apparent from the expression (e.g., method return values)
- Use implicit typing (`var`) in `for` loops
- Use **explicit typing** in `foreach` loops
- Use `var` for LINQ query results
- Use string interpolation `$"..."` instead of `string.Format` or concatenation
- Use `StringBuilder` for string appending in loops
- Use `&&`/`||` (short-circuit) instead of `&`/`|` for boolean logic
- Use collection expressions: `string[] items = [ "a", "b", "c" ];`
- Use `Func<>` and `Action<>` instead of custom delegate types
- Use file-scoped namespace declarations: `namespace MyNamespace;`
- Place `using` directives **outside** namespace declarations

#### Object Creation
- Use target-typed `new()` or `var` with explicit constructor:
  ```csharp
  var example = new ExampleClass();
  ExampleClass example = new();
  ```
- Use object initializers when setting multiple properties

#### Exception Handling
- Only catch exceptions that can be properly handled; avoid catching `System.Exception` without a filter
- Use specific exception types for meaningful error messages
- Prefer `using` statements/declarations over `try-finally` for `IDisposable`
- Prefer `using` declaration (no braces): `using var conn = new SqlConnection(connStr);`

#### Async
- Use `async`/`await` for I/O-bound operations
- Be cautious of deadlocks; use `ConfigureAwait` when appropriate

#### Comments
- Use single-line comments (`//`) — avoid multi-line `/* */`
- Place comments on a separate line, not at end of code
- Begin comment text with uppercase, end with a period
- Use XML doc comments (`///`) for public members
- One space after `//`: `// This is a comment.`

#### LINQ
- Use meaningful names for query variables
- Use `where` clauses before other query clauses to filter early
- Align query clauses under the `from` clause

### Testing
- **Every test must provide real value** - no tests written purely for coverage. Each test should validate meaningful behavior, a real scenario, or a specific edge case. If a test doesn't catch a real bug or verify an important contract, don't write it.
- Unit tests: Use `Assert.Fail()`, never `Assert.Ignore()` or `Assert.Inconclusive()`
- Integration tests can be slow (5-10 min per category) - run specific categories only
- **Test runner: NUnit** for all projects (team standard).

#### Integration Testing Conventions
Follow the ASP.NET Core integration-testing guidance (https://learn.microsoft.com/aspnet/core/test/integration-tests). Applies to all web-API test work.

- **Separate unit and integration tests into distinct projects.** `*.UnitTests` = host-less, fast, isolated (construct the class under test directly with mocks; reference only the layer under test — no web host, no `Mvc.Testing`). `*.IntegrationTests` = `WebApplicationFactory`-based, real infra, `[Category("Integration")]`. Within a project, keep reusable harness under `Framework/` and tests under `Tests/`.
- **Default to endpoint-level E2E**, not repository-only tests. Drive the real HTTP endpoint through the full stack (routing → controller → MediatR → handler → repository/EF → DB) so the test exercises the components the way production does. Test the repository directly only when no endpoint reaches the path safely.
- **Use `WebApplicationFactory<Program>`** via the reusable `CustomWebApplicationFactory<TProgram>` (override `ConfigureWebHost`). Fixtures inherit `IntegrationTestBase`; do not re-create host plumbing per test.
- **Configuration comes from `appsettings.Testing.json`** copied to the test output - never hardcode connection strings or settings in test code. Point it at **staging** (never production). This lets the same tests target different components/environments by config.
- **Resolve services from the app's DI** (`Factory.Services.CreateScope()`), so tests use the same wiring/config as the app. Override per-test dependencies with `WithWebHostBuilder` + `ConfigureTestServices`.
- **Mark DB/network-touching tests `[Category("Integration")]`** so CI can run them selectively; pure in-process pipeline tests stay uncategorized.
- **Authenticated endpoints**: use the reusable `TestAuthHandler` scheme via `ConfigureTestServices` rather than minting real tokens.
- **Integration tests must be safe and repeatable**: read-only or self-cleaning, no destructive side effects against staging. If a path can't be driven safely (e.g. it writes or calls external nodes), cover its pipeline with a mocked in-process test and document why.
- Reusable test infrastructure (`CustomWebApplicationFactory`, `IntegrationTestBase`, `TestAuthHandler`) should be promoted to a shared test library once a second test project needs it.

## Git Workflow

- **Main branch**: `main`
- **Repository**: `https://devops.example.com/DefaultCollection/MyProject/_git/Payments`
- Check `git status` before making changes
- Follow standard git workflow for commits and pull requests

## Honest Assessment

Always give your HONEST ASSESSMENT. Do not present solutions in a better light than your honest opinion. The user needs accurate information to make decisions, even if it's not what they want to hear.

## Anti-Hallucination Rules

1. **Never reshape evidence to fit earlier assumptions** - If data contradicts your hypothesis, the hypothesis is wrong, not the data.
2. **Update the model explicitly when contradicted** - State clearly what changed and why the previous understanding was incorrect.
3. **Avoid vague guesses; use "Unclear; need to inspect X"** - When uncertain, name the specific file, table, or SP that must be checked rather than speculating.
4. **Cross-reference constantly to maintain global coherence** - Verify claims against actual code, DB state, and logs. Do not let one finding drift from the rest of the analysis.
