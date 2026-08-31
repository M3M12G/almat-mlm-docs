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
   OSS-дашборд (CrystalQuartz или эквивалент) под **стандартной ASP.NET
   авторизацией** (Basic Auth / policy). Hangfire не ставим (Pro/лицензии).
   *(История: кратко смотрели TickerQ ради UI — откатили в пользу зрелого
   Quartz + auth на дашборде; см. дополнение.)*
5. **Валидация:** data annotations / ручные checks. FluentValidation (Apache-2.0)
   — опционально, не сразу.
6. **Frontend:** React + Next.js (`output: 'standalone'`) + TanStack Query +
   Tailwind + **shadcn/ui** (MIT, код копируется в репо — минимум lock-in) +
   **`@xyflow/react`** (v12+, MIT core) / **Recharts** (MIT; watch-item →
   visx при проблемах) по мере экранов. Без платных UI-kit (MUI X Pro и т.п.)
   и без Redux/Zustand на старте.

## Альтернативы (отклонены на старте)

| Пакет | Почему нет сейчас |
|---|---|
| **MediatR** | Commercial shift; для пилота хватает controller → service |
| **AutoMapper** | Commercial; вместо него **Mapster** (MIT) |
| **Hangfire** | Pro/лицензионная путаница; **отказ в силе**. Не обходим «Hangfire Core» |
| **TickerQ** | Моложе экосистема; дашборд закрываем Quartz + CrystalQuartz (или аналог) + ASP.NET auth |
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
| Дашборд | OSS UI (**CrystalQuartz** или эквивалент) |
| Auth на UI | **стандартная ASP.NET** авторизация (Basic Auth на всех env; либо admin policy) — без кастомного API дашборда |

Ранее рассматривали TickerQ из‑за «дашборда из коробки». Требование закрывается
связкой Quartz + OSS dashboard + middleware auth; зрелость/adoption важнее
молодой библиотеки.

### Операционное требование

Дашборд Quartz **не** публиковать без auth. На всех окружениях (local demo /
staging / prod): Basic Auth или существующая admin-аутентификация приложения.
URL дашборда не светить в публичных README.

### Hangfire

Отказ (**Pro / лицензионная путаница**) **остаётся в силе**.

### Rollback

При критических проблемах с Quartz/UI — сузить до `BackgroundService` + таблица
`job_runs` + минимальный self-hosted status page. **Не** откатываться на Hangfire.

## Последствия

- ✅ Предсказуемые лицензии, меньше сюрпризов при апгрейде
- ✅ Меньше магии commercial-стека — проще ревью денежных путей
- ✅ Jobs: Quartz.NET + Postgres + dashboard с ASP.NET auth
- ⚠️ Новый NuGet/npm вне allow-list — **спросить человека** (см. `AGENTS.md`)
- 📄 Стек: `docs/01_stack.md`, `docs/TECH_SPEC.md`, `docs/09_mvp_deployment.md`
