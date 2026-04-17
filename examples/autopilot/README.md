# Autopilot

An autonomous browser agent powered by AI vision and multi-LLM orchestration, built on top of [Bibbidi](https://github.com/petermueller/bibbidi) (BEAM Interface for Browser with BiDi).

Autopilot observes, understands, and interacts with web pages like a human would — using computer vision models to parse UI elements and an LLM-driven ReAct loop to reason and act autonomously.

---

## How It Works

Autopilot combines three core capabilities:

1. **Visual Understanding** — A unified vision API analyzes the browser viewport, detecting and classifying UI elements across 48 classes (buttons, inputs, links, icons, text, images, etc.).
2. **ReAct Agent Loop** — A single reasoning-and-acting loop (similar to LangChain's ReAct agent) where the LLM observes the current state, decides the next action, executes it via tools, and repeats until the task is complete.
3. **Browser Automation** — Bibbidi handles all browser communication via the WebDriver BiDi Protocol (Firefox) or ChromeDriver, while Autopilot owns the AI layer on top.

### Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                       Autopilot                          │
│                   (Elixir / OTP Agent)                   │
│                                                          │
│         ┌─────────────────────────────────┐              │
│         │        ReAct Agent Loop         │              │
│         │                                 │              │
│         │   Observe ──► Think ──► Act ─┐  │              │
│         │      ▲                       │  │              │
│         │      └───────────────────────┘  │              │
│         └─────────────────────────────────┘              │
│                        │                                 │
│                        ▼                                 │
│  ┌─────────────────────────────────────────┐             │
│  │              Tools                      │             │
│  │  browser · vision · human · wait · done │             │
│  └─────────────────────────────────────────┘             │
│       │              │                                   │
│  ┌────┴────┐   ┌─────┴──────┐                            │
│  │ Bibbidi │   │  Middleware │                            │
│  │(Browser)│   │  observer · context_pruner              │
│  └─────────┘   └────────────┘                            │
└──────────────────────────────────────────────────────────┘
       │                    │
       ▼                    ▼
  Firefox (BiDi)     Unified Vision API (port 5001)
  or ChromeDriver    ├── YOLO (48 UI classes)
                     ├── OmniParser (Florence2)
                     ├── txtai
                     ├── SAM3 (segmentation)
                     ├── CAPTCHA solver
                     └── VLM
```

---

## Agent Loop

Autopilot uses a **ReAct (Reasoning + Acting) loop** — a single iterative cycle where the LLM observes the current page state, reasons about what to do next, calls a tool, observes the result, and repeats until the task is done or the `done` tool is called.

```
┌─► Observe (screenshot + vision parsing)
│        │
│     Think  (LLM decides next action)
│        │
│      Act   (call tool: click, type, scroll, etc.)
│        │
└────────┘   (repeat until done)
```

The loop is powered by configurable LLM nodes, each tuned for a different responsibility:

| Node | Role | Default Provider | Default Model |
|---|---|---|---|
| **Planner** | Core reasoning — decides the next action | Anthropic | `claude-sonnet-4-5-20250929` |
| **Validator** | Lightweight check on action feasibility | Ollama (local) | `llama3.2` |
| **Narrator** | Generates human-readable status updates | Anthropic | `claude-haiku-4-5-20251001` |

Each node's provider, model, and temperature are independently configurable via environment variables.

### Middleware

- **Observer** — Logs and monitors agent activity in real time.
- **Context Pruner** — Keeps the LLM context window manageable by retaining only the last N turns (default: 3).

### Tools

| Tool | Description |
|---|---|
| `browser` | Click, type, scroll, navigate — all browser interactions via Bibbidi |
| `vision` | Request a UI snapshot from the vision API and parse the result |
| `human` | Hand control back to the user (e.g. for 2FA, sensitive inputs) |
| `wait` | Pause execution for a specified duration or until a condition is met |
| `done` | Signal task completion |

---

## Vision API

A single Python service (port `5001`) that exposes multiple vision capabilities behind one endpoint:

- **Custom YOLO** — Fine-tuned on 48 UI element classes with EasyOCR (conf threshold: `0.25`)
- **OmniParser** — Florence2 + YOLO for general-purpose UI parsing
- **txtai** — Semantic search over detected elements
- **SAM3** — Segment Anything Model 3, used for physical objects (CAPTCHAs, real-world images)
- **CAPTCHA solver** — Dedicated pipeline for CAPTCHA challenges
- **VLM** — Vision-Language Model for complex visual reasoning

---

## Requirements

- **Elixir** >= 1.15
- **Erlang/OTP** >= 26
- **Python** >= 3.10 (for the vision API)
- **Firefox** with remote debugging enabled, or **ChromeDriver**
- **NVIDIA GPU** with CUDA support (recommended: RTX 4080 SUPER or equivalent)

---

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/petermueller/bibbidi.git
cd bibbidi/examples/autopilot
```

### 2. Configure environment variables

Copy the example `.env` file and fill in your keys:

```bash
cp .env.example .env
```

```env
# LLM Providers
ANTHROPIC_API_KEY=sk-ant-...
OLLAMA_BASE_URL=http://localhost:11434

# Browser
BROWSER=firefox
FIREFOX_WS_URL=ws://localhost:9222

# Vision
VISION_URL=http://localhost:5001

# Per-node overrides (optional)
PLANNER_PROVIDER=anthropic
PLANNER_MODEL=claude-sonnet-4-5-20250929
VALIDATOR_PROVIDER=ollama
VALIDATOR_MODEL=llama3.2
NARRATOR_PROVIDER=anthropic
NARRATOR_MODEL=claude-haiku-4-5-20251001
```

### 3. Start the vision API

```bash
# From the vision API directory
python server.py  # Starts on port 5001
```

### 4. Launch the browser

```bash
# Firefox with remote debugging
firefox --remote-debugging-port=9222

# Or start ChromeDriver
chromedriver --port=9515
```

### 5. Run Autopilot

```bash
mix deps.get
mix run --no-halt
```

---

## Configuration Reference

All configuration is loaded from `.env` via [Dotenvy](https://hexdocs.pm/dotenvy) at runtime.

### Browser

| Variable | Default | Description |
|---|---|---|
| `BROWSER` | `firefox` | Browser engine (`firefox` or `chrome`) |
| `FIREFOX_WS_URL` | `ws://localhost:9222` | Firefox BiDi WebSocket URL |
| `CHROMEDRIVER_URL` | `http://localhost:9515` | ChromeDriver HTTP endpoint |

### Vision

| Variable | Default | Description |
|---|---|---|
| `VISION_URL` | `http://localhost:5001` | Unified vision API endpoint |

### LLM Providers

| Variable | Default | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | — | Anthropic API key (required for Claude nodes) |
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Local Ollama instance |
| `OLLAMA_CLOUD_URL` | — | Remote Ollama endpoint (optional) |
| `OLLAMA_API_KEY` | — | API key for remote Ollama (optional) |

### Per-Node LLM Settings

Each node (`PLANNER`, `VALIDATOR`, `NARRATOR`) accepts three variables:

| Suffix | Type | Description |
|---|---|---|
| `_PROVIDER` | string | `anthropic` or `ollama` |
| `_MODEL` | string | Model identifier |
| `_TEMPERATURE` | float | Sampling temperature |

Example: `PLANNER_PROVIDER=anthropic`, `PLANNER_MODEL=claude-sonnet-4-5-20250929`, `PLANNER_TEMPERATURE=0.0`

### Middleware

| Setting | Default | Description |
|---|---|---|
| Observer | enabled | Real-time agent activity logging |
| Context Pruner | enabled, 3 turns | Limits LLM context to the last N conversation turns |

---

## Project Structure

```
examples/autopilot/
├── config/
│   └── runtime.exs            # Dotenvy-based runtime configuration
├── lib/
│   ├── autopilot.ex            # Public API & entry point
│   └── autopilot/
│       ├── application.ex      # OTP application & supervision tree
│       ├── agent.ex            # Core agent loop & orchestration
│       ├── browser.ex          # Bibbidi browser wrapper
│       ├── llm.ex              # Multi-provider LLM client
│       ├── task_log.ex         # Task execution logging
│       ├── middleware/
│       │   ├── context_pruner.ex   # Prunes old turns from LLM context
│       │   ├── observer.ex         # Observability & event logging
│       │   └── planner.ex          # Planning middleware
│       └── tools/
│           ├── browser.ex      # Click, type, scroll, navigate
│           ├── vision.ex       # Vision API integration
│           ├── human.ex        # Human-in-the-loop handoff
│           ├── wait.ex         # Timed waits & conditions
│           └── done.ex         # Task completion signal
├── mix.exs
└── .env
```

---

## Roadmap

- [ ] Migrate from `examples/autopilot/` to `packages/autopilot/` in Bibbidi repo
- [ ] Single `mix` task to launch full stack (vision API + browser + agent)
- [ ] Playbook system — record and replay browser workflows
- [ ] Port to Ethermed Elixir umbrella (`apps/autopilot/`)
- [ ] Improved error recovery and multi-tab support

---

## Contributing

Contributions are welcome! Please open an issue first to discuss what you'd like to change.

1. Fork the repo
2. Create your branch (`git checkout -b feature/my-feature`)
3. Commit your changes
4. Push and open a Pull Request

---

## License

This project is licensed under the [MIT License](LICENSE).

---

## Acknowledgements

- [Bibbidi](https://github.com/petermueller/bibbidi) — BEAM Interface for Browser with BiDi (BIBBiDi), utilizing the WebDriver BiDi Protocol. Maintained by Peter Mueller.
- [OmniParser](https://github.com/microsoft/OmniParser) — UI screen parsing with Florence2 + YOLO.
- [Segment Anything 3](https://github.com/facebookresearch/sam3) — Meta's segmentation model.
- [Dotenvy](https://hexdocs.pm/dotenvy) — Environment variable management for Elixir.