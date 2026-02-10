defmodule PearlWeb.SettingsLive do
  @moduledoc """
  LiveView for managing Pearl application settings.

  Provides UI for configuring LLM providers, models, performance tuning,
  and storage paths. Handles embedding model changes by prompting for
  repository re-indexing.
  """
  use PearlWeb, :live_view

  alias Pearl.Settings

  @impl true
  def mount(_params, _session, socket) do
    # Build reindex_topic only when connected - nil during static render is intentional.
    # The topic is only used by handle_event/handle_info callbacks which require a connection.
    reindex_topic =
      if connected?(socket) do
        session_id = get_connect_params(socket)["_session_id"] || Ecto.UUID.generate()
        topic = "settings:reindex:#{session_id}"
        Phoenix.PubSub.subscribe(Pearl.PubSub, topic)
        topic
      end

    settings = Settings.all()

    resolved_path = Path.expand(settings["repos_path"])

    {:ok,
     assign(socket,
       page_title: "Settings",
       drawer_id: nil,
       breadcrumb: "Settings",
       show_ask: false,
       settings: settings,
       initial_settings: settings,
       form: to_form(settings_changeset(settings), as: :settings),
       dirty: false,
       openrouter_key_set: env_var_set?(settings["openrouter_api_key_env"]),
       ollama_host_set: env_var_set?(settings["ollama_host_env"]),
       resolved_path: resolved_path,
       path_exists: File.dir?(resolved_path),
       reindex_topic: reindex_topic
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <div class="max-w-3xl mx-auto py-12 px-4 space-y-8">
        <div class="animate-fade-up">
          <h1 class="text-2xl font-bold tracking-tight">Settings</h1>
          <p class="text-base-content/50 text-sm mt-1">
            Configure LLM providers, performance tuning, and storage paths.
          </p>
        </div>

        <.form for={@form} phx-change="validate" phx-submit="save">
          <%!-- Card 1: LLM Providers --%>
          <div class="card bg-base-100 shadow-md animate-fade-up" style="animation-delay: 75ms">
            <div class="card-body">
              <h2 class="card-title text-lg">
                <.icon name="hero-cpu-chip" class="size-5 text-primary" /> LLM Providers
              </h2>
              <p class="text-sm text-base-content/50 -mt-1">
                Select which providers and models to use for wiki generation and embeddings.
              </p>

              <div class="divider my-2"></div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <%!-- Chat / Generation --%>
                <fieldset>
                  <legend class="text-xs font-semibold uppercase tracking-wider text-base-content/40 mb-3">
                    Chat / Generation
                  </legend>

                  <div class="form-control mb-3">
                    <label class="label" for="chat_provider">
                      <span class="label-text text-sm">Provider</span>
                    </label>
                    <select
                      name="settings[chat_provider]"
                      id="chat_provider"
                      class="select select-bordered select-sm w-full"
                    >
                      <option value="openrouter" selected={@settings["chat_provider"] == "openrouter"}>
                        OpenRouter
                      </option>
                      <option value="ollama" selected={@settings["chat_provider"] == "ollama"}>
                        Ollama (Local)
                      </option>
                    </select>
                  </div>

                  <div class="form-control">
                    <label class="label" for="chat_model">
                      <span class="label-text text-sm">Model</span>
                    </label>
                    <input
                      type="text"
                      name="settings[chat_model]"
                      id="chat_model"
                      value={@settings["chat_model"]}
                      placeholder="e.g. openai/gpt-5.2"
                      class="input input-bordered input-sm w-full font-mono text-xs"
                      phx-debounce="500"
                    />
                  </div>
                </fieldset>

                <%!-- Embeddings --%>
                <fieldset>
                  <legend class="text-xs font-semibold uppercase tracking-wider text-base-content/40 mb-3">
                    Embeddings
                  </legend>

                  <div class="form-control mb-3">
                    <label class="label" for="embedding_provider">
                      <span class="label-text text-sm">Provider</span>
                    </label>
                    <select
                      name="settings[embedding_provider]"
                      id="embedding_provider"
                      class="select select-bordered select-sm w-full"
                    >
                      <option
                        value="openrouter"
                        selected={@settings["embedding_provider"] == "openrouter"}
                      >
                        OpenRouter
                      </option>
                      <option value="ollama" selected={@settings["embedding_provider"] == "ollama"}>
                        Ollama (Local)
                      </option>
                    </select>
                  </div>

                  <div class="form-control">
                    <label class="label" for="embedding_model">
                      <span class="label-text text-sm">Model</span>
                    </label>
                    <input
                      type="text"
                      name="settings[embedding_model]"
                      id="embedding_model"
                      value={@settings["embedding_model"]}
                      placeholder="e.g. openai/text-embedding-3-small"
                      class="input input-bordered input-sm w-full font-mono text-xs"
                      phx-debounce="500"
                    />
                  </div>
                </fieldset>
              </div>

              <div class="divider my-2"></div>

              <%!-- Credentials --%>
              <div>
                <h3 class="text-xs font-semibold uppercase tracking-wider text-base-content/40 mb-3">
                  Provider Credentials
                </h3>
                <p class="text-xs text-base-content/40 mb-4">
                  Pearl reads API keys from environment variables. Configure which env var names to look up.
                </p>

                <div class="space-y-3">
                  <div class="flex items-end gap-3">
                    <div class="form-control flex-1">
                      <label class="label" for="openrouter_api_key_env">
                        <span class="label-text text-sm">OpenRouter API Key</span>
                      </label>
                      <input
                        type="text"
                        name="settings[openrouter_api_key_env]"
                        id="openrouter_api_key_env"
                        value={@settings["openrouter_api_key_env"]}
                        class="input input-bordered input-sm w-full font-mono text-xs"
                        phx-debounce="500"
                      />
                    </div>
                    <div class="pb-1">
                      <span
                        :if={@openrouter_key_set}
                        class="badge badge-success badge-sm gap-1"
                      >
                        <.icon name="hero-check-circle-mini" class="size-3" /> Set
                      </span>
                      <span
                        :if={!@openrouter_key_set}
                        class="badge badge-warning badge-sm gap-1"
                      >
                        <.icon name="hero-exclamation-triangle-mini" class="size-3" /> Not set
                      </span>
                    </div>
                  </div>

                  <div class="flex items-end gap-3">
                    <div class="form-control flex-1">
                      <label class="label" for="ollama_host_env">
                        <span class="label-text text-sm">Ollama Host</span>
                      </label>
                      <input
                        type="text"
                        name="settings[ollama_host_env]"
                        id="ollama_host_env"
                        value={@settings["ollama_host_env"]}
                        class="input input-bordered input-sm w-full font-mono text-xs"
                        phx-debounce="500"
                      />
                    </div>
                    <div class="pb-1">
                      <span
                        :if={@ollama_host_set}
                        class="badge badge-success badge-sm gap-1"
                      >
                        <.icon name="hero-check-circle-mini" class="size-3" /> Set
                      </span>
                      <span
                        :if={!@ollama_host_set}
                        class="badge badge-warning badge-sm gap-1"
                      >
                        <.icon name="hero-exclamation-triangle-mini" class="size-3" /> Not set
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Card 2: Performance --%>
          <div class="card bg-base-100 shadow-md animate-fade-up mt-8" style="animation-delay: 150ms">
            <div class="card-body">
              <h2 class="card-title text-lg">
                <.icon name="hero-bolt" class="size-5 text-primary" /> Performance
              </h2>
              <p class="text-sm text-base-content/50 -mt-1">
                Tune concurrency and timeout parameters for wiki generation.
              </p>

              <div class="divider my-2"></div>

              <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
                <div class="form-control">
                  <label class="label" for="embedding_batch_size">
                    <span class="label-text text-sm">Embedding Batch Size</span>
                  </label>
                  <input
                    type="number"
                    name="settings[embedding_batch_size]"
                    id="embedding_batch_size"
                    value={@form[:embedding_batch_size].value}
                    min="1"
                    max="500"
                    phx-debounce="300"
                    class={[
                      "input input-bordered input-sm w-full",
                      @form[:embedding_batch_size].errors != [] && "input-error"
                    ]}
                  />
                  <label class="label">
                    <span
                      :if={@form[:embedding_batch_size].errors == []}
                      class="label-text-alt text-base-content/30"
                    >
                      1 – 500 chunks per batch
                    </span>
                    <span
                      :for={error <- @form[:embedding_batch_size].errors}
                      class="label-text-alt text-error"
                    >
                      {translate_error(error)}
                    </span>
                  </label>
                </div>

                <div class="form-control">
                  <label class="label" for="file_read_concurrency">
                    <span class="label-text text-sm">File Read Concurrency</span>
                  </label>
                  <input
                    type="number"
                    name="settings[file_read_concurrency]"
                    id="file_read_concurrency"
                    value={@form[:file_read_concurrency].value}
                    min="1"
                    max="100"
                    phx-debounce="300"
                    class={[
                      "input input-bordered input-sm w-full",
                      @form[:file_read_concurrency].errors != [] && "input-error"
                    ]}
                  />
                  <label class="label">
                    <span
                      :if={@form[:file_read_concurrency].errors == []}
                      class="label-text-alt text-base-content/30"
                    >
                      1 – 100 concurrent reads
                    </span>
                    <span
                      :for={error <- @form[:file_read_concurrency].errors}
                      class="label-text-alt text-error"
                    >
                      {translate_error(error)}
                    </span>
                  </label>
                </div>

                <div class="form-control">
                  <label class="label" for="wiki_page_timeout">
                    <span class="label-text text-sm">Page Timeout</span>
                  </label>
                  <div class="join w-full">
                    <input
                      type="number"
                      name="settings[wiki_page_timeout]"
                      id="wiki_page_timeout"
                      value={@form[:wiki_page_timeout].value}
                      min="10000"
                      max="600000"
                      step="1000"
                      phx-debounce="300"
                      class={[
                        "input input-bordered input-sm join-item w-full",
                        @form[:wiki_page_timeout].errors != [] && "input-error"
                      ]}
                    />
                    <span class="btn btn-sm btn-disabled join-item border-base-content/20 bg-base-200 text-base-content/40 no-animation">
                      ms
                    </span>
                  </div>
                  <label class="label">
                    <span
                      :if={@form[:wiki_page_timeout].errors == []}
                      class="label-text-alt text-base-content/30"
                    >
                      10s – 600s per wiki page
                    </span>
                    <span
                      :for={error <- @form[:wiki_page_timeout].errors}
                      class="label-text-alt text-error"
                    >
                      {translate_error(error)}
                    </span>
                  </label>
                </div>
              </div>
            </div>
          </div>

          <%!-- Card 3: Storage --%>
          <div class="card bg-base-100 shadow-md animate-fade-up mt-8" style="animation-delay: 225ms">
            <div class="card-body">
              <h2 class="card-title text-lg">
                <.icon name="hero-folder-open" class="size-5 text-primary" /> Storage
              </h2>
              <p class="text-sm text-base-content/50 -mt-1">
                Where cloned repositories are stored on disk.
              </p>

              <div class="divider my-2"></div>

              <div class="form-control">
                <label class="label" for="repos_path">
                  <span class="label-text text-sm">Repository Storage Path</span>
                </label>
                <input
                  type="text"
                  name="settings[repos_path]"
                  id="repos_path"
                  value={@settings["repos_path"]}
                  placeholder="~/.pearl/repos"
                  class="input input-bordered input-sm w-full font-mono text-xs"
                  phx-debounce="500"
                />
              </div>

              <div class="mt-3 rounded-lg bg-base-200/60 border border-base-content/5 px-4 py-3">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-2 min-w-0">
                    <.icon name="hero-arrow-long-right" class="size-4 text-base-content/30 shrink-0" />
                    <span class="text-xs font-mono text-base-content/60 truncate">
                      {@resolved_path}
                    </span>
                  </div>
                  <span
                    :if={@path_exists}
                    class="badge badge-success badge-sm gap-1 shrink-0 ml-2"
                  >
                    <.icon name="hero-check-circle-mini" class="size-3" /> Exists
                  </span>
                  <span
                    :if={!@path_exists}
                    class="badge badge-warning badge-sm gap-1 shrink-0 ml-2"
                  >
                    <.icon name="hero-exclamation-triangle-mini" class="size-3" /> Not found
                  </span>
                </div>
              </div>
            </div>
          </div>

          <%!-- Footer --%>
          <div
            class="flex items-center justify-between animate-fade-up mt-8"
            style="animation-delay: 300ms"
          >
            <div>
              <p :if={@dirty} class="text-xs text-warning flex items-center gap-1.5">
                <.icon name="hero-exclamation-circle-mini" class="size-4" /> You have unsaved changes.
              </p>
            </div>
            <button type="submit" class="btn btn-primary" disabled={!@dirty}>
              <.icon name="hero-check" class="size-4" /> Save Settings
            </button>
          </div>
        </.form>

        <%!-- Re-index Modal --%>
        <dialog id="reindex-modal" class="modal">
          <div class="modal-box max-w-md">
            <h3 class="text-lg font-bold flex items-center gap-2">
              <.icon name="hero-exclamation-triangle" class="size-5 text-warning" />
              Re-indexing Required
            </h3>
            <p class="py-4 text-sm text-base-content/70">
              You changed the embedding provider or model. Existing embeddings are incompatible
              with the new configuration and repositories will need to be re-indexed for
              RAG search to work correctly.
            </p>

            <div class="divider my-0"></div>

            <div class="modal-action flex-col sm:flex-row gap-2">
              <button
                type="button"
                phx-click="save_and_reindex"
                class="btn btn-warning w-full sm:w-auto"
              >
                <.icon name="hero-arrow-path" class="size-4" /> Save &amp; Re-index All
              </button>
              <button
                type="button"
                phx-click="save_without_reindex"
                class="btn btn-ghost w-full sm:w-auto"
              >
                Save Without Re-indexing
              </button>
            </div>

            <form method="dialog" class="absolute top-4 right-4">
              <button class="btn btn-ghost btn-sm btn-circle">
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </form>
          </div>
          <form method="dialog" class="modal-backdrop">
            <button>close</button>
          </form>
        </dialog>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"settings" => params}, socket) do
    settings = Map.merge(socket.assigns.settings, params)
    dirty = settings != socket.assigns.initial_settings
    changeset = settings_changeset(settings, :validate)

    # Only expand path if it changed to avoid redundant work
    {resolved_path, path_exists} =
      if settings["repos_path"] == socket.assigns.settings["repos_path"] do
        {socket.assigns.resolved_path, socket.assigns.path_exists}
      else
        expanded = Path.expand(settings["repos_path"])
        {expanded, File.dir?(expanded)}
      end

    # Only check env vars if the field actually changed
    openrouter_key_set =
      if settings["openrouter_api_key_env"] == socket.assigns.settings["openrouter_api_key_env"] do
        socket.assigns.openrouter_key_set
      else
        env_var_set?(settings["openrouter_api_key_env"])
      end

    ollama_host_set =
      if settings["ollama_host_env"] == socket.assigns.settings["ollama_host_env"] do
        socket.assigns.ollama_host_set
      else
        env_var_set?(settings["ollama_host_env"])
      end

    {:noreply,
     assign(socket,
       settings: settings,
       form: to_form(changeset, as: :settings),
       dirty: dirty,
       openrouter_key_set: openrouter_key_set,
       ollama_host_set: ollama_host_set,
       resolved_path: resolved_path,
       path_exists: path_exists
     )}
  end

  @impl true
  def handle_event("save", %{"settings" => params}, socket) do
    settings = Map.merge(socket.assigns.settings, params)

    if embedding_config_changed?(settings, socket.assigns.initial_settings) do
      {:noreply,
       socket
       |> assign(settings: settings)
       |> push_event("show-modal", %{id: "reindex-modal"})}
    else
      {_status, socket} = do_save(socket, settings)
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save_and_reindex", _params, socket) do
    case do_save(socket, socket.assigns.settings) do
      {:ok, saved_socket} ->
        reindex_topic = socket.assigns.reindex_topic

        # Intentionally unlinked: task failure shouldn't crash the LiveView process.
        # The task runs in the background and reports progress via PubSub to reindex_topic.
        case Task.Supervisor.start_child(
               Pearl.TaskSupervisor,
               fn -> __MODULE__.reindex_repos_task(reindex_topic) end
             ) do
          {:ok, _pid} ->
            {:noreply,
             put_flash(saved_socket, :info, "Settings saved. Re-indexing started in background.")}

          {:error, reason} ->
            {:noreply,
             put_flash(
               saved_socket,
               :error,
               "Settings saved, but failed to start re-indexing: #{inspect(reason)}"
             )}
        end

      {:error, socket} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save_without_reindex", _params, socket) do
    {_status, socket} = do_save(socket, socket.assigns.settings)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:reindex_complete, socket) do
    {:noreply, put_flash(socket, :info, "Re-indexing completed successfully.")}
  end

  @impl true
  def handle_info({:reindex_failed, errors}, socket) do
    error_msg = "Re-indexing failed for: " <> Enum.join(errors, "; ")
    {:noreply, put_flash(socket, :error, error_msg)}
  end

  @impl true
  def handle_info({:reindex_progress, repo_name, current, total}, socket) do
    msg = "Re-indexing #{repo_name} (#{current}/#{total})..."
    {:noreply, put_flash(socket, :info, msg)}
  end

  # Catch-all for unexpected messages (e.g., PubSub noise).
  # Note: start_child tasks are unlinked so no :DOWN messages are received here.
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # Maps numeric setting fields to their valid {min, max} range for validation.
  @numeric_fields %{
    embedding_batch_size: {1, 500},
    file_read_concurrency: {1, 100},
    wiki_page_timeout: {10_000, 600_000}
  }

  defp do_save(socket, settings) do
    changeset = settings_changeset(settings, :save)

    if changeset.valid? do
      settings_list =
        settings
        |> Enum.filter(fn {key, _value} -> Settings.valid_key?(key) end)
        |> Enum.to_list()

      case Settings.put_all(settings_list) do
        :ok ->
          {:ok,
           socket
           |> assign(
             settings: settings,
             initial_settings: settings,
             form: to_form(changeset, as: :settings),
             dirty: false
           )
           |> put_flash(:info, "Settings saved.")}

        {:error, _name, _changeset, _changes} ->
          {:error, put_flash(socket, :error, "Failed to save settings.")}

        {:error, :unknown_key, _key} ->
          {:error, put_flash(socket, :error, "Failed to save settings.")}
      end
    else
      # Errors are shown inline via the form, no flash needed
      {:error, assign(socket, form: to_form(changeset, as: :settings))}
    end
  end

  # All settings keys for the schemaless changeset
  @all_settings_types %{
    chat_provider: :string,
    chat_model: :string,
    embedding_provider: :string,
    embedding_model: :string,
    openrouter_api_key_env: :string,
    ollama_host_env: :string,
    embedding_batch_size: :integer,
    file_read_concurrency: :integer,
    wiki_page_timeout: :integer,
    repos_path: :string
  }

  defp settings_changeset(settings), do: settings_changeset(settings, nil)

  defp settings_changeset(settings, action) do
    # Convert string keys to atoms and include all settings
    data =
      for {field, _} <- @all_settings_types, into: %{} do
        {field, settings[to_string(field)]}
      end

    changeset =
      {%{}, @all_settings_types}
      |> Ecto.Changeset.cast(data, Map.keys(@all_settings_types))
      |> then(fn changeset ->
        Enum.reduce(@numeric_fields, changeset, fn {field, {min, max}}, cs ->
          msg = "must be between #{min} and #{max}"

          cs
          |> Ecto.Changeset.validate_required([field], message: msg)
          |> Ecto.Changeset.validate_number(field,
            greater_than_or_equal_to: min,
            less_than_or_equal_to: max,
            message: msg
          )
        end)
      end)

    if action, do: Map.put(changeset, :action, action), else: changeset
  end

  defp env_var_set?(env_var_name) when is_binary(env_var_name) do
    System.get_env(env_var_name) != nil
  end

  defp env_var_set?(_), do: false

  defp embedding_config_changed?(current, initial) do
    current["embedding_provider"] != initial["embedding_provider"] or
      current["embedding_model"] != initial["embedding_model"]
  end

  # Task entry point for Task.Supervisor.start_child - re-indexes all ready repos
  @doc false
  @spec reindex_repos_task(String.t()) :: :ok
  def reindex_repos_task(topic) do
    repos =
      Pearl.Repositories.list_repos()
      |> Enum.filter(&(&1.status == Pearl.Repositories.RepoRecord.status_ready()))

    case reindex_repos_sequentially(repos, topic) do
      {:ok, :ok} ->
        Phoenix.PubSub.broadcast(Pearl.PubSub, topic, :reindex_complete)

      {:ok, {:errors, errors}} ->
        error_messages = Enum.map(errors, fn {name, msg} -> "#{name}: #{msg}" end)

        Phoenix.PubSub.broadcast(
          Pearl.PubSub,
          topic,
          {:reindex_failed, error_messages}
        )
    end

    :ok
  end

  # Process repos sequentially without transaction - LLM API calls should not hold DB locks
  # Collects all errors instead of stopping at the first one
  # Each repo has a 5-minute timeout to prevent hanging on slow LLM calls
  @reindex_timeout_ms :timer.minutes(5)

  defp reindex_repos_sequentially(repos, topic) do
    total = length(repos)

    errors =
      repos
      |> Enum.with_index(1)
      |> Enum.reduce([], fn {repo, index}, errors ->
        Phoenix.PubSub.broadcast(
          Pearl.PubSub,
          topic,
          {:reindex_progress, repo.name, index, total}
        )

        task =
          Task.Supervisor.async_nolink(Pearl.TaskSupervisor, fn ->
            Pearl.Rag.index_repo(repo)
          end)

        try do
          case Task.yield(task, @reindex_timeout_ms) || Task.shutdown(task) do
            {:ok, {:ok, _count}} ->
              errors

            {:ok, {:error, reason}} ->
              [{repo.name, inspect(reason)} | errors]

            nil ->
              [{repo.name, "timeout after #{div(@reindex_timeout_ms, 60_000)} minutes"} | errors]
          end
        rescue
          e -> [{repo.name, Exception.message(e)} | errors]
        end
      end)

    case errors do
      [] -> {:ok, :ok}
      _ -> {:ok, {:errors, Enum.reverse(errors)}}
    end
  end
end
