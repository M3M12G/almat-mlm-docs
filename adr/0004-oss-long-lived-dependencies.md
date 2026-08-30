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
4. **Фоновые задачи:** *(исходный план — ниже; **актуально: TickerQ**, см.
   раздел «Дополнение».)* `BackgroundService` + простой schedule (месячный
   Leadership Pool). Если cron-сложность вырастет — **Quartz.NET** (Apache-2.0).
   Hangfire на старте не ставим (Pro/лицензионная путаница не нужна).
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
| **Hangfire** | Pro/лицензионная путаница; **отказ в силе** (см. дополнение ниже). Не заменяется «на Hangfire Core» — обходим через **TickerQ** |
| **Quartz.NET** (как следующий шаг после `BackgroundService`) | План из п.4 пересмотрен: нужен встроенный визуальный дашборд; выбран **TickerQ** (см. дополнение) |
| **MassTransit / Kafka / Rabbit** | YAGNI |
| **Clean Architecture / VSA + MediatR шаблон** | Оверинжиниринг для соло-пилота |

## Дополнение (после проверки на MVP-этапе)

**Статус:** пересмотр п.4 «Фоновые задачи». Исходный план
`BackgroundService → Quartz.NET при росте cron-сложности` **заменяется** на **TickerQ**.

### Почему пересматриваем

Визуальный дашборд мониторинга джоб оказался **приоритетным** требованием:
демо инвестору + повседневная отладка соло-разработчиком. Цепочка
BackgroundService / Quartz этого не даёт «из коробки» без самописного UI.

### Новый выбор: TickerQ

| Критерий ADR-0004 | TickerQ |
|---|---|
| Лицензия | dual-licensed **MIT / Apache-2.0** |
| Владелец | Arcenox LLC (проверено на момент решения) |
| Adoption | ~880K загрузок на NuGet |
| Активность | активные релизы |
| Postgres / EF | EF Core-native, нативная поддержка Postgres |
| Дашборд | встроенный SignalR-дашборд, **без платных надстроек** |

Пройдены те же критерии проверки, что декларирует эта ADR (лицензия, владелец,
adoption, активность).

### Принятый риск (явно)

Библиотека **моложе** Hangfire/Quartz (~2 года истории, меньшая экосистема).
Это осознанный trade-off ради дашборда и OSS-лицензии.

**Переоценка через 6–12 месяцев эксплуатации.** При проблемах со стабильностью —
откат на `BackgroundService` + собственный минимальный dashboard поверх своей
таблицы `job_runs`, **без** внешней job-библиотеки.

### Hangfire

Причина отказа от Hangfire (**Pro / лицензионная путаница**) **остаётся в силе**
и **не** пересматривается этим решением. TickerQ — не «Hangfire-lite», а
отдельный OSS-выбор под дашборд.

### Операционное требование

`AddDashboardBasicAuth()` (или эквивалент) **обязательна** на всех окружениях;
дашборд (`/tickerq-dashboard` или заданный `basePath`) не оставлять публично
открытым. См. `AGENTS.md`, `docs/01_stack.md`, `docs/TECH_SPEC.md`.

## Последствия

- ✅ Предсказуемые лицензии, меньше сюрпризов при апгрейде
- ✅ Меньше магии commercial-стека — проще ревью денежных путей
- ✅ Jobs: TickerQ + Postgres + встроенный дашборд (с auth)
- ⚠️ Новый NuGet/npm вне allow-list — **спросить человека** (см. `AGENTS.md`)
- ⚠️ TickerQ — younger ecosystem; rollback-план зафиксирован выше
- 📄 Стек: `docs/01_stack.md`, `docs/TECH_SPEC.md`, `docs/09_mvp_deployment.md`
