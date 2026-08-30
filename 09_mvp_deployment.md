# MVP Deployment — бесплатные ресурсы (без домена и эквайринга)

**Статус:** план до появления своего домена и платёжного провайдера.  
Цель: публичный demo URL для инвестора + staging для bonus engine, **$0/мес**.

Платежка и кастомный домен — **out of scope этого документа** (подключить позже
поверх той же схемы).

---

## 1. Целевая схема MVP

```
                    *.vercel.app (или Pages)
┌─────────────┐         HTTPS          ┌──────────────────┐
│  apps/web   │───────────────────────►│ Cloudflare Tunnel │  (опц.)
│  Next.js    │                        │  или публичный    │
│  (Vercel)   │◄───── API_URL ────────│  URL API          │
└─────────────┘                        └────────┬─────────┘
                                                │
                                                ▼
                                       ┌──────────────────┐
                                       │    apps/api      │
                                       │  .NET 10 +       │
                                       │  TickerQ         │
                                       │  (Render / Fly)  │
                                       └────────┬─────────┘
                                                │
                                                ▼
                                       ┌──────────────────┐
                                       │  PostgreSQL      │
                                       │  (Neon free)     │
                                       └──────────────────┘
```

Один compose-файл остаётся для **локальной** разработки (`api` + `postgres`).
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

**Prod с реальной платёжкой** — отдельный этап после домена + эквайринга
(не смешивать с demo DB).

---

## 4. Что деплоить как

### 4.1 `apps/web` → Vercel
- Root Directory: `apps/web` (когда появится код).
- Env: `NEXT_PUBLIC_API_URL` = публичный URL API.
- Cookies/CORS: API должен отдавать CORS только на origin Vercel
  (explicit origins, не `*`).

### 4.2 `apps/api` → Render Web Service (или Fly)
- Dockerfile в `apps/api` (multi-stage .NET 10).
- Env: `ConnectionStrings__Default`, JWT keys, TickerQ dashboard credentials.
- Health: `GET /health` — для cold-start ping.
- **TickerQ dashboard:** Basic Auth обязателен; не публиковать без пароля
  (см. ADR-0004, `AGENTS.md`).

### 4.3 Postgres → Neon
- Две ветки: `staging`, `demo`.
- Миграции EF — из CI или one-shot job на deploy staging
  (не auto-migrate demo без подтверждения).

---

## 5. Без домена — как жить

| Нужда | Решение |
|---|---|
| HTTPS URL фронта | `*.vercel.app` |
| HTTPS URL API | `*.onrender.com` / `*.fly.dev` |
| Cookie auth cross-site | SameSite=None; Secure; явный CORS + CSRF-стратегия **или** на MVP временно Bearer в memory только для demo (хуже) — предпочтительно общий reverse-proxy позже |
| Webhook эквайринга | **недоступен** без публичного стабильного URL + провайдера; mock payments на MVP |
| Красивый бренд-URL | отложить до покупки домена → Cloudflare |

**Практика для MVP-демо без эквайринга:**
- Режим `Payments:Provider=Mock` — заказ сразу `paid` (только staging/demo).
- Реальный webhook — после выбора Epay/Kaspi и домена/стабильного API URL.

---

## 6. TickerQ на free hosting

- Jobs крутятся **внутри** процесса API → на Render Free при sleep **cron не тикает**.
  Mitigation: (a) внешний free cron (cron-job.org) пингует `/health` каждые 10–14 мин;
  (b) или Fly.io с минимальным always-on, если лимит позволяет;
  (c) Leadership Pool на MVP запускать **вручную** из дашборда TickerQ на демо.
- Дашборд: Basic Auth; URL не светить в публичных README.

---

## 7. Секреты и безопасность MVP

- [ ] JWT signing key / Data Protection keys — только env
- [ ] TickerQ `AddDashboardBasicAuth()` на **всех** env
- [ ] Neon connection string с SSL
- [ ] CORS allowlist = Vercel origins
- [ ] Mock payments **запрещены** на любом env с реальными деньгами
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
- Реальный эквайринг + webhook SLA
- Neon упирается в storage → dedicated Postgres

План B all-in-one: **Oracle Always Free** / Hetzner CX + Docker Compose
(API + PG + Caddy) — когда SaaS-лимиты бесят сильнее, чем ops.

---

## 10. Чеклист первого выката (без платежей)

1. Neon: проекты `staging` + `demo`
2. Render/Fly: API с `/health`, TickerQ + Basic Auth
3. Vercel: web → `NEXT_PUBLIC_API_URL`
4. Mock payments включён **только** на staging/demo
5. Прогрев API перед демо инвестору
6. Открыть TickerQ dashboard по Basic Auth — показать Leadership Pool job
7. Зафиксировать URL в `.scratch/` / README demo-секции (не коммитить пароли)

Связанные: ADR-0004 (TickerQ), `01_stack.md`, `TECH_SPEC.md`, `06_security.md`.
