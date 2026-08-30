-- ============================================================
-- Recursive CTE — примеры обхода дерева сети
-- ============================================================

-- ---------- Обход ВВЕРХ (для Direct Bonus / Unilevel Bonus, макс. 10 уровней) ----------
-- Дешёвая операция: линейна по глубине, НЕ зависит от ширины дерева.

WITH RECURSIVE ancestors AS (
    SELECT id, sponsor_id, 1 AS level
    FROM users
    WHERE id = :buyer_id

    UNION ALL

    SELECT u.id, u.sponsor_id, a.level + 1
    FROM users u
    JOIN ancestors a ON u.id = a.sponsor_id
    WHERE a.level < 10
)
SELECT * FROM ancestors WHERE level > 1;


-- ---------- Обход ВНИЗ (для ранговых условий — состав команды) ----------
-- ВНИМАНИЕ: потенциально дорогая операция при широком+глубоком дереве.
-- Использовать только для батч-пересчёта/сверки, НЕ на лету при каждом запросе.
-- В проде — материализованные агрегаты, обновляемые инкрементально вверх
-- при каждой покупке (см. queries_incremental.sql).

WITH RECURSIVE descendants AS (
    SELECT id, sponsor_id, 1 AS level
    FROM users
    WHERE sponsor_id = :root_user_id

    UNION ALL

    SELECT u.id, u.sponsor_id, d.level + 1
    FROM users u
    JOIN descendants d ON u.sponsor_id = d.id
)
SELECT * FROM descendants;


-- ---------- Проверка на цикл при назначении/смене sponsor_id ----------
-- Перед UPDATE users SET sponsor_id = :new_sponsor_id WHERE id = :user_id
-- проверить, что :user_id НЕ встречается в цепочке предков :new_sponsor_id.

WITH RECURSIVE potential_ancestors AS (
    SELECT id, sponsor_id
    FROM users
    WHERE id = :new_sponsor_id

    UNION ALL

    SELECT u.id, u.sponsor_id
    FROM users u
    JOIN potential_ancestors pa ON u.id = pa.sponsor_id
)
SELECT EXISTS (
    SELECT 1 FROM potential_ancestors WHERE id = :user_id
) AS would_create_cycle;


-- ---------- Инкрементальное обновление total_team_volume вверх по цепочке ----------
-- Выполняется после каждой покупки — добавляет объём покупки ко всем предкам
-- до 10 уровней (или без ограничения, в зависимости от бизнес-правила для
-- ранговых условий — см. 07_open_questions.md).

WITH RECURSIVE ancestors AS (
    SELECT id, sponsor_id, 1 AS level
    FROM users
    WHERE id = :buyer_id

    UNION ALL

    SELECT u.id, u.sponsor_id, a.level + 1
    FROM users u
    JOIN ancestors a ON u.id = a.sponsor_id
)
UPDATE users
SET total_team_volume = total_team_volume + :purchase_amount
WHERE id IN (SELECT id FROM ancestors WHERE level > 1);
