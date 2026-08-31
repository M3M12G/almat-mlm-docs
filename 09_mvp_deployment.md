# MVP Deployment — бесплатные ресурсы (без домена; mock payments)

**Статус:** план до появления своего домена и боевого FreedomPay.  
Цель: публичный demo URL для инвестора + staging для bonus engine, **$0/мес**.

Боевая платёжка (FreedomPay Result URL) и кастомный домен — **подключить позже**
поверх той же схемы; детали интеграции — `04_payments.md`.

---

## 1. Целевая схема MVP

```
                    *.vercel.app (или Pages)
┌─────────────┐         HTTPS          ┌──────────────────┐
│   mlm-web   │───────────────────────►│ Cloudflare Tunnel │  (опц.)
│  Next.js    │                        │  или публичный    │
│  (Vercel)   │◄───── API_URL ────────│  URL API          │
└─────────────┘                        └────────┬─────────┘
                                                │
                                                ▼
                                       ┌──────────────────┐
                                       │     mlm-api      │
                                       │  .NET 10 +       │
                                       │  Quartz.NET      │
                                       │  (Render / Fly)  │
                                       └────────┬─────────┘
                                                │
                                                ▼
                                       ┌──────────────────┐
                                       │  PostgreSQL      │
                                       │  (Neon free)     │
                                       └──────────────────┘
```

Один compose-файл остаётся для **локальной** разработки (`mlm-api` + `postgres`).
В облаке сервисы разделены по free-tier провайдерам.

---

## 2. Рекомендуемый бесплатный набор

| Слой | Провайдер (free) | Зачем |
|---|---|---|
| **Frontend** | **Vercel Hobby** | Next.js «из коробки», HTTPS, preview на PR |
| **API** | **Render Free** *или* **Fly.io** free allowance | ASP.NET контейнер / native |
| **Postgres** | **Neon Free** (или Supabase Free) | serverless PG, ветки DB под staging |
| **CI** | **GitHub Actions** | build + test на push |
| **Секреты** | env vars провайдера | не в git |
| **DNS / WAF** | позже **Cloudflare** | когда появится домен |
| **Uptime** | UptimeRobot free / Better Stack free | алерт в Telegram |

### Почему не «один бесплатный VPS на всё»
Oracle Always Free / чужой VPS — ок как **план B**, но выше ops-нагрузка
(обновления, бэкапы, TLS). Для соло-MVP быстрее split free SaaS.

### Ограничения free-тиров (принять заранее)
- **Render Free** — cold start ~30–60s после простоя; для демо прогревать
  healthcheck или держать «пингующий» cron.
- **Neon Free** — лимиты storage/compute; для пилота достаточно.
- Нет SLA; не хранить единственную копию продакшен-денег здесь
  (на MVP — demo + staging данные).

---

## 3. Окружения

| Env | Frontend | API | DB | Назначение |
|---|---|---|---|---|
| `local` | `localhost:3000` | `localhost:5xxx` | Docker Postgres | разработка |
| `staging` | Vercel preview / `*-staging` | Render/Fly staging | Neon branch `staging` | bonus engine тесты |
| `demo` (MVP) | Vercel production project | Render/Fly «demo» | Neon branch `demo` | показ инвестору |

**Prod с реальным FreedomPay** — отдельный этап после домена + стабильного
HTTPS API URL (Result URL должен быть публичным).

---

## 4. Что деплоить как

### 4.1 `mlm-web` → Vercel
- Root Directory: корень репо `almat-mlm-web` (когда появится код).
- Env: `NEXT_PUBLIC_API_URL` = публичный URL API.
- Cookies/CORS: API должен отдавать CORS только на origin Vercel
  (explicit origins, не `*`).

### 4.2 `mlm-api` → Render Web Service (или Fly)
- Dockerfile в репо `almat-mlm-api` (multi-stage .NET 10).
- Env: `ConnectionStrings__Default`, JWT keys, Quartz dashboard credentials,
  позже — `FreedomPay__*`.
- Health: `GET /health` — для cold-start ping.
- **Quartz.Dashboard:** policy `QuartzDashboard` обязательна (Basic scheme +
  роль `SchedulerAdmin`); не публиковать без policy (ADR-0004, `AGENTS.md`).

### 4.3 Postgres → Neon
- Две ветки: `staging`, `demo`.
- Схема накатывается `DbMigrator` при старте API (оба контекста + seed
  каталогов). Destructive drop — только явно.
- Таблицы Quartz JobStore — та же БД, отдельный `QuartzDbContext` (ADR-0005).

---

## 5. Без домена — как жить

| Нужда | Решение |
|---|---|
| HTTPS URL фронта | `*.vercel.app` |
| HTTPS URL API | `*.onrender.com` / `*.fly.dev` |
| Cookie auth cross-site | SameSite=None; Secure; явный CORS + CSRF-стратегия **или** на MVP временно Bearer в memory только для demo (хуже) — предпочтительно общий reverse-proxy позже |
| FreedomPay Result URL | нужен публичный стабильный HTTPS; на чистом MVP — mock payments |
| Красивый бренд-URL | отложить до покупки домена → Cloudflare |

**Практика для MVP-демо без FreedomPay:**
- Режим `Payments:Provider=Mock` — заказ сразу `paid` (только staging/demo).
- Реальный Result URL — после выдачи `MerchantId`/`SecretKey` и стабильного API URL.

---

## 6. Quartz на free hosting

- Scheduler крутится **внутри** процесса API → на Render Free при sleep **cron не тикает**.
  Mitigation: (a) внешний free cron (cron-job.org) пингует `/health` каждые 10–14 мин;
  (b) или Fly.io с минимальным always-on, если лимит позволяет;
  (c) Leadership Pool на MVP запускать **вручную** из дашборда Quartz на демо.
- Дашборд: policy `QuartzDashboard` (Basic + `SchedulerAdmin`); URL не светить в публичных README.

---

## 7. Секреты и безопасность MVP

- [ ] JWT signing key / Data Protection keys — только env
- [ ] Quartz dashboard auth на **всех** env
- [ ] Neon connection string с SSL
- [ ] CORS allowlist = Vercel origins
- [ ] Mock payments **запрещены** на любом env с реальными деньгами
- [ ] `FreedomPay__SecretKey` / Partner JWS secret — только env (когда появятся)
- [ ] Бэкап: Neon PITR/export перед демо с «важными» данными

---

## 8. Минимальный CI (GitHub Actions)

```
push → build api + web → test → (manual) deploy staging
```

Auto-deploy demo — только с `main` после зелёного CI.  
EF migrate — отдельный job с approval.

---

## 9. Когда вырастем из free

Триггеры апгрейда (не раньше боли):
- Cold start мешает демо → always-on API ($7–/мес) или маленький VPS
- Нужен свой домен + Cloudflare
- Боевой FreedomPay + Result URL SLA
- Neon упирается в storage → dedicated Postgres

План B all-in-one: **Oracle Always Free** / Hetzner CX + Docker Compose
(API + PG + Caddy) — когда SaaS-лимиты бесят сильнее, чем ops.

---

## 10. Чеклист первого выката (без платежей)

1. Neon: проекты `staging` + `demo`
2. Render/Fly: API с `/health`, Quartz + dashboard auth
3. Vercel: web → `NEXT_PUBLIC_API_URL`
4. Mock payments включён **только** на staging/demo
5. Прогрев API перед демо инвестору
6. Открыть Quartz.Dashboard (`/quartz`) по Basic Auth — показать Leadership Pool job
7. Зафиксировать URL в `.scratch/` / README demo-секции (не коммитить пароли)

Связанные: ADR-0004 (Quartz), `01_stack.md`, `TECH_SPEC.md`, `04_payments.md`,
`06_security.md`.
