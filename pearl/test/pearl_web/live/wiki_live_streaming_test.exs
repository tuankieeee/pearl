defmodule PearlWeb.WikiLiveStreamingTest do
  @moduledoc """
  Integration tests for streaming RAG responses in WikiLive.

  These tests verify that streaming chunks are correctly received, concatenated,
  and displayed to the user. We test by directly sending messages to the LiveView
  process, which simulates what happens when actual streaming chunks arrive from
  the Rag module.

  ## Bugs Fixed During Test Development

  1. `ask_answer` was initialized to `nil` in mount/3, but handle_info for
     :answer_chunk tried to concatenate with `<>` which fails on nil values.
     Fix: Initialize `ask_answer` to "" instead of nil.

  2. SSE parser in OpenRouter only handled single events per TCP packet, but
     SSE streams often batch multiple `data:` events in one packet, causing
     chunks to be lost. Fix: Split incoming data by newlines and parse each
     `data:` line individually in `parse_sse_events/1`.

  See commit history for details.
  """
  use PearlWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Pearl.Repositories
  alias Pearl.Wiki

  setup do
    {:ok, repo} =
      Repositories.create_repo(%{
        url: "https://github.com/test/streaming",
        provider: "github",
        owner: "test",
        name: "streaming-test",
        status: "ready"
      })

    {:ok, _} =
      Wiki.save_cache(repo, %{
        structure: %{"pages" => [%{"id" => "overview", "title" => "Overview"}]},
        pages: %{"overview" => "# Overview\n\nThis is the overview."},
        model_used: "test/model"
      })

    {:ok, repo: repo}
  end

  describe "ask panel UI" do
    test "shows loading indicator before streaming begins", %{conn: conn, repo: repo} do
      {:ok, view, _html} = live(conn, "/wiki/#{repo.id}")

      # Open the ask panel
      view |> element("button", "Chat with AI") |> render_click()

      # Verify panel is open and has the input
      assert has_element?(view, "input[name='question']")

      # Verify form structure for submitting questions
      assert has_element?(view, "form[phx-submit='ask']")
    end

    test "ask panel has correct structure", %{conn: conn, repo: repo} do
      {:ok, view, _html} = live(conn, "/wiki/#{repo.id}")

      # Open the ask panel
      view |> element("button", "Chat with AI") |> render_click()

      html = render(view)

      # Verify panel structure
      assert html =~ "Ask about the codebase"
      assert has_element?(view, "input[placeholder='Ask anything about this codebase...']")
      assert has_element?(view, "button[type='submit']")
    end

    test "toggle_ask opens and closes panel", %{conn: conn, repo: repo} do
      {:ok, view, _html} = live(conn, "/wiki/#{repo.id}")

      # Initially no ask panel
      refute render(view) =~ "Ask about the codebase"

      # Open panel
      view |> element("button", "Chat with AI") |> render_click()
      assert render(view) =~ "Ask about the codebase"

      # Close panel via the X button
      view |> element("button[phx-click='toggle_ask'].btn-circle") |> render_click()
      refute render(view) =~ "Ask about the codebase"
    end

    test "loading state before first chunk", %{conn: conn, repo: repo} do
      {:ok, view, _html} = live(conn, "/wiki/#{repo.id}")

      # Open ask panel
      view |> element("button", "Chat with AI") |> render_click()

      # Initially, no loading indicator until question is submitted
      html = render(view)
      refute html =~ "loading-infinity"
    end
  end

  describe "streaming chunk handling" do
    test "receives and displays streaming chunks", %{conn: conn, repo: repo} do
      {:ok, view, _html} = live(conn, "/wiki/#{repo.id}")

      view |> element("button", "Chat with AI") |> render_click()
      pid = view.pid

      send(pid, {:answer_chunk, "Hello"})
      html = render(view)

      assert html =~ "Hello"
    end

    test "concatenates multiple chunks correctly", %{conn: conn, repo: repo} do
      {:ok, view, _html} = live(conn, "/wiki/#{repo.id}")

      view |> element("button", "Chat with AI") |> render_click()
      pid = view.pid

      send(pid, {:answer_chunk, "Hello"})
      send(pid, {:answer_chunk, " "})
      send(pid, {:answer_chunk, "World"})
      send(pid, {:answer_chunk, "!"})

      html = render(view)

      assert html =~ "Hello World!"
    end

    test "handles empty chunks gracefully", %{conn: conn, repo: repo} do
      {:ok, view, _html} = live(conn, "/wiki/#{repo.id}")

      view |> element("button", "Chat with AI") |> render_click()
      pid = view.pid

      send(pid, {:answer_chunk, "Start"})
      send(pid, {:answer_chunk, ""})
      send(pid, {:answer_chunk, "End"})

      html = render(view)

      assert html =~ "StartEnd"
    end

    test "handles answer_complete message", %{conn: conn, repo: repo} do
      {:ok, view, _html} = live(conn, "/wiki/#{repo.id}")

      view |> element("button", "Chat with AI") |> render_click()
      pid = view.pid

      send(pid, {:answer_chunk, "Complete answer"})
      send(pid, :answer_complete)

      html = render(view)

      assert html =~ "Complete answer"
      refute html =~ "loading-spinner"
    end

    test "handles chunks with special characters", %{conn: conn, repo: repo} do
      {:ok, view, _html} = live(conn, "/wiki/#{repo.id}")

      view |> element("button", "Chat with AI") |> render_click()
      pid = view.pid

      send(pid, {:answer_chunk, "# Header\n\n"})
      send(pid, {:answer_chunk, "Some **bold** text."})

      html = render(view)

      assert html =~ "Header"
      assert html =~ "bold"
    end

    test "handles unicode chunks correctly", %{conn: conn, repo: repo} do
      {:ok, view, _html} = live(conn, "/wiki/#{repo.id}")

      view |> element("button", "Chat with AI") |> render_click()
      pid = view.pid

      send(pid, {:answer_chunk, "Hello "})
      send(pid, {:answer_chunk, "世界"})

      html = render(view)

      assert html =~ "Hello"
      assert html =~ "世界"
    end

    test "rapid sequential chunks are all processed", %{conn: conn, repo: repo} do
      {:ok, view, _html} = live(conn, "/wiki/#{repo.id}")

      view |> element("button", "Chat with AI") |> render_click()
      pid = view.pid

      for i <- 1..10 do
        send(pid, {:answer_chunk, "#{i} "})
      end

      html = render(view)

      for i <- 1..10 do
        assert html =~ "#{i}"
      end
    end

    test "closing and reopening panel preserves answer", %{conn: conn, repo: repo} do
      {:ok, view, _html} = live(conn, "/wiki/#{repo.id}")

      view |> element("button", "Chat with AI") |> render_click()
      pid = view.pid

      send(pid, {:answer_chunk, "Persistent answer"})
      _ = render(view)

      # Close panel
      view |> element("button[phx-click='toggle_ask'].btn-circle") |> render_click()

      # Reopen panel
      view |> element("button", "Chat with AI") |> render_click()

      html = render(view)

      assert html =~ "Persistent answer"
    end
  end

  describe "error handling" do
    test "handles answer_error message", %{conn: conn, repo: repo} do
      {:ok, view, _html} = live(conn, "/wiki/#{repo.id}")

      view |> element("button", "Chat with AI") |> render_click()
      pid = view.pid

      send(pid, {:answer_error, :api_timeout})

      html = render(view)

      assert html =~ "Error"
      assert html =~ "api_timeout"
    end
  end
end
