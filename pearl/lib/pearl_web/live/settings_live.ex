defmodule PearlWeb.SettingsLive do
  @moduledoc """
  Placeholder settings page.
  """
  use PearlWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Settings",
       drawer_id: nil,
       breadcrumb: "Settings",
       show_ask: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto py-8 px-4">
      <h1 class="text-2xl font-bold mb-4">Settings</h1>
      <p class="text-base-content/60">Settings coming soon.</p>
    </div>
    """
  end
end
