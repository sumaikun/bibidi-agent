defmodule Autopilot.Tools.Browser do
  @moduledoc "Browser action tools: navigate, click, type_text, press_key, scroll, go_back, get_links, get_current_url."

  alias LangChain.Function
  alias LangChain.FunctionParam

  def navigate do
    Function.new!(%{
      name: "navigate",
      description: "Navigate the browser to a URL.",
      parameters: [
        FunctionParam.new!(%{name: "url", type: :string, required: true,
          description: "Full URL e.g. 'https://google.com'"})
      ],
      function: fn %{"url" => url}, _context ->
        case Autopilot.Browser.navigate(url) do
          {:ok, _}         -> {:ok, "Navigated to #{url}"}
          {:error, reason} -> {:error, "navigate failed: #{inspect(reason)}"}
        end
      end
    })
  end

  def click do
    Function.new!(%{
      name: "click",
      description: "Click at x,y coordinates. Get coordinates from find_element first.",
      parameters: [
        FunctionParam.new!(%{name: "x", type: :integer, required: true, description: "X coordinate"}),
        FunctionParam.new!(%{name: "y", type: :integer, required: true, description: "Y coordinate"})
      ],
      function: fn %{"x" => x, "y" => y}, _context ->
        case Autopilot.Browser.click(x, y) do
          {:ok, _}         -> {:ok, "Clicked at (#{x}, #{y})"}
          {:error, reason} -> {:error, "click failed: #{inspect(reason)}"}
        end
      end
    })
  end

  def type_text do
    Function.new!(%{
      name: "type_text",
      description: """
      Type text into an input field using native keyboard events.
      Works with React, Angular and other modern frameworks.
      Automatically focuses the field, clears existing content,
      and types character by character like a real keyboard.
      Use CSS selector from find_element or scan_dom.
      """,
      parameters: [
        FunctionParam.new!(%{name: "selector", type: :string, required: true,
          description: "CSS selector e.g. '#username', '[name=q]', 'input[type=email]'"}),
        FunctionParam.new!(%{name: "text", type: :string, required: true,
          description: "Text to type"})
      ],
      function: fn %{"selector" => selector, "text" => text}, _context ->
        case Autopilot.Browser.type(selector, text) do
          {:ok, _}         -> {:ok, "Typed '#{text}' into #{selector}"}
          {:error, reason} -> {:error, "type_text failed: #{inspect(reason)}"}
        end
      end
    })
  end

  def press_key do
    Function.new!(%{
      name: "press_key",
      description: "Press a keyboard key. Use 'Enter' to submit, 'Tab' to move focus, 'Escape' to close.",
      parameters: [
        FunctionParam.new!(%{name: "key", type: :string, required: true,
          description: "Key name e.g. 'Enter', 'Tab', 'Escape', 'ArrowDown', 'Backspace'"})
      ],
      function: fn %{"key" => key}, _context ->
        case Autopilot.Browser.press_key(key) do
          {:ok, _}         -> {:ok, "Pressed '#{key}'"}
          {:error, reason} -> {:error, "press_key failed: #{inspect(reason)}"}
        end
      end
    })
  end

  def scroll do
    Function.new!(%{
      name: "scroll",
      description: "Scroll the page up or down to reveal more content.",
      parameters: [
        FunctionParam.new!(%{name: "direction", type: :string, required: true,
          description: "'down' or 'up'"}),
        FunctionParam.new!(%{name: "amount", type: :integer, required: false,
          description: "Pixels to scroll (default 400)"})
      ],
      function: fn args, _context ->
        direction = args["direction"] || "down"
        amount    = args["amount"] || 400
        case Autopilot.Browser.scroll(direction, amount) do
          {:ok, _}         -> {:ok, "Scrolled #{direction} #{amount}px"}
          {:error, reason} -> {:error, "scroll failed: #{inspect(reason)}"}
        end
      end
    })
  end

  def go_back do
    Function.new!(%{
      name: "go_back",
      description: "Go back to the previous page in browser history.",
      parameters: [],
      function: fn _args, _context ->
        case Autopilot.Browser.go_back() do
          {:ok, _}         -> {:ok, "Navigated back to previous page"}
          {:error, reason} -> {:error, "go_back failed: #{inspect(reason)}"}
        end
      end
    })
  end

  def get_current_url do
    Function.new!(%{
      name: "get_current_url",
      description: "Get the current page URL without taking a screenshot.",
      parameters: [],
      function: fn _args, _context ->
        case Autopilot.Browser.eval("window.location.href") do
          {:ok, %{"result" => %{"value" => url}}} -> {:ok, url}
          {:error, reason}                         -> {:error, "get_current_url failed: #{inspect(reason)}"}
        end
      end
    })
  end

  def get_links do
    Function.new!(%{
      name: "get_links",
      description: "Get all visible links on the page with their text and coordinates. Use to find search results or navigation links.",
      parameters: [
        FunctionParam.new!(%{name: "limit", type: :integer, required: false,
          description: "Max number of links to return (default 10)"})
      ],
      function: fn args, _context ->
        limit = args["limit"] || 10
        js = """
        JSON.stringify(
          Array.from(document.querySelectorAll('a[href]'))
            .filter(a => a.offsetParent !== null && a.textContent.trim().length > 0)
            .slice(0, #{limit})
            .map(a => ({
              text: a.textContent.trim().slice(0, 80),
              href: a.href,
              x:    Math.round(a.getBoundingClientRect().x + a.getBoundingClientRect().width  / 2),
              y:    Math.round(a.getBoundingClientRect().y + a.getBoundingClientRect().height / 2)
            }))
        )
        """
        case Autopilot.Browser.eval(js) do
          {:ok, %{"result" => %{"value" => json}}} ->
            links  = Jason.decode!(json)
            result = links
              |> Enum.map(fn l -> "[#{l["x"]}, #{l["y"]}] #{l["text"]} → #{l["href"]}" end)
              |> Enum.join("\n")
            {:ok, "Found #{length(links)} links:\n#{result}"}
          {:error, reason} ->
            {:error, "get_links failed: #{inspect(reason)}"}
        end
      end
    })
  end
end
