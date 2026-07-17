---
name: aaaaa-xxf-ui-technology-selection
description: Android UI technology selection and default implementation guidance. Use when choosing or changing the UI stack for Android screens. Default to multi-Activity apps with Activity-hosted Jetpack Compose screens, and use XML/View only for hard constraints.
---

> 备注：此 skill 来自 https://github.com/NBXXF/android-skills，请不要手动修改！新增或维护本工程内的 skill 时也必须保留此备注规则，方便其他业务引用方识别来源。

# UI Technology Selection

## Default Choice

- New Android UI uses `Activity + Jetpack Compose` by default.
- Prefer multiple Activities when the product flow is clearer with explicit entry points.
- Each Activity hosts the page with `setContent { ... }`.
- New pages must not use XML layouts by default.
- Do not default to Fragment or XML for new screens.

## Strong Defaults

- Compose is the primary UI framework for screens, dialogs, empty states, settings pages, forms, lists, and detail pages.
- Keep Activity thin: entry, dependency acquisition, system callbacks, `setContent`.
- Keep state and navigation glue in Compose route/screen layers and ViewModel/state holders.
- Prefer Compose primitives such as `LazyColumn` and `LazyVerticalGrid` over new RecyclerView paths.
- Do not create new XML layouts for primary UI paths unless there is a clear migration blocker.

## When To Use XML Or View

Use XML/View only when the UI is constrained by:

- a third-party SDK that only exposes traditional Views
- `RemoteViews`, `AppWidget`, notifications, input method UI, or similar system constraints
- map, camera, player, or WebView surfaces that are already View-centric
- a narrowly scoped legacy fix where Compose migration would add unacceptable risk

If XML/View is kept, explain why Compose was not used and what the boundary is.

## Selection Rules

1. Choose Compose first for new screens.
2. Prefer Compose migration for existing screens unless a hard View constraint exists.
3. Keep multiple Activities when the flow benefits from simpler lifecycle or routing boundaries.
4. Do not choose Fragment as the default container for new UI.
5. Do not add DataBinding or ViewBinding for a new Compose-first path.
6. If the project already has Compose Navigation, follow it; otherwise use a thin Activity host with direct Compose content.

## Implementation Checklist

- Activity hosts the page and calls `setContent`.
- Compose handles layout, interaction, and state rendering.
- ViewModel or other state holder owns data loading and state transitions.
- UI code respects design alignment, insets, font scaling, and responsive behavior.
- Any legacy XML fallback is explicitly documented as temporary or constrained.

## Practical Output

When this skill is used, the final answer should say:

- whether Compose or XML was chosen
- why the choice fits the page
- whether the app uses multiple Activities or a different structure
- what legacy UI tech was avoided or retained
