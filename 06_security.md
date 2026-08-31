# Безопасность

## Обязательно до публичного запуска

- [ ] Пентест (хотя бы базовый аудит от ИБ-компании) — приоритет №1, система
      работает с деньгами.
- [ ] 2FA для вывода средств: одноразовый код (SMS), хеш в БД, лимит попыток
      в окне времени; не логировать код.
- [ ] Rate limiting / anti-fraud на регистрации — критично при MLM: боты-
      регистрации ради бонусов, множественные аккаунты одного человека.
- [ ] Шифрование ПДн (ИИН, банковские реквизиты): **Data Protection API**,
      ключи в Postgres (`PersistKeysToDbContext`), колонки через EF
      ValueConverter. ИИН — 12 цифр; дата рождения из цифр 1–6 + код века.
- [ ] Audit trail: штампы `created_at`/`created_by`/`updated_at`/`updated_by`
      на доменных строках; колоночный diff апдейтов в `audit_log` (ChangeTracker).
      Append-only, та же Postgres, не брокер. Не логировать секреты (hash, ИИН).
- [ ] JWT в httpOnly cookie (`Secure`, SameSite Lax локально / None на HTTPS
      за прокси). Refresh — строка сессии в БД, ротация при каждом refresh,
      отзыв + Quartz-cleanup просроченных.
- [ ] За прокси (Render/Fly): `UseForwardedHeaders` (Proto/Host), иначе cookie
      Secure/SameSite ломаются.
- [ ] Валидация всех raw SQL с recursive CTE — параметризация обязательна, даже
      в сыром SQL (не только там, где EF Core параметризует автоматически).
- [ ] Quartz.Dashboard — только под ASP.NET policy `QuartzDashboard`
      (Basic / admin JWT); не публиковать UI без policy (ADR-0004).
- [ ] FreedomPay: `SecretKey` / Partner JWS secret только в env; Result URL
      проверяет `pg_sig` на каждый запрос.

## Инфраструктурный уровень

- Cloudflare (WAF + DDoS-защита), free/pro tier достаточно на пилоте.
- Автоматизированные бэкапы БД, хранение снапшотов **отдельно** от основного
  сервера (offsite).
- Мониторинг + алерты (Grafana/Prometheus или проще — Uptime Robot с алертами
  в Telegram/SMS).
- Staging-окружение обязательно для тестирования bonus engine — **нельзя**
  тестировать расчёт бонусов на проде.

## Юридический комплаенс (отдельная область, не чисто техническая)

- Консультация юриста по MLM-регулированию в РК — до фиксации compensation
  plan в коде, не после.
- Консультация по закону "О персональных данных" — отдельно от MLM-юриста.
