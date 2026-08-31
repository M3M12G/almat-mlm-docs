# almat-mlm-docs

Каноническая документация пилота Almat MLM. **Кода здесь нет.**

Приложения: **mlm-api**, **mlm-web**.  
Подключается в репозитории `almat-mlm-api` и `almat-mlm-web` как git submodule
по пути `docs/` (имена репо/папок не совпадают с именами приложений — так и задумано).

## Start here

1. [`TECH_SPEC.md`](TECH_SPEC.md) — backend / frontend / storage / integrations
2. [`07_open_questions.md`](07_open_questions.md) — закрыть до bonus engine
3. [`08_roadmap.md`](08_roadmap.md) — этапы
4. [`09_mvp_deployment.md`](09_mvp_deployment.md) — бесплатный MVP-деплой
5. [`adr/0004-…`](adr/0004-oss-long-lived-dependencies.md) — OSS-политика + Quartz.NET
6. [`adr/0005-…`](adr/0005-ef-code-first-and-json.md) — code-first EF, два контекста, STJ

## Layout

```
almat-mlm-docs/          ← корень репо (= docs/ в api/web после submodule)
├── TECH_SPEC.md
├── 00_…09_*.md
├── adr/
├── agents/              # Matt Pocock skills config
├── db/                  # README + queries_recursive.sql (схема = EF, ADR-0005)
└── api-contracts/
```

В code-репо пути выглядят так:

| В этом репо | В api / web |
|---|---|
| `TECH_SPEC.md` | `docs/TECH_SPEC.md` |
| `adr/` | `docs/adr/` |
| `db/README.md` | `docs/db/README.md` |
| `api-contracts/` | `docs/api-contracts/` |

## Обновление submodule в api/web

```bash
cd docs
git pull origin main
cd ..
git add docs
git commit -m "chore: update docs submodule ref"
```

Не копировать канон в `.scratch` — только ссылки на файлы выше.
