# Almat MLM — Техническая спецификация (пилот)

Каноническая техспека приложения. Детали домена — в соседних файлах `docs/0*.md`,
схема БД — `db/schema.sql`, API — `api-contracts/endpoints.md`.

**Статус:** пилот · соло · backend **.NET 10** + frontend **Next.js**  
**Компенсационный план и деньги в коде не трогать**, пока не закрыты `07_open_questions.md`.  
**KISS + YAGNI + OSS (ADR-0004):** BCL/Microsoft first; commercial NuGet (MediatR,
AutoMapper и т.п.) не ставить; усложнять только после реальной боли.

---

## 1. Цель системы

Платформа сетевого маркетинга (Unilevel): регистрация с рефералом, каталог пакетов,
оплата, начисление бонусов по 5 правилам, ЛК (баланс / дерево / ранг), заявки на вывод,
минимальный бухучёт + админка.

| В пилоте | Вне пилота |
|---|---|
| Auth + сеть + каталог + 1 эквайринг | Автомассовые выплаты |
| 5 bonus-механизмов + ledger | Мультивалютность |
| Ручное подтверждение выводов | Мобильное приложение |
| Проводки + Excel/1С экспорт | Полноценная двойная запись |

---

## 2. Архитектура (высокий уровень)

```
┌─────────────┐     HTTPS/JSON      ┌──────────────────┐
│  apps/web   │◄───────────────────►│    apps/api      │
│  Next.js    │   JWT httpOnly      │  ASP.NET Core 10 │
└─────────────┘                     └────────┬─────────┘
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    ▼                        ▼                        ▼
             ┌────────────┐          ┌──────────────┐          ┌────────────┐
             │ PostgreSQL │          │   TickerQ    │          │  Acquirer  │
             │  (primary) │          │ jobs+dashboard│         │ Epay/Kaspi │
             └────────────┘          └──────────────┘          └────────────┘
```

- MVP-деплой на бесплатных ресурсах — `docs/09_mvp_deployment.md`
  (домен и эквайринг — TBD).
- Cloudflare — CDN + WAF, когда появится домен. Redis / брокер — **не сейчас**.
- Staging обязателен для bonus engine.

---

## 3. Backend (`apps/api`)

### 3.1 Стек
| Слой | Выбор | Лицензия / заметка |
|---|---|---|
| Runtime | **.NET 10** ASP.NET Core Web API | Microsoft |
| API | REST/JSON `/api/v1` | — |
| Структура | Controllers + services + DbContext | без MediatR / VSA |
| ORM | EF Core + Npgsql; CTE через `FromSqlInterpolated` | Microsoft / OSS |
| Mapping | **Mapster** (MIT) | **не** AutoMapper |
| Jobs | **TickerQ** (EF Core / Postgres, SignalR-дашборд) | **не** Hangfire; Quartz-план снят (ADR-0004) |
| Auth | JWT bearer + httpOnly cookie | Microsoft |
| Errors | ProblemDetails | встроено |
| Validation | Data annotations | FluentValidation — опционально позже |

### 3.2 Области
Identity · Network · Catalog/Orders · Payments · BonusEngine · Ranks ·
LeadershipPool (TickerQ job) · Withdrawals · Accounting (минимум) · Admin · Audit.
Папки — по мере кода, без заранее разнесённой Clean Architecture.

### 3.3 Bonus Engine (контракт поведения)
```
Purchase paid (idempotent)
  → DirectBonusRule
  → UnilevelBonusRule (active partners only, ≤10 levels up)
  → MatchingBonusRule (from paid bonus, depth TBD — open Q)
  → RankEngine → RankBonus
  → incremental ancestor volume update

TickerQ monthly cron:
  → LeadershipPoolJob (2% world TO → Gold Director+)
```

- Правила в `bonus_rules.config_json` — **данные, не код** (ADR-0003).
- Баланс = агрегат ledger, не mutable field.
- Порядок Direct vs Unilevel и глубина Matching — закрыть в `07_open_questions.md`
  до реализации.

### 3.4 API (сводка)
Черновик: `api-contracts/endpoints.md`.  
Группы: `/auth/*`, `/network/*`, `/catalog/*`, `/orders`, `/payments/webhook`,
`/me/*`, `/admin/*`. Вебхук — подпись + идемпотентность.

---

## 4. Frontend (`apps/web`)

### 4.1 Стек (фиксированный, OSS)
| Слой | Выбор | Заметка |
|---|---|---|
| Framework | Next.js (App Router) + React + TS **strict** | MIT; ADR-0002 |
| UI | shadcn/ui + Tailwind | MIT; код копируется в репо |
| Server state | TanStack Query | MIT |
| Client state | React state / URL | без Zustand/Redux |
| Tree | **`@xyflow/react` (v12+)** | MIT core (бывш. `reactflow`); Pro = примеры/шаблоны/support, не runtime |
| Charts | Recharts | MIT; watch-item — см. `01_stack.md` (альтернатива: visx) |

Сборка Next.js: всегда `output: 'standalone'` в `next.config.js` (self-host
на VPS/Docker без привязки к Vercel-only defaults).

Платные UI-kit и «enterprise» design systems — не брать.

### 4.2 Поверхности
Public (landing/register/login) · Cabinet · Shop · Admin.

### 4.3 Для агентов
1. Не менять стек самовольно (ADR-0002, ADR-0004).
2. Денежные экраны — ручной review.
3. Не ставить npm «на всякий случай».

---

## 5. Storage

### 5.1 PostgreSQL (primary)
Причина: `WITH RECURSIVE`, JSONB для `bonus_rules` / rank conditions.

**Модель сети — Adjacency List** (`users.sponsor_id`):
- вверх (≤10) — дёшево, для Direct/Unilevel;
- вниз — дорого → материализованные агрегаты (`total_team_volume`, rank composition),
  инкремент вверх при покупке; полный down-scan только в batch сверке.

DDL: `db/schema.sql`. CTE: `db/queries_recursive.sql`.

### 5.2 Ключевые таблицы
| Таблица | Роль |
|---|---|
| `users` | узел сети + агрегаты активности/объёма |
| `packages` | START / BUSINESS / PREMIUM (+ LP) |
| `purchases` | заказы; unique `payment_provider_tx_id` |
| `bonus_rules` | конфиг правил (JSONB) |
| `bonus_transactions` | append-only ledger начислений |
| `ranks` / `rank_achievements` | карьера + разовые премии |
| `pool_periods` / `pool_distributions` | Leadership Pool |
| `withdrawal_requests` | выводы (ручной approve на пилоте) |
| `accounting_entries` | минимальные проводки |
| `audit_log` | кто трогал финансы |

Миграции — только EF Core Migrations (не руками на проде).

### 5.3 Фоновые jobs — TickerQ
- Storage: **EF Core (Postgres)** — отдельные таблицы TickerQ в той же БД.
- Встроенный **SignalR-дашборд** (демо инвестору + отладка соло).
- **`AddDashboardBasicAuth()` обязательна** в проде, staging и MVP-демо —
  не оставлять дашборд (`/tickerq-dashboard` или заданный `basePath`)
  публично открытым без авторизации.
- Отдельный брокер / Hangfire — **не** нужны; отказ от Hangfire по лицензии
  в силе (ADR-0004).
- Rollback через 6–12 мес. при нестабильности: `BackgroundService` + своя
  таблица `job_runs` + минимальный dashboard.

### 5.4 Экспорт
Excel/1С — генерация файла на скачивание. Object storage не нужен на пилоте.

### 5.5 Чего нет на старте
Redis, Neo4j, search engine, event bus, MediatR, AutoMapper, Hangfire,
Quartz.NET, monorepo tooling.

---

## 6. Интеграции

| Система | Назначение | Требования |
|---|---|---|
| Epay / Kaspi Pay (TBD) | приём оплаты | webhook, signature, idempotency |
| SMS gateway | verify phone / 2FA | rate limit |
| Cloudflare | WAF/CDN | когда появится домен |
| 1С / Excel | бух. экспорт | ручная загрузка на пилоте |
| Free-tier hosting | MVP deploy | см. `09_mvp_deployment.md` |

---

## 7. Безопасность (must before public)

- 2FA на вывод; rate limit + anti-fraud на регистрацию
- Шифрование ПДн (ИИН, реквизиты) — Data Protection / column encrypt
- JWT httpOnly; HTTPS + HSTS; CORS explicit origins
- Параметризация всего raw SQL (CTE)
- Audit trail финансовых действий
- Offsite DB backups; staging для bonus tests
- Пентест до публичного запуска

Детали: `docs/06_security.md`.

---

## 8. Observability & CI

- Логи: встроенный ASP.NET logging сначала; Serilog (Apache-2.0) — если нужна структура
- Health check API; простой uptime-алерт (Telegram)
- GitHub Actions: build + test
- Локально: Docker Compose `api` + `postgres`; облако MVP — `09_mvp_deployment.md`

---

## 9. Repo layout (целевой)

`apps/api` и `apps/web` — **независимые** деревья исходников (без Nx/Turborepo/
pnpm-workspace). Позже уедут в **разные git-репозитории**; сейчас соседствуют
только для спеки и агентской навигации.

```
almat_mlm_app/
├── AGENTS.md
├── CONTEXT.md                 # lazy (domain skills)
├── docs/                      # эта спека + доменные 0*.md + agents/ + adr/
├── db/                        # schema + CTE reference
├── api-contracts/
├── apps/
│   ├── api/                   # ASP.NET solution (отдельный будущий repo)
│   └── web/                   # Next.js app (отдельный будущий repo)
├── .scratch/                  # local issues + archive
├── graphify-out/              # knowledge graph (docs/code)
└── .codegraph/                # code intelligence index
```

---

## 10. Порядок реализации

См. `docs/08_roadmap.md`. Критический путь:

0. Закрыть `07_open_questions.md` письменно  
1. Auth + network  
2. Bonus engine на staging  
3. Catalog + payments  
4. Accounting + admin  
5. Security hardening + soft launch  

---

## 11. Индекс связанных документов

| Файл | Содержание |
|---|---|
| `00_overview.md` | скоуп пилота, принципы (comp plan = data, ledger) |
| `01_stack.md` | стек + политика зависимостей |
| `02_network_model.md` | adjacency list, циклы, агрегаты |
| `03_bonus_engine.md` | 5 правил, пакеты, config_json |
| `04_payments.md` | эквайринг, выводы, идемпотентность |
| `05_accounting.md` | минимальные проводки |
| `06_security.md` | чеклист ИБ |
| `07_open_questions.md` | блокер до кодинга bonus |
| `08_roadmap.md` | этапы |
| `db/schema.sql` | DDL |
| `db/queries_recursive.sql` | CTE |
| `api-contracts/endpoints.md` | REST черновик |
| `docs/adr/0001-…` | Adjacency List |
| `docs/adr/0002-…` | Next.js вместо Blazor |
| `docs/adr/0003-…` | Rules as config_json |
| `docs/adr/0004-…` | OSS / long-lived deps (+ TickerQ) |
| `09_mvp_deployment.md` | бесплатный MVP-деплой (до домена/эквайринга) |
