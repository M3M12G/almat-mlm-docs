# ADR-0004: Open-source, long-lived dependencies only

## Контекст

Пилот соло; стек должен жить годы без сюрпризов по лицензии и без vendor lock-in.
Ряд популярных .NET-библиотек (MediatR, AutoMapper и др.) ушёл или уходит в
commercial / dual-license модель. Нужна явная политика: что можно ставить сразу,
что — только при боли, что — запрещено без OK человека.

## Решение

1. **Сначала BCL и Microsoft.\*** (ASP.NET Core, EF Core, Npgsql, JWT bearer,
   ProblemDetails, `IHostedService` / `BackgroundService`).
2. **Стороннее — только зрелый OSS** (MIT/Apache-2.0/BSD), активные релизы,
   широкое adoption. Перед NuGet/npm — проверить лицензию и «кто владеет».
3. **Маппинг DTO:** **Mapster** (MIT, OSS) — не AutoMapper. Простые случаи
   можно и руками; сложные конфиги — через Mapster.
4. **Фоновые задачи:** **Quartz.NET** (Apache-2.0) + JobStore на Postgres +
   first-party **Quartz.Dashboard** под ASP.NET **authorization policy**
   (`QuartzDashboard`: Basic scheme + роль `SchedulerAdmin`). Hangfire не
   ставим (Pro/лицензии).
   *(История: смотрели TickerQ ради UI, затем CrystalQuartz как сторонний
   UI; оба заменены официальным Quartz.Dashboard — см. дополнение.)*
5. **Валидация:** data annotations / ручные checks. FluentValidation (Apache-2.0)
   — опционально, не сразу.
6. **Frontend:** React + Next.js (`output: 'standalone'`) + TanStack Query +
   Tailwind + **shadcn/ui** (MIT, код копируется в репо — минимум lock-in) +
   **`@xyflow/react`** (v12+, MIT core) / **Recharts** (MIT; watch-item →
   visx при проблемах) по мере экранов. Без платных UI-kit (MUI X Pro и т.п.)
   и без Redux/Zustand на старте.
7. **OpenAPI UI:** **Scalar.AspNetCore** (MIT) поверх `Microsoft.AspNetCore.OpenApi`.
   Флаг `OpenApi:Enabled` (Development — true).

## Альтернативы (отклонены на старте)

| Пакет | Почему нет сейчас |
|---|---|
| **MediatR** | Commercial shift; для пилота хватает controller → service |
| **AutoMapper** | Commercial; вместо него **Mapster** (MIT) |
| **Hangfire** | Pro/лицензионная путаница; **отказ в силе**. Не обходим «Hangfire Core» |
| **TickerQ** | Моложе экосистема; дашборд — Quartz.Dashboard + ASP.NET policy |
| **MassTransit / Kafka / Rabbit** | YAGNI |
| **Clean Architecture / VSA + MediatR шаблон** | Оверинжиниринг для соло-пилота |

## Дополнение — Jobs: Quartz.NET (актуально)

**Статус:** финальный выбор п.4 — **Quartz.NET**, не TickerQ / Hangfire /
«голый» `BackgroundService`.

### Почему Quartz

| Критерий ADR-0004 | Quartz.NET |
|---|---|
| Лицензия | **Apache-2.0** |
| Зрелость | годы в проде, огромная экосистема |
| Persistence | ADO.NET JobStore → **Postgres** (та же БД пилота) |
| Cron / календарь | из коробки (месячный Leadership Pool и т.д.) |
| Дашборд | **Quartz.Dashboard** (first-party, Apache-2.0, pin той же версии, что Quartz) |
| Auth на UI | ASP.NET policy `QuartzDashboard` на pages + hub + `_blazor` + assets ([дока](https://www.quartz-scheduler.net/documentation/quartz-3.x/packages/dashboard.html#policy-and-role-based-authorization)) |

Ранее рассматривали TickerQ из‑за «дашборда из коробки», затем CrystalQuartz
как сторонний UI. First-party `Quartz.Dashboard` закрывает UI + policy auth
без третьего пакета; пакет помечен WIP — пиним 3.20.x, API может меняться.

### Операционное требование

Дашборд Quartz **не** публиковать без `AuthorizationPolicy`. На всех
окружениях (local / staging / prod): policy `QuartzDashboard` (сейчас HTTP
Basic + роль `SchedulerAdmin`; после Identity — тот же policy на admin JWT).
Без policy пакет **не** ставит auth на UI — это дыра. URL дашборда не светить
в публичных README. API-only .NET 10: `RequiresAspNetWebAssets=true` +
`UseStaticFiles` + `UseAntiforgery`.

### Hangfire

Отказ (**Pro / лицензионная путаница**) **остаётся в силе**.

### Rollback

При критических проблемах с Quartz/UI — сузить до `BackgroundService` + таблица
`job_runs` + минимальный self-hosted status page. **Не** откатываться на Hangfire.

## Последствия

- ✅ Предсказуемые лицензии, меньше сюрпризов при апгрейде
- ✅ Меньше магии commercial-стека — проще ревью денежных путей
- ✅ Jobs: Quartz.NET + Postgres + Quartz.Dashboard с policy `QuartzDashboard`
- ⚠️ Новый NuGet/npm вне allow-list — **спросить человека** (см. `AGENTS.md`)
- 📄 Стек: `docs/01_stack.md`, `docs/TECH_SPEC.md`, `docs/09_mvp_deployment.md`
