# Технологический стек

Принцип: **KISS + YAGNI** + **OSS на долгий срок** (ADR-0004).  
Не ставить библиотеку, пока боль не появилась. Не ставить commercial NuGet «по привычке».

## Backend (.NET 10)

| Нужно | Берём | Не берём на старте |
|---|---|---|
| Web API | ASP.NET Core | Blazor UI |
| Данные | EF Core code-first + Npgsql; CTE через `FromSqlInterpolated` | schema-first SQL, Dapper «на всякий» |
| Структура | Controllers + services + DbContext | MediatR, Clean Architecture шаблоны |
| DTO map | **Mapster** (MIT) | AutoMapper |
| Jobs | **Quartz.NET** (Apache-2.0) + Postgres JobStore | Hangfire, MassTransit, Kafka, TickerQ |
| Auth | JWT bearer + httpOnly cookie; refresh-сессия в Postgres (ротация) | Identity UI / OpenIddict / auth SaaS |
| Errors | ProblemDetails через `IExceptionHandler` | свой Result-конверт в JSON |
| PII at rest | Data Protection + EF ValueConverter на колонках | самописный AES с фиксированным IV |
| Validation | Data annotations | FluentValidation — только если атрибутов мало |
| JSON | **System.Text.Json** | Newtonsoft.Json |
| OpenAPI UI | **Scalar.AspNetCore** (MIT) | Swashbuckle UI / NSwag |

**Схема БД — code-first** (ADR-0005): сущности + `dotnet ef migrations add`.
Накат при старте API (`DbMigrator`); seed каталогов — `SeedDbContext`.
Quartz JobStore — отдельный `QuartzDbContext`, vendor SQL в миграции.
Запросы сначала в EF; `.sql` только после профилирования.

**Quartz.NET:** ADO.NET JobStore на Postgres; дашборд — first-party
**Quartz.Dashboard** (Apache-2.0, тот же пакет/версия, что и Quartz). Это
операторский Blazor UI внутри API (`/quartz`), не продуктовый фронт (ADR-0002
по-прежнему Next.js). Auth: ASP.NET policy `QuartzDashboard` (Basic scheme +
роль `SchedulerAdmin`) — [официальная дока](https://www.quartz-scheduler.net/documentation/quartz-3.x/packages/dashboard.html#policy-and-role-based-authorization).
Публичный дашборд запрещён. Отказ от Hangfire (Pro/лицензии) в силе — ADR-0004.

**Платежи:** **FreedomPay** (KZ) — Merchant/Gateway pay-in + Result URL;
после пилота — ISO 20022 settlement для массовых выплат. См. `04_payments.md`.

**PostgreSQL** — `WITH RECURSIVE` + JSONB для `bonus_rules.config_json`.  
Redis / брокер — не ставим.

## Frontend

| Нужно | Берём | Почему |
|---|---|---|
| App | **Next.js** (App Router) + React + TS strict | MIT, огромная экосистема, ADR-0002 |
| UI | **shadcn/ui** + Tailwind | MIT; компоненты в репо — слабый lock-in |
| Server state | **TanStack Query** | MIT, стандарт де-факто |
| Client state | React state / URL | без Zustand/Redux |
| Дерево | **`@xyflow/react` (v12+)** | MIT core (бывш. `reactflow`); Pro = примеры/шаблоны/поддержка, не runtime |
| Графики | **Recharts** | MIT, adoption большой; см. watch-item ниже |

**Сборка Next.js:** всегда `output: 'standalone'` в `next.config.js` —
страховка от мягкого vendor lock-in под Vercel (ISR/edge middleware заточены
под их хостинг). С `standalone` прод без проблем на любом VPS/Docker.

**`@xyflow/react`:** то же MIT-ядро React Flow под актуальным именем пакета
(v12+). Платный React Flow Pro покрывает доп. примеры/шаблоны/поддержку, не
саму функциональность — смены библиотеки не требуется, только npm-имя.

**Recharts (watch-item):** исторически бывали периоды медленной реакции
мейнтейнеров на issues — MIT, adoption большой, форкать при необходимости
несложно. При проблемах со стабильностью в будущем рассмотреть **visx**
(Airbnb, MIT) как альтернативу для графиков.

Не брать: платные UI-kit (MUI X Pro и аналоги), тяжёлые «enterprise» design systems,
второй state-manager «на вырост».

## Инфра
- MVP на **бесплатных** тирах — см. `docs/09_mvp_deployment.md`
  (пока нет своего домена; FreedomPay webhook нужен публичный HTTPS URL API).
- Staging для bonus engine (отдельный env / проект, не prod DB).
- FreedomPay + Result URL + идемпотентность — см. `04_payments.md`.

## Для агентов
1. Стек = этот файл + `TECH_SPEC.md` + ADR-0002/0004/0005. Не выбирать заново.
2. Новый NuGet/npm вне таблицы — **спросить человека**.
3. Денежные экраны — ручной review.
