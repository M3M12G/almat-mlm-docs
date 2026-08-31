# Платежи и выплаты

**Провайдер пилота:** [FreedomPay](https://docs.freedompay.kz/) (KZ).  
Альтернативы (Epay/Kaspi и т.п.) — **не** рассматриваем, пока не сменится решение.

Официальные доки: [Overview](https://docs.freedompay.kz/overview-1281608m0) ·
[Result notify](https://docs.freedompay.kz/api-12007677) ·
[Gateway / Merchant API](https://freedompay.kz/docs-en/merchant-api/intro).

---

## Приём платежей (покупки) — Merchant / Gateway API

Pay-in через FreedomPay Gateway / Merchant API (`https://api.freedompay.kz`,
тест: `https://test-api.freedompay.kz`).

- Создание платежа на стороне API → редирект/оплата у провайдера.
- Статус заказа в нашей системе обновляется **только** из Result URL (вебхук),
  не из синхронного ответа фронта.
- Все сообщения мерчант ↔ FreedomPay **подписываются** (`pg_sig` + `pg_salt`);
  входящий вебхук без валидной подписи — отклонять.
- **Идемпотентность:** один и тот же Result URL может прийти повторно
  (retry каждые ~30 мин до 2 ч при недоступности/не-200). Обработка по
  уникальному `pg_payment_id` (маппится в `purchases.payment_provider_tx_id`);
  повтор не должен задвоить бонусы.
- Ответ мерчанта на Result URL: XML со статусом `ok` / `rejected` / `error`
  (см. доки). Endpoint **публичный** (без JWT) — защита = проверка `pg_sig`.
- Test mode: merchant в тесте или `pg_testing_mode=1` на конкретной транзакции
  (уточнять у менеджера FreedomPay).

Эндпоинт: `POST /api/v1/payments/webhook` (= Result URL в кабинете FreedomPay).

Конфиг (env / user-secrets, не в git):

| Ключ | Назначение |
|---|---|
| `FreedomPay__MerchantId` | `pg_merchant_id` |
| `FreedomPay__SecretKey` | секрет подписи `pg_sig` |
| `FreedomPay__ApiBaseUrl` | prod / test host |
| `Payments__Provider` | `FreedomPay` \| `Mock` (Mock только staging/demo) |

---

## Выплаты партнёрам

### Пилот

Отдельный модуль от приёма платежей:
- KYC-минимум (паспорт / ИИН) перед выводом
- Лимиты (мин. сумма, частота)
- **Ручное/полуручное** подтверждение админом — без автомассовых выплат
- 2FA обязательна перед заявкой на вывод

### После пилота — ISO 20022 Settlement (FreedomPay Partner API)

Массовые кредитовые переводы через JSON-обёртку + XML ISO 20022 в поле
`document_body` ([overview](https://docs.freedompay.kz/overview-1281608m0)):

| Поле | Значение |
|---|---|
| `document_type` | `iso20022` |
| `document_body` | XML pain.001 / ответ pain.002 |
| Поддерживаемые версии | **pain.001.001.12** (инициация), **pain.002.001.14** (статус) |

**Авторизация запросов к Partner API:** JWS HS256 в заголовке
`X-JWS-Signature`. Секрет = Partner API key; в header JWS — `auth_id`
(User ID мерчанта/партнёра), `uri`, `method`. Подпись считается по
`encodedHeader.encodedPayload` (тело — **строка** `JSON.stringify(...)`,
не «сырой» объект).

Ограничения:
- ≤ **500** платёжных инструкций в одном ISO-документе
- Валидация XSD; типовые коды: `BE04`, `AM04`, `AC01` (IBAN), `RC01` (BIC/TRF)

Статусы settlement:

| ISO | Internal | Смысл |
|---|---|---|
| ACSC | success | Успешно отправлено в банк |
| ACSP | process | В очереди |
| RJCT | error | Ошибка / отказ банка |
| PDNG | downloaded | Загружено, ещё не обработано |

На пилоте ISO settlement **не** подключаем в прод-путь выводов — только
закладываем контракты/секреты, чтобы не переписывать модуль выплат позже.

---

## Идемпотентность — общий принцип

Каждая финансовая операция (покупка, начисление бонуса, заявка на вывод,
пакет ISO-инструкций) имеет уникальный id операции; обработчик проверяет
повтор до записи в `bonus_transactions` / `withdrawal_requests` /
таблицах settlement.

---

## Открытые вопросы к FreedomPay (менеджер)

- Комиссии pay-in для юрлица на момент запуска; сроки зачисления на р/с
- Нужен ли отдельный договор / продукт на Partner Settlement (pain.001)
  для выплат физлицам; лимиты и KYC со стороны банка
- Prod `auth_id` + Partner API secret; whitelist Result URL
- Нужен ли отдельный merchant для test vs prod
