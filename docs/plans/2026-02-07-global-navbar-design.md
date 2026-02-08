# Global Navbar Design: Unified Chrome

## Overview

Add a persistent global navbar to Pearl that provides consistent navigation, repo search, and settings access across all pages. The navbar absorbs WikiLive's existing internal mobile header, creating a single unified navigation bar.

## Approach

**"Unified Chrome"** — a single 48px daisyUI `navbar` that adapts per page. WikiLive's internal mobile navbar is eliminated; its controls (drawer hamburger, Ask button) move into the global bar.

### Why this approach

- Single bar everywhere — no stacked navbars, maximum content space
- Uses the existing unused `app/1` layout component as Phoenix intends
- Clean architecture — router assigns the layout, LiveViews pass assigns
- WikiLive's drawer conflict solved cleanly by removing its internal header

### Alternatives considered

- **Thin Command Bar** (40px strip, WikiLive keeps its own navbar below) — rejected because two bars on wiki mobile wastes space
- **Floating Dock** (pill-shaped overlay with backdrop blur) — rejected because two navigation zones on wiki pages confuses users, accessibility concerns with fixed floating elements

## Navbar Structure

```
┌──────────────────────────────────────────────────────────────────┐
│ [☰]  Pearl / owner/repo    [ Search repos... ]    [Ask] [⚙]    │
│  ^         ^                       ^                 ^    ^     │
│  │         │                       │                 │    │     │
│  drawer    breadcrumb              inline search     │  settings│
│  (wiki     (wiki only)             with dropdown     │  dropdown│
│  mobile                            results           │         │
│  only)                                          (wiki only)    │
└──────────────────────────────────────────────────────────────────┘
```

### Per-page behavior

| Assign | HomeLive | WikiLive | SettingsLive |
|--------|----------|----------|--------------|
| `drawer_id` | `nil` | `"wiki-drawer"` | `nil` |
| `breadcrumb` | `nil` | `"owner/repo"` | `"Settings"` |
| `show_ask` | `false` | `true` | `false` |

## Layout Integration

The `app/1` function component in `layouts.ex` is rewritten with the navbar. The router assigns it via `live_session`:

```elixir
live_session :default,
  layout: {PearlWeb.Layouts, :app},
  on_mount: [PearlWeb.NavbarHook] do

  live "/", HomeLive, :index
  live "/wiki/:id", WikiLive, :show
  live "/settings", SettingsLive, :index
end
```

## Navbar Markup

48px bar, `sticky top-0 z-50`, daisyUI `navbar` with three sections:

```heex
<header class="navbar h-12 min-h-12 bg-base-100 border-b border-base-content/8 px-4 sticky top-0 z-50">
  <div class="navbar-start gap-2">
    <label :if={@drawer_id} for={@drawer_id} class="btn btn-ghost btn-sm btn-square lg:hidden">
      <.icon name="hero-bars-3" class="size-5" />
    </label>

    <.link navigate={~p"/"} class="font-semibold tracking-wider uppercase text-sm text-base-content/70 hover:text-primary transition-colors">
      Pearl
    </.link>
    <span :if={@breadcrumb} class="text-base-content/20">/</span>
    <span :if={@breadcrumb} class="text-sm font-medium truncate max-w-48">{@breadcrumb}</span>
  </div>

  <div class="navbar-center hidden sm:flex">
    <div class="relative">
      <form phx-change="search" phx-submit="search">
        <.icon name="hero-magnifying-glass" class="size-4 absolute left-3 top-1/2 -translate-y-1/2 text-base-content/30" />
        <input type="text" name="q" placeholder="Search repos..."
          class="input input-sm bg-base-200/50 border-base-content/10 pl-9 w-56 focus:w-72 transition-all duration-200 text-sm" />
      </form>
      <ul :if={@search_results != []} class="menu bg-base-200 rounded-box absolute top-full mt-1 w-72 p-2 shadow-lg border border-base-content/10 z-50">
        <li :for={repo <- @search_results}>
          <.link navigate={~p"/wiki/#{repo.id}"}>{repo.owner}/{repo.name}</.link>
        </li>
      </ul>
    </div>
  </div>

  <div class="navbar-end gap-1">
    <button class="btn btn-ghost btn-sm btn-circle sm:hidden">
      <.icon name="hero-magnifying-glass" class="size-4" />
    </button>

    <button :if={@show_ask} phx-click="toggle_ask" class="btn btn-ghost btn-sm gap-1.5 text-base-content/60 hover:text-primary">
      <.icon name="hero-chat-bubble-left-right" class="size-4" />
      <span class="hidden md:inline text-xs">Ask</span>
    </button>

    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="btn btn-ghost btn-sm btn-circle">
        <.icon name="hero-cog-6-tooth" class="size-4" />
      </div>
      <ul tabindex="0" class="dropdown-content menu bg-base-200 rounded-box z-[1] w-48 p-2 shadow-lg border border-base-content/10 mt-2">
        <li>
          <.link navigate={~p"/settings"}>
            <.icon name="hero-adjustments-horizontal" class="size-4" /> Settings
          </.link>
        </li>
      </ul>
    </div>
  </div>
</header>
```

## Search Behavior

Search is handled by a shared `on_mount` hook so every LiveView gets it automatically:

```elixir
defmodule PearlWeb.NavbarHook do
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(search_results: [], search_query: "")
      |> attach_hook(:navbar_search, :handle_event, &handle_event/3)

    {:cont, socket}
  end

  defp handle_event("search", %{"q" => ""}, socket) do
    {:halt, assign(socket, search_results: [], search_query: "")}
  end

  defp handle_event("search", %{"q" => query}, socket) do
    results = Pearl.Repositories.search(query)
    {:halt, assign(socket, search_results: results, search_query: query)}
  end

  defp handle_event(_event, _params, socket), do: {:cont, socket}
end
```

`Pearl.Repositories.search/1` queries repos by owner or name using `ilike`.

Selecting a result navigates to `/wiki/:id`. Clicking outside dismisses results via `phx-click-away` or JS hook.

## WikiLive Drawer Adjustments

WikiLive's internal mobile navbar is removed. The drawer adjusts to sit below the global bar:

```heex
<div class="drawer lg:drawer-open">
  <input id="wiki-drawer" type="checkbox" class="drawer-toggle" />

  <div class="drawer-content flex flex-col bg-base-200 h-[calc(100dvh-3rem)]">
    <!-- No internal navbar — straight to content -->
    <div class="flex flex-1 overflow-hidden">
      <main class="flex-1 overflow-y-auto bg-base-100">
        <!-- wiki content -->
      </main>
    </div>
  </div>

  <div class="drawer-side z-40 h-[calc(100dvh-3rem)] top-12">
    <label for="wiki-drawer" class="drawer-overlay"></label>
    <!-- sidebar content, back-to-home link removed (Pearl logo handles this) -->
  </div>
</div>
```

Key changes:
- `h-[calc(100dvh-3rem)]` on both `drawer-content` and `drawer-side`
- `top-12` on `drawer-side` so sidebar starts below navbar
- `z-40` on `drawer-side` so navbar's `z-50` stays above
- "Back to Home" link removed from sidebar — "Pearl" wordmark in navbar handles this

## Settings Page

Placeholder LiveView at `/settings`:

```elixir
defmodule PearlWeb.SettingsLive do
  use PearlWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(drawer_id: nil, breadcrumb: "Settings", show_ask: false)
     |> assign(page_title: "Settings")}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto py-8 px-4">
      <h1 class="text-2xl font-bold mb-4">Settings</h1>
      <p class="text-base-content/60">Settings coming soon.</p>
    </div>
    """
  end
end
```

## Files to Change

| File | Action | What changes |
|------|--------|-------------|
| `lib/pearl_web/components/layouts.ex` | Edit | Rewrite `app/1` with new navbar (attrs: `drawer_id`, `breadcrumb`, `show_ask`, `search_results`) |
| `lib/pearl_web/router.ex` | Edit | Wrap routes in `live_session` with `layout:` and `on_mount:` |
| `lib/pearl_web/live/navbar_hook.ex` | Create | Shared hook for search event handling |
| `lib/pearl_web/live/home_live.ex` | Edit | Remove inline `<header>`, add layout assigns in mount |
| `lib/pearl_web/live/wiki_live.ex` | Edit | Remove internal mobile navbar, add layout assigns in mount, adjust drawer height/z-index |
| `lib/pearl_web/live/settings_live.ex` | Create | Placeholder settings page |
| `lib/pearl/repositories/repositories.ex` | Edit | Add `search/1` function for querying repos by name/owner |

No changes needed to: `root.html.heex`, `app.css`, `core_components.ex`, or any Ecto schemas.
