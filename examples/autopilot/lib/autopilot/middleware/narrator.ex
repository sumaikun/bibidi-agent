defmodule Autopilot.Middleware.Narrator do
  @moduledoc "Adds summary instructions to system prompt."
  @behaviour Sagents.Middleware

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def system_prompt(_config) do
    """
    When the task is complete, provide a clear friendly summary:
    - What was accomplished
    - Any important results or content found
    - Steps that required human input or CAPTCHA solving
    Keep it concise.
    """
  end

  @impl true
  def tools(_config), do: []

  @impl true
  def before_model(state, _config), do: {:ok, state}

  @impl true
  def after_model(state, _config), do: {:ok, state}

  @impl true
  def handle_message(_msg, state, _config), do: {:ok, state}

  @impl true
  def on_server_start(state, _config), do: {:ok, state}
end
