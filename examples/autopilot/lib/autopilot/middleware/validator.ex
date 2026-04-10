defmodule Autopilot.Middleware.Validator do
  @moduledoc "Validates tool results and injects corrective notes."
  @behaviour Sagents.Middleware

  @captcha_keywords ["captcha", "recaptcha", "hcaptcha", "not a robot", "unusual traffic",
                     "verify you", "security check", "blocked"]

  @verification_keywords ["closed", "did it work", "is the", "verify", "still there",
                          "gone", "disappeared", "successful", "worked", "resolved"]

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def system_prompt(_config), do: ""

  @impl true
  def tools(_config), do: []

  @impl true
  def before_model(state, _config), do: {:ok, state}

  @impl true
  def after_model(state, _config) do
    tool_msgs = state.messages
      |> Enum.reverse()
      |> Enum.filter(&(&1.role == :tool))
      |> Enum.take(3)

    last_content = case List.first(tool_msgs) do
      %{content: c} when is_binary(c) -> c
      _ -> ""
    end

    notes = []

    # --- Detect failures ---
    notes = if String.contains?(last_content, "failed") or String.contains?(last_content, "error") do
      ["The previous action may have failed. Use extract_text to check current page state before retrying." | notes]
    else
      notes
    end

    # --- Detect CAPTCHA in tool results ---
    lower = String.downcase(last_content)
    is_captcha = Enum.any?(@captcha_keywords, &String.contains?(lower, &1))

    notes = if is_captcha do
      ["""
      CAPTCHA DETECTED in page. Follow this strategy:
      1. For image-grid CAPTCHA: use solve_captcha() — it handles everything automatically.
      2. For checkbox CAPTCHA: try click(x, y) at the checkbox location.
      3. If CAPTCHA persists after 2 attempts: switch to a different site (DuckDuckGo has no CAPTCHAs).
      4. NEVER keep retrying the same CAPTCHA — switch strategies or sites after 2 failures.
      """ | notes]
    else
      notes
    end

    # --- Detect repeated CAPTCHA (agent stuck in loop) ---
    captcha_count = tool_msgs
      |> Enum.count(fn
        %{content: c} when is_binary(c) ->
          Enum.any?(@captcha_keywords, &String.contains?(String.downcase(c), &1))
        _ -> false
      end)

    notes = if captcha_count >= 2 do
      ["""
      You have hit CAPTCHAs multiple times. STOP retrying this site.
      Switch to DuckDuckGo (https://duckduckgo.com/?q=YOUR+QUERY) which does not use CAPTCHAs.
      """ | notes]
    else
      notes
    end

    # --- Detect see_screen used for verification (unreliable) ---
    notes = if see_screen_used_for_verification?(state) do
      ["""
      STOP: Do NOT trust see_screen for verifying if an action worked.
      VLM responses are unreliable for yes/no confirmation — they tend to say "yes" even when nothing changed.
      Instead use extract_text and check if the expected text is still present or gone.
      For example: if you closed a pop-up saying "Would you like to receive notifications",
      call extract_text and check that text no longer appears.
      """ | notes]
    else
      notes
    end

    # --- Detect click followed by no verification ---
    notes = if click_without_verification?(state) do
      ["You just clicked an element. Use extract_text to verify the action worked — do NOT assume success." | notes]
    else
      notes
    end

    if Enum.empty?(notes) do
      {:ok, state}
    else
      combined = Enum.join(notes, "\n\n")
      note_msg = LangChain.Message.new_system!(combined)
      {:ok, %{state | messages: state.messages ++ [note_msg]}}
    end
  end

  @impl true
  def handle_message(_msg, state, _config), do: {:ok, state}

  @impl true
  def on_server_start(state, _config), do: {:ok, state}

  # --- Private helpers ---

  defp see_screen_used_for_verification?(state) do
    # Check if the last assistant message contains a see_screen call
    # with a verification-style question
    last_assistant = state.messages
      |> Enum.reverse()
      |> Enum.find(&(&1.role == :assistant))

    case last_assistant do
      %{content: parts} when is_list(parts) ->
        Enum.any?(parts, fn
          %{name: "see_screen", arguments: %{"question" => q}} ->
            lower = String.downcase(q)
            Enum.any?(@verification_keywords, &String.contains?(lower, &1))
          _ -> false
        end)
      _ -> false
    end
  end

  defp click_without_verification?(state) do
    # Check if the last two tool calls were: click → see_screen (bad)
    # or if click was the very last tool call with no follow-up check
    recent = state.messages
      |> Enum.reverse()
      |> Enum.take(4)

    tool_names = recent
      |> Enum.filter(&(&1.role == :assistant))
      |> Enum.flat_map(fn msg ->
        case msg.content do
          parts when is_list(parts) ->
            parts
            |> Enum.filter(fn
              %{type: :tool_call} -> true
              %{"type" => "tool_use"} -> true
              _ -> false
            end)
            |> Enum.map(fn
              %{name: n} -> n
              %{"name" => n} -> n
              _ -> nil
            end)
            |> Enum.reject(&is_nil/1)
          _ -> []
        end
      end)

    # Pattern: click was called, then see_screen (should be extract_text instead)
    case tool_names do
      ["see_screen", "click" | _] -> true
      _ -> false
    end
  end
end
