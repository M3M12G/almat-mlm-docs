# Storage notes

**Канон схемы — EF-сущности** в `almat-mlm-api` (ADR-0005), не этот каталог.

| Где | Роль |
|---|---|
| `Mlm.Api/Data/AppDbContext.cs` + `Modules/*/Entities/` | Code-first модель |
| `Mlm.Api/Data/Migrations/` | `dotnet ef migrations add --context AppDbContext` |
| `Mlm.Api/Data/QuartzDbContext.cs` + `QuartzMigrations/` | JobStore; vendor SQL в миграции |
| `Mlm.Api/Data/Scripts/0002_quartz_postgres.sql` | Официальный Quartz.NET Postgres DDL |
| `Mlm.Api/Data/DbMigrator.cs` | Накат при старте API |
| `Mlm.Api/Data/SeedDbContext.cs` | Seed `packages` / `ranks` (insert if missing) |
| `queries_recursive.sql` | Справочник CTE, не DDL |

Дамп при нужде (из `Mlm.Api/`):

```bash
dotnet ef migrations script --idempotent --context AppDbContext
```
