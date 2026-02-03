defmodule PearlWeb.HomeLive do
  use PearlWeb, :live_view

  alias Pearl.Repositories

  @impl true
  def mount(_params, _session, socket) do
    repos = Repositories.list_repos()

    {:ok,
     assign(socket,
       page_title: "Pearl",
       repos: repos,
       repo_url: "",
       generating: false,
       progress: nil,
       error: nil,
       confirm_delete_id: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <div class="max-w-4xl mx-auto py-12 px-4">
        <header class="text-center mb-12">
          <h1 class="text-4xl font-bold mb-2">Pearl</h1>
          <p class="opacity-70">Inspired by DeepWiki: generate excellent wikis from your code.</p>
        </header>

        <div class="card bg-base-100 shadow-md mb-8">
          <div class="card-body">
            <form phx-submit="generate" class="space-y-6">
              <div class="form-control">
                <label for="repo_url" class="label">
                  <span class="label-text">Repository URL</span>
                </label>
                <input
                  type="url"
                  name="repo_url"
                  id="repo_url"
                  value={@repo_url}
                  placeholder="https://github.com/owner/repo"
                  class="input input-bordered w-full"
                  required
                />
              </div>

              <%= if @error do %>
                <div role="alert" class="alert alert-error">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 shrink-0 stroke-current" fill="none" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <span><%= @error %></span>
                </div>
              <% end %>

              <%= if @progress do %>
                <div role="alert" class="alert alert-info">
                  <span class="loading loading-spinner"></span>
                  <span><%= @progress %></span>
                </div>
              <% end %>

              <button type="submit" disabled={@generating} class="btn btn-primary w-full">
                <%= if @generating, do: "Generating...", else: "Generate Wiki" %>
              </button>
            </form>
          </div>
        </div>

        <%= if length(@repos) > 0 do %>
          <div class="card bg-base-100 shadow-md">
            <div class="card-body">
              <h2 class="card-title">Recent Repositories</h2>
              <ul class="divide-y divide-base-200">
                <%= for repo <- @repos do %>
                  <li class="py-3">
                    <div class="flex items-center justify-between hover:bg-base-200 -mx-3 px-3 py-2 rounded">
                      <.link navigate={~p"/wiki/#{repo.id}"} class="flex-1">
                        <div>
                          <span class="font-medium link link-primary"><%= repo.owner %>/<%= repo.name %></span>
                          <%= if repo.embedding_model do %>
                            <span class="ml-2 badge badge-ghost badge-sm"><%= repo.embedding_model %></span>
                          <% end %>
                        </div>
                      </.link>
                      <div class="flex items-center gap-2">
                        <span class={"badge #{status_badge(repo.status)}"}><%= repo.status %></span>
                        <%= if @confirm_delete_id == repo.id do %>
                          <button phx-click="confirm_delete" phx-value-id={repo.id} class="btn btn-error btn-xs">Delete</button>
                          <button phx-click="cancel_delete" class="btn btn-ghost btn-xs">Cancel</button>
                        <% else %>
                          <button
                            phx-click="request_delete"
                            phx-value-id={repo.id}
                            class="btn btn-ghost btn-xs text-error hover:bg-error hover:text-error-content"
                            disabled={repo.status in ["cloning", "analyzing"]}
                          >
                            <.icon name="hero-trash" class="size-4" />
                          </button>
                        <% end %>
                      </div>
                    </div>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("generate", %{"repo_url" => url}, socket) do
    socket =
      socket
      |> assign(generating: true, progress: "Starting...", error: nil, repo_url: url)

    # Start async generation
    pid = self()

    Task.start(fn ->
      result = do_generate(url, fn msg -> send(pid, {:progress, msg}) end)
      send(pid, {:generation_complete, result})
    end)

    {:noreply, socket}
  end

  def handle_event("request_delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, confirm_delete_id: String.to_integer(id))}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, confirm_delete_id: nil)}
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    repo_id = String.to_integer(id)

    case Repositories.get_repo(repo_id) do
      nil ->
        {:noreply, socket |> assign(confirm_delete_id: nil) |> put_flash(:error, "Repository not found")}

      repo ->
        case Repositories.delete_repo(repo) do
          {:ok, deleted} ->
            {:noreply,
             socket
             |> assign(repos: Enum.reject(socket.assigns.repos, &(&1.id == repo_id)), confirm_delete_id: nil)
             |> put_flash(:info, "Deleted #{deleted.owner}/#{deleted.name}")}

          {:error, _} ->
            {:noreply, socket |> assign(confirm_delete_id: nil) |> put_flash(:error, "Failed to delete repository")}
        end
    end
  end

  @impl true
  def handle_info({:progress, message}, socket) do
    {:noreply, assign(socket, progress: message)}
  end

  @impl true
  def handle_info({:generation_complete, {:ok, repo}}, socket) do
    {:noreply,
     socket
     |> assign(generating: false, progress: nil)
     |> push_navigate(to: ~p"/wiki/#{repo.id}")}
  end

  @impl true
  def handle_info({:generation_complete, {:error, reason}}, socket) do
    error_message =
      case reason do
        {:clone_failed, msg} -> "Clone failed: #{msg}"
        {:indexing_failed, msg} -> "Indexing failed: #{inspect(msg)}"
        {:generation_failed, msg} -> "Wiki generation failed: #{inspect(msg)}"
        :no_api_key -> "API key not configured for selected provider"
        msg when is_binary(msg) -> msg
        msg -> "Error: #{inspect(msg)}"
      end

    {:noreply,
     assign(socket,
       generating: false,
       progress: nil,
       error: error_message
     )}
  end

  defp do_generate(url, on_progress) do
    on_progress.("Validating repository URL...")

    case Repositories.clone(url) do
      {:ok, repo} ->
        on_progress.("Repository cloned. Indexing for RAG...")

        case Pearl.Rag.index_repo(repo) do
          {:ok, count} ->
            on_progress.("Indexed #{count} chunks. Generating wiki...")

            case Pearl.Wiki.generate(repo, on_progress) do
              {:ok, _} -> {:ok, repo}
              {:error, reason} -> {:error, {:generation_failed, reason}}
            end

          {:error, reason} ->
            {:error, {:indexing_failed, reason}}
        end

      {:error, {:clone_failed, output}} ->
        {:error, {:clone_failed, "Git clone failed: #{String.slice(output, 0, 200)}"}}

      {:error, :invalid_url} ->
        {:error, "Invalid repository URL format"}

      {:error, :unsupported_provider} ->
        {:error, "Only GitHub, GitLab, and Bitbucket URLs are supported"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp status_badge("ready"), do: "badge-success"
  defp status_badge("cloning"), do: "badge-warning"
  defp status_badge("analyzing"), do: "badge-info"
  defp status_badge("failed"), do: "badge-error"
  defp status_badge(_), do: "badge-neutral"
end
