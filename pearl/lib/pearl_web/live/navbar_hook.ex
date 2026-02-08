defmodule PearlWeb.NavbarHook do
  @moduledoc """
  Shared on_mount hook that provides navbar search functionality to all LiveViews.

  Assigns `search_results` and `search_query` on mount, and intercepts the
  "search" event from the navbar search form.
  """
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(search_results: [], search_query: "", search_form: to_form(%{"q" => ""}, as: :search))
      |> attach_hook(:navbar_search, :handle_event, &handle_event/3)

    {:cont, socket}
  end

  defp handle_event("search", %{"search" => %{"q" => ""}}, socket) do
    {:halt, assign(socket, search_results: [], search_query: "", search_form: to_form(%{"q" => ""}, as: :search))}
  end

  defp handle_event("search", %{"search" => %{"q" => query}}, socket) do
    results = Pearl.Repositories.search(query)
    {:halt, assign(socket, search_results: results, search_query: query, search_form: to_form(%{"q" => query}, as: :search))}
  end

  defp handle_event(_event, _params, socket), do: {:cont, socket}
end
