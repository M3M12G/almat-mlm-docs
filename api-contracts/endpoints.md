# API Endpoints — черновик

Базовый URL: `/api`. Формат — JSON REST. Аутентификация — JWT в httpOnly cookie.

## Auth
| Метод | Путь | Описание |
|---|---|---|
| POST | `/auth/register` | Регистрация (email/phone + referral_code спонсора) |
| POST | `/auth/login` | Вход, выдача access + refresh token |
| POST | `/auth/refresh` | Обновление access token |
| POST | `/auth/logout` | Выход |
| POST | `/auth/verify-phone` | Верификация SMS-кодом |

## Сеть
| Метод | Путь | Описание |
|---|---|---|
| GET | `/network/tree` | Дерево вниз от текущего пользователя (N уровней) |
| GET | `/network/ancestors` | Цепочка вверх (до 10 уровней) |
| GET | `/network/stats` | Агрегаты: total_team_volume, состав по рангам |

## Каталог / заказы
| Метод | Путь | Описание |
|---|---|---|
| GET | `/catalog/packages` | Список пакетов (START/BUSINESS/PREMIUM) |
| POST | `/orders` | Создание заказа |
| GET | `/orders/{id}` | Статус заказа |
| POST | `/payments/webhook` | FreedomPay Result URL (идемпотентный по `pg_payment_id`) |

## Личный кабинет
| Метод | Путь | Описание |
|---|---|---|
| GET | `/me` | Профиль, ранг, баланс |
| GET | `/me/bonus-transactions` | История начислений (пагинация) |
| GET | `/me/rank-progress` | Прогресс до следующего ранга |
| POST | `/me/withdrawals` | Заявка на вывод средств |
| GET | `/me/withdrawals` | История заявок на вывод |

## Админка
| Метод | Путь | Описание |
|---|---|---|
| GET | `/admin/users` | Список пользователей, поиск/фильтр |
| PATCH | `/admin/users/{id}` | Ручная правка (осторожно с sponsor_id — проверка циклов!) |
| GET | `/admin/withdrawals` | Заявки на вывод — очередь на подтверждение |
| PATCH | `/admin/withdrawals/{id}` | Подтвердить/отклонить выплату |
| GET | `/admin/bonus-rules` | Текущие правила начисления (config_json) |
| PATCH | `/admin/bonus-rules/{code}` | Изменение конфига правила (проценты, пороги) |
| GET | `/admin/pool-periods` | История расчётов Leadership Pool |
| POST | `/admin/pool-periods/{period}/recalculate` | Ручной пересчёт (safety net) |

## Примечания
- Все мутирующие эндпоинты, касающиеся денег (`orders`, `withdrawals`,
  `bonus-rules`), должны логироваться в `audit_log`.
- `/payments/webhook` — публичный Result URL FreedomPay: проверка `pg_sig` +
  идемпотентность по `pg_payment_id` → `payment_provider_tx_id`. Без JWT.
  Ответ в формате провайдера (`ok` / `rejected` / `error`). См. `04_payments.md`.
