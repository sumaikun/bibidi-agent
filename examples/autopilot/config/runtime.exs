import Config
import Dotenvy

source!([Path.join([__DIR__, "..", ".env"]) |> Path.expand(), System.get_env()])

IO.puts(">> Config loaded - provider: #{System.get_env("PLANNER_PROVIDER", "anthropic")}")

config :autopilot,
  # Browser
  browser_ws_url: env!("BROWSER_WS_URL", :string, "ws://localhost:9222/session"),

  # Vision API (unified: YOLO + txtai + SAM3 + CAPTCHA + VLM)
  vision_url: env!("VISION_URL", :string, "http://localhost:5001"),

  # Observability
  observer: [enabled: true],
  context_pruner: [enabled: true, keep_turns: 3],

  # LLM providers
  anthropic_api_key: env!("ANTHROPIC_API_KEY", :string, nil),
  ollama_base_url:   env!("OLLAMA_BASE_URL",   :string, "http://localhost:11434"),
  ollama_cloud_url:  env!("OLLAMA_CLOUD_URL",  :string, nil),
  ollama_api_key:    env!("OLLAMA_API_KEY",    :string, nil),

  # Per-node config
  planner: %{
    provider:    env!("PLANNER_PROVIDER",    :string, "anthropic"),
    model:       env!("PLANNER_MODEL",       :string, "claude-sonnet-4-5-20250929"),
    temperature: env!("PLANNER_TEMPERATURE", :float,  0.0)
  },
  validator: %{
    provider:    env!("VALIDATOR_PROVIDER",    :string, "ollama"),
    model:       env!("VALIDATOR_MODEL",       :string, "llama3.2"),
    temperature: env!("VALIDATOR_TEMPERATURE", :float,  0.0)
  },
  narrator: %{
    provider:    env!("NARRATOR_PROVIDER",    :string, "anthropic"),
    model:       env!("NARRATOR_MODEL",       :string, "claude-haiku-4-5-20251001"),
    temperature: env!("NARRATOR_TEMPERATURE", :float,  0.7)
  }
