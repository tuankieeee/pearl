defmodule PearlWeb.WikiLive do
  @moduledoc """
  LiveView for displaying generated wikis with RAG-powered Q&A chat panel.
  """
  use PearlWeb, :live_view

  alias Pearl.Repositories
  alias Pearl.Wiki
  alias Pearl.Rag
  alias PearlWeb.MarkdownComponent

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    with {int_id, ""} <- Integer.parse(id),
         %{} = repo <- Repositories.get_repo(int_id) do
      wiki_cache = Wiki.get_cached(repo)

      pages = if wiki_cache, do: wiki_cache.structure["pages"] || [], else: []
      current_page_id = if length(pages) > 0, do: hd(pages)["id"], else: nil

      {:ok,
       assign(socket,
         page_title: "#{repo.owner}/#{repo.name} - Pearl",
         repo: repo,
         wiki_cache: wiki_cache,
         pages: pages,
         current_page_id: current_page_id,
         current_content: get_page_content(wiki_cache, current_page_id),
         ask_open: false,
         ask_messages: [],
         ask_current_input: "",
         ask_loading: false
       )}
    else
      _ -> raise Ecto.NoResultsError, queryable: Repositories.RepoRecord
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open">
      <input id="wiki-drawer" type="checkbox" class="drawer-toggle" />
      
    <!-- Main content area -->
      <div class="drawer-content flex flex-col bg-base-200 h-screen">
        <!-- Mobile header with menu toggle -->
        <div class="navbar bg-base-100 lg:hidden border-b border-base-300">
          <div class="flex-none">
            <label for="wiki-drawer" class="btn btn-square btn-ghost drawer-button">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                class="inline-block h-5 w-5 stroke-current"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M4 6h16M4 12h16M4 18h16"
                />
              </svg>
            </label>
          </div>
          <div class="flex-1">
            <span class="font-semibold truncate">{@repo.owner}/{@repo.name}</span>
          </div>
          <div class="flex-none">
            <button phx-click="toggle_ask" class="btn btn-ghost btn-sm">
              Ask
            </button>
          </div>
        </div>
        
    <!-- Content wrapper -->
        <div class="flex flex-1 overflow-hidden">
          <!-- Main content -->
          <main class="flex-1 overflow-y-auto bg-base-100">
            <%= if @wiki_cache do %>
              <div class="max-w-4xl mx-auto py-8 px-8">
                <MarkdownComponent.markdown id="wiki-content" content={@current_content} />
              </div>
            <% else %>
              <div class="flex items-center justify-center h-full">
                <div class="text-center opacity-60">
                  <p class="text-lg mb-2">No wiki generated yet</p>
                  <.link navigate={~p"/"} class="link link-primary">
                    Generate one now
                  </.link>
                </div>
              </div>
            <% end %>
          </main>
          
    <!-- Ask panel (slide-out) -->
          <%= if @ask_open do %>
            <aside class="w-[36rem] bg-gradient-to-b from-base-100 to-base-200 border-l border-base-300/50 flex flex-col">
              <div class="px-5 py-4 border-b border-primary/20 bg-gradient-to-r from-primary/5 to-transparent flex items-center justify-between">
                <h3 class="text-sm font-semibold tracking-wide uppercase text-primary/80 font-[family-name:var(--font-heading)]">
                  Ask about the codebase
                </h3>
                <button
                  phx-click="toggle_ask"
                  class="btn btn-ghost btn-sm btn-circle text-base-content/50 hover:text-base-content"
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </button>
              </div>

              <div class="flex-1 overflow-y-auto p-5" id="ask-messages" phx-hook="ScrollToBottom">
                <%= if @ask_messages == [] do %>
                  <div class="flex items-center justify-center h-full">
                    <div class="text-center">
                      <.icon
                        name="hero-chat-bubble-left-right"
                        class="size-12 text-primary/20 mx-auto mb-4"
                      />
                      <p class="text-base-content/30 text-sm">Ask anything about the codebase</p>
                    </div>
                  </div>
                <% end %>
                <%= for {message, idx} <- Enum.with_index(@ask_messages) do %>
                  <%= if message.role == :user do %>
                    <div class="chat chat-end mb-4">
                      <div class="chat-bubble chat-bubble-primary">
                        {message.content}
                      </div>
                    </div>
                  <% else %>
                    <div class="mb-4">
                      <div class="rounded-lg bg-base-300/50 border-l-2 border-primary/40 px-4 py-3">
                        <%= if message.content == "" and @ask_loading do %>
                          <span class="loading loading-dots loading-sm text-primary/60"></span>
                        <% else %>
                          <MarkdownComponent.markdown
                            id={"ask-msg-#{idx}"}
                            content={message.content}
                            class="prose-sm [&_pre]:overflow-x-auto [&_pre]:max-w-full [&_code]:text-xs"
                          />
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>

              <div class="p-4 border-t border-primary/20 bg-base-200/50">
                <form phx-submit="ask" class="flex gap-3 items-center">
                  <input
                    type="text"
                    name="question"
                    value={@ask_current_input}
                    placeholder="Ask anything about this codebase..."
                    id="ask-input"
                    class="input input-bordered flex-1 bg-base-300/50 focus:border-primary/50"
                    disabled={@ask_loading}
                    phx-debounce="300"
                    phx-hook="AutoFocus"
                  />
                  <button type="submit" disabled={@ask_loading} class="btn btn-primary btn-circle">
                    <%= if @ask_loading do %>
                      <span class="loading loading-spinner loading-sm"></span>
                    <% else %>
                      <.icon name="hero-paper-airplane" class="size-5" />
                    <% end %>
                  </button>
                </form>
              </div>
            </aside>
          <% end %>
        </div>
      </div>
      
    <!-- Sidebar -->
      <div class="drawer-side">
        <label for="wiki-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <aside class="bg-base-100 min-h-full w-64 flex flex-col border-r border-base-300">
          <div class="p-4 border-b border-base-300">
            <.link navigate={~p"/"} class="link link-hover text-sm opacity-60">
              ← Back to Home
            </.link>
            <h2 class="mt-2 font-semibold truncate">
              {@repo.owner}/{@repo.name}
            </h2>
          </div>

          <nav class="flex-1 overflow-y-auto p-2">
            <ul class="menu menu-sm">
              <%= for page <- @pages do %>
                <li>
                  <button
                    phx-click="select_page"
                    phx-value-id={page["id"]}
                    class={if @current_page_id == page["id"], do: "active", else: ""}
                  >
                    {page["title"]}
                  </button>
                </li>
              <% end %>
            </ul>
          </nav>

          <div class="p-4 border-t border-base-300">
            <button
              phx-click="toggle_ask"
              class="btn btn-ghost btn-sm w-full gap-2 text-base-content/60 hover:text-base-content"
            >
              <%= if @ask_open do %>
                <.icon name="hero-x-mark" class="size-4" /> Close Chat
              <% else %>
                <.icon name="hero-chat-bubble-left-right" class="size-4" /> Chat with AI
              <% end %>
            </button>
          </div>
        </aside>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_page", %{"id" => page_id}, socket) do
    valid_page_ids = Enum.map(socket.assigns.pages, & &1["id"])

    if page_id in valid_page_ids do
      content = get_page_content(socket.assigns.wiki_cache, page_id)
      {:noreply, assign(socket, current_page_id: page_id, current_content: content)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_ask", _params, socket) do
    {:noreply, assign(socket, ask_open: !socket.assigns.ask_open)}
  end

  @impl true
  def handle_event("ask", %{"question" => question}, socket)
      when is_binary(question) and question != "" do
    %{repo: repo} = socket.assigns

    # Add user message and placeholder assistant message
    messages =
      socket.assigns.ask_messages ++
        [
          %{role: :user, content: question},
          %{role: :assistant, content: ""}
        ]

    socket =
      assign(socket,
        ask_loading: true,
        ask_messages: messages,
        ask_current_input: ""
      )

    pid = self()

    # Get history (all messages except the last empty assistant placeholder)
    history =
      for msg <- socket.assigns.ask_messages, msg.content != "" do
        %{role: msg.role, content: msg.content}
      end

    # Linked to LiveView - terminates if user navigates away
    _ =
      Task.Supervisor.start_child(
        Pearl.TaskSupervisor,
        fn ->
          case Rag.ask(repo, question, stream: true, history: history) do
            {:ok, stream} ->
              Enum.each(stream, fn chunk ->
                send(pid, {:answer_chunk, chunk})
              end)

              send(pid, :answer_complete)

            {:error, reason} ->
              send(pid, {:answer_error, reason})
          end
        end,
        link: true
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("ask", _params, socket) do
    # Empty question - do nothing
    {:noreply, socket}
  end

  @impl true
  def handle_info({:answer_chunk, chunk}, socket) do
    # Append chunk to the last message (assistant)
    messages = socket.assigns.ask_messages

    updated_messages =
      case Enum.split(messages, -1) do
        {init, [last]} ->
          init ++ [%{last | content: last.content <> chunk}]

        _ ->
          # No messages yet - create an assistant message
          [%{role: :assistant, content: chunk}]
      end

    {:noreply, assign(socket, ask_messages: updated_messages)}
  end

  @impl true
  def handle_info(:answer_complete, socket) do
    {:noreply,
     socket
     |> assign(ask_loading: false)
     |> push_event("focus-input", %{})}
  end

  @impl true
  def handle_info({:answer_error, reason}, socket) do
    # Update the last (assistant) message with the error
    messages = socket.assigns.ask_messages
    error_content = "Error: #{inspect(reason)}"

    updated_messages =
      case Enum.split(messages, -1) do
        {init, [last]} ->
          init ++ [%{last | content: error_content}]

        _ ->
          [%{role: :assistant, content: error_content}]
      end

    {:noreply,
     socket
     |> assign(ask_loading: false, ask_messages: updated_messages)
     |> push_event("focus-input", %{})}
  end

  defp get_page_content(nil, _), do: ""

  defp get_page_content(wiki_cache, page_id) do
    wiki_cache.pages[page_id] || ""
  end
end
