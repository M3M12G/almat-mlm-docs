# Технологический стек

Принцип: **KISS + YAGNI** + **OSS на долгий срок** (ADR-0004).  
Не ставить библиотеку, пока боль не появилась. Не ставить commercial NuGet «по привычке».

## Backend (.NET 10)

| Нужно | Берём | Не берём на старте |
|---|---|---|
| Web API | ASP.NET Core | Blazor UI |
| Данные | EF Core + Npgsql; CTE через `FromSqlInterpolated` | Dapper «на всякий» |
| Структура | Controllers + services + DbContext | MediatR, Clean Architecture шаблоны |
| DTO map | **Mapster** (MIT) | AutoMapper |
| Jobs | **TickerQ** (MIT/Apache-2.0) | Hangfire, MassTransit, Kafka, Quartz «на вырост» |
| Auth | JWT bearer + httpOnly cookie | Identity UI / сторонние auth SaaS без нужды |
| Errors | ProblemDetails | свой Result-фреймворк |
| Validation | Data annotations | FluentValidation — только если атрибутов мало |

**TickerQ:** EF Core storage (Postgres), встроенный SignalR-дашборд.
`AddDashboardBasicAuth()` **обязательна в проде** (и на staging / MVP-демо) —
не оставлять дашборд джоб публично открытым без авторизации.
Отказ от Hangfire (Pro/лицензии) в силе — ADR-0004 дополнение.

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
(Airbnb, MIT) как альтернативу для графиков. (Аналог принятого риска с планом
пересмотра, как у TickerQ в ADR-0004.)

Не брать: платные UI-kit (MUI X Pro и аналоги), тяжёлые «enterprise» design systems,
второй state-manager «на вырост».

## Инфра
- MVP на **бесплатных** тирах — см. `docs/09_mvp_deployment.md`
  (пока нет своего домена и платёжки).
- Staging для bonus engine (отдельный env / проект, не prod DB).
- Один эквайринг + webhook + идемпотентность — когда появятся реквизиты.

## Для агентов
1. Стек = этот файл + `TECH_SPEC.md` + ADR-0002/0004. Не выбирать заново.
2. Новый NuGet/npm вне таблицы — **спросить человека**.
3. Денежные экраны — ручной review.
