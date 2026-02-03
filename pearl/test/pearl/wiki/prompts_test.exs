defmodule Pearl.Wiki.PromptsTest do
  use ExUnit.Case, async: true

  alias Pearl.Wiki.Prompts

  describe "structure_prompt/1" do
    test "returns few-shot prompt with example exchange" do
      file_tree = %{"lib" => %{"app.ex" => :file}}
      messages = Prompts.structure_prompt(file_tree)

      # Few-shot pattern: system, example user, example assistant, actual user
      assert length(messages) == 4
      assert Enum.at(messages, 0).role == "system"
      assert Enum.at(messages, 1).role == "user"
      assert Enum.at(messages, 2).role == "assistant"
      assert Enum.at(messages, 3).role == "user"
      assert Enum.at(messages, 3).content =~ "app.ex"
    end
  end

  describe "page_prompt/2" do
    test "returns messages for page generation" do
      page_spec = %{id: "overview", title: "Overview"}
      file_contents = [{"lib/app.ex", "defmodule App do end"}]

      messages = Prompts.page_prompt(page_spec, file_contents)

      assert length(messages) == 2
      assert Enum.at(messages, 0).role == "system"
      assert Enum.at(messages, 1).role == "user"
      assert Enum.at(messages, 1).content =~ "Overview"
    end
  end

  describe "page_prompt/3" do
    test "includes type-specific guidance for overview pages" do
      page_spec = %{id: "overview", title: "Overview"}
      file_contents = [{"lib/app.ex", "defmodule App do end"}]

      messages = Prompts.page_prompt(page_spec, file_contents, :overview)

      system_content = Enum.at(messages, 0).content
      assert system_content =~ "OVERVIEW"
      assert system_content =~ "Project identity"
    end

    test "includes type-specific guidance for getting_started pages" do
      page_spec = %{id: "getting-started", title: "Getting Started"}
      file_contents = [{"mix.exs", "defp deps do [] end"}]

      messages = Prompts.page_prompt(page_spec, file_contents, :getting_started)

      system_content = Enum.at(messages, 0).content
      assert system_content =~ "GETTING STARTED"
      assert system_content =~ "Prerequisites"
    end

    test "includes type-specific guidance for architecture pages" do
      page_spec = %{id: "architecture", title: "Architecture"}
      file_contents = [{"lib/app.ex", "defmodule App do end"}]

      messages = Prompts.page_prompt(page_spec, file_contents, :architecture)

      system_content = Enum.at(messages, 0).content
      assert system_content =~ "ARCHITECTURE"
      assert system_content =~ "Components"
    end

    test "includes type-specific guidance for configuration pages" do
      page_spec = %{id: "configuration", title: "Configuration"}
      file_contents = [{"config/config.exs", "import Config"}]

      messages = Prompts.page_prompt(page_spec, file_contents, :configuration)

      system_content = Enum.at(messages, 0).content
      assert system_content =~ "CONFIGURATION"
      assert system_content =~ "Configuration options"
    end

    test "uses general guidance for default page type" do
      page_spec = %{id: "api", title: "API"}
      file_contents = [{"lib/api.ex", "defmodule Api do end"}]

      messages = Prompts.page_prompt(page_spec, file_contents, :default)

      system_content = Enum.at(messages, 0).content
      assert system_content =~ "GENERAL"
    end
  end
end
