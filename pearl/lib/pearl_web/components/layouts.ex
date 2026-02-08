defmodule PearlWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use PearlWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :drawer_id, :string, default: nil, doc: "drawer checkbox ID (for wiki mobile hamburger)"
  attr :breadcrumb, :string, default: nil, doc: "breadcrumb text shown after Pearl wordmark"
  attr :show_ask, :boolean, default: false, doc: "whether to show the Ask button"
  attr :search_form, :map, default: nil, doc: "search form created via to_form/2"
  attr :search_results, :list, default: [], doc: "list of repo search results"
  attr :search_query, :string, default: "", doc: "current search query for input persistence"

  def app(assigns) do
    ~H"""
    <header class="navbar h-12 min-h-12 bg-base-100 border-b border-base-content/8 px-4 sticky top-0 z-50">
      <div class="navbar-start gap-2">
        <label :if={@drawer_id} for={@drawer_id} class="btn btn-ghost btn-sm btn-square lg:hidden">
          <.icon name="hero-bars-3" class="size-5" />
        </label>

        <.link
          navigate={~p"/"}
          class="font-semibold tracking-wider uppercase text-sm text-base-content/70 hover:text-primary transition-colors"
        >
          Pearl
        </.link>
        <span :if={@breadcrumb} class="text-base-content/20">/</span>
        <span :if={@breadcrumb} class="text-sm font-medium truncate max-w-48">{@breadcrumb}</span>
      </div>

      <div class="navbar-end gap-1">
        <div class="relative hidden sm:block mr-2">
          <.form for={@search_form} id="navbar-search" phx-change="search" phx-submit="search" phx-debounce="300">
            <.icon
              name="hero-magnifying-glass"
              class="size-4 absolute left-3 top-1/2 -translate-y-1/2 text-base-content/30"
            />
            <input
              type="text"
              name={@search_form[:q].name}
              value={@search_form[:q].value}
              placeholder="Search repos..."
              class="input input-sm bg-base-200/50 border-base-content/10 pl-9 w-56 focus:w-72 transition-all duration-200 text-sm"
            />
          </.form>
          <ul
            :if={@search_results != []}
            class="menu bg-base-200 rounded-box absolute top-full mt-1 w-72 p-2 shadow-lg border border-base-content/10 z-50"
          >
            <li :for={repo <- @search_results}>
              <.link navigate={~p"/wiki/#{repo.id}"}>{repo.owner}/{repo.name}</.link>
            </li>
          </ul>
        </div>

        <%!-- Mobile search button hidden until mobile search is implemented --%>

        <button
          :if={@show_ask}
          phx-click="toggle_ask"
          class="btn btn-ghost btn-sm gap-1.5 text-base-content/60 hover:text-primary"
        >
          <.icon name="hero-chat-bubble-left-right" class="size-4" />
          <span class="hidden md:inline text-xs">Ask</span>
        </button>

        <div class="dropdown dropdown-end">
          <div tabindex="0" role="button" class="btn btn-ghost btn-sm btn-circle">
            <.icon name="hero-cog-6-tooth" class="size-4" />
          </div>
          <ul
            tabindex="0"
            class="dropdown-content menu bg-base-200 rounded-box z-[1] w-48 p-2 shadow-lg border border-base-content/10 mt-2"
          >
            <li>
              <.link navigate={~p"/settings"}>
                <.icon name="hero-adjustments-horizontal" class="size-4" /> Settings
              </.link>
            </li>
          </ul>
        </div>
      </div>
    </header>

    {@inner_content}

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
