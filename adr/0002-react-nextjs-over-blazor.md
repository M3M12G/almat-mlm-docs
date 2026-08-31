# ADR-0002: React/Next.js over Blazor Server

## Контекст

Backend — ASP.NET Core. Изначально рассматривался **Blazor Server** как
fullstack-.NET UI. Приоритеты пилота сместились: сильный визуал ЛК (дерево сети,
графики), экосистема UI-компонентов, активная генерация фронта ИИ-ассистентами.

## Решение

Фронтенд пилота — **Next.js (App Router) + React + TypeScript strict**, отдельно
от API (приложение **mlm-web**, репо `almat-mlm-web`). UI: shadcn/ui + Tailwind;
серверное состояние: TanStack Query; дерево: `@xyflow/react` (v12+, MIT; бывш.
reactflow). Без Zustand/Redux и без второй UI-библиотеки на старте. Next:
`output: 'standalone'` для self-host.

**Актуальный выбор фронтенда — только Next.js/React.** Blazor Server / Blazor
Wasm **не** являются целевым стеком. Упоминания Blazor в истории означают
отклонённую альтернативу, не план реализации.

## Альтернативы

| Вариант | Почему не взяли |
|---|---|
| **Blazor Server** | Уже .NET, но слабее экосистема визуала/компонентов; меньше обучающих данных у ИИ для UI |
| **Blazor WASM** | Тяжёлый cold start, всё ещё уже экосистема vs React |
| **SPA на Vite + React** | Без App Router/SSR-опций Next; для пилота Next даёт готовый каркас |

## Последствия

- ✅ Разделение **mlm-api** (.NET, репо `almat-mlm-api`) и **mlm-web** (Next,
  репо `almat-mlm-web`)
- ✅ TypeScript strict обязателен для ИИ-генерации
- ⚠️ Два рантайма в деплое (Node + .NET), два CI
- ⚠️ Агенты не должны предлагать Blazor-компоненты или Razor Pages как UI
- 📄 Детали: `docs/01_stack.md`, `docs/TECH_SPEC.md` §4
