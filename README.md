# almat_mlm_app

Пилот Almat MLM — приложение + каноническая техдокументация.

## Start here

1. [`docs/TECH_SPEC.md`](docs/TECH_SPEC.md) — backend / frontend / storage / integrations
2. [`docs/07_open_questions.md`](docs/07_open_questions.md) — закрыть до bonus engine
3. [`docs/08_roadmap.md`](docs/08_roadmap.md) — этапы
4. [`docs/09_mvp_deployment.md`](docs/09_mvp_deployment.md) — бесплатный MVP-деплой (до домена/эквайринга)
5. [`docs/adr/0004-…`](docs/adr/0004-oss-long-lived-dependencies.md) — OSS-политика + **TickerQ**

## Layout

```
almat_mlm_app/
├── AGENTS.md
├── docs/
│   ├── TECH_SPEC.md           # сводная техспека
│   ├── 00_…09_*.md            # домен + MVP deploy
│   ├── adr/                   # принятые архитектурные решения
│   └── agents/                # Matt Pocock skills config
├── db/                        # schema + recursive CTE
├── api-contracts/
├── apps/{api,web}/            # независимые папки (не monorepo)
├── .scratch/                  # issues + archive/root-draft
├── graphify-out/
└── .codegraph/
```

`apps/api` и `apps/web` без Nx/Turborepo — позже разные репозитории.

## Graphs

```bash
# docs/architecture graph
# (re-run after doc changes via agent /graphify --update)

# code index (после появления исходников)
codegraph sync .
```
