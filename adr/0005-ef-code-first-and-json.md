# ADR-0005: EF Core code-first, два контекста, System.Text.Json

## Контекст

Пилот ещё не задеплоен. Черновик DDL жил в `db/schema.sql` и попадал в миграции
через `migrationBuilder.Sql(...)` (schema-first). Так схема расходится с
сущностями, а `dotnet ef migrations add` перестаёт быть источником правды.
Quartz.NET JobStore — чужой DDL (`qrtz_*`), CLR-сущностей у вендора нет.
Запросы бонусов/сети пока пишутся в EF; сырой SQL — только когда EF не тянет
(CTE, горячие пути). JSON — только BCL (`System.Text.Json`).

## Решение

1. **Code-first.** Источник схемы — сущности + `IEntityTypeConfiguration<T>`.
   Генерация миграций **только** `dotnet ef migrations add`. Ручной DDL в Up()
   для домена запрещён. Накат — `DbMigrator` при старте API (`MigrateAsync`
   обоих контекстов); `dotnet ef database update` — запасной CLI без seed.
2. **Два контекста, одна Postgres:**
   - `AppDbContext` — домен + Data Protection keys.
     История: `__ef_migrations_history`.
   - `QuartzDbContext` — без сущностей. Единственное исключение: в миграции
     выполняется официальный скрипт Quartz (`Data/Scripts/0002_quartz_postgres.sql`).
     История: `__ef_migrations_history_quartz`.
   Контексты не шарят `__EFMigrationsHistory`. Connection string Quartz =
   `ConnectionStrings:Quartz` или fallback на `Default`.
3. **Запросы.** Сложные выборки держим в LINQ/EF (`FromSqlInterpolated` для
   CTE). Вынос в `.sql` — только после профилирования конкретной боли.
   `docs/db/queries_recursive.sql` — справочник CTE, не схема.
4. **JSON:** `System.Text.Json` (+ `JsonStringEnumConverter`). Newtonsoft.Json
   не ставить (и не возвращать).

## Альтернативы

| Вариант | Почему нет |
|---|---|
| Schema-first (`schema.sql` → Sql() в миграции) | Двойной источник правды, drift |
| Один DbContext на домен + `qrtz_*` | Snapshot EF не знает JobStore; путаница истории миграций |
| CLR-сущности под каждую `qrtz_*` | Нет официальной модели; ломается при апгрейде Quartz |
| Newtonsoft.Json | Лишняя зависимость; STJ в BCL |

## Последствия

- ✅ `dotnet ef migrations add Foo --context AppDbContext` — единственный путь
  менять доменную схему; накат — старт API (`DbMigrator` + `SeedDbContext`)
- ✅ Апгрейд Quartz: заменить vendor SQL + новая миграция `QuartzDbContext`
- ✅ Локальный reset (пока нет прода): `dotnet ef database drop --force
  --context AppDbContext`, затем `dotnet run`
- ⚠️ `db/schema.sql` больше не канон; дамп при нужде —
  `dotnet ef migrations script --idempotent --context AppDbContext`
- 📄 Стек: `docs/01_stack.md`, `docs/TECH_SPEC.md` §5, `AGENTS.md`
