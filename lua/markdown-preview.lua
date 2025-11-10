-- Markdown Preview Module
-- Opens current markdown file in browser with live preview

local M = {}

-- Check if a command exists
local function command_exists(cmd)
  local handle = io.popen("command -v " .. cmd .. " 2>/dev/null")
  if handle == nil then
    return false
  end
  local result = handle:read("*a")
  handle:close()
  return result ~= ""
end

-- Get the current buffer's file path
local function get_current_file()
  return vim.api.nvim_buf_get_name(0)
end

-- Convert markdown to HTML using pandoc (if available)
local function convert_with_pandoc(md_file, html_file)
  local cmd = string.format(
    "pandoc '%s' -f markdown -t html -s -o '%s' --metadata title='Markdown Preview' --css 'https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.2.0/github-markdown.min.css' --katex",
    md_file, html_file
  )
  return os.execute(cmd) == 0
end

-- Create HTML with embedded markdown renderer
local function create_html_with_renderer(md_file, html_file)
  local md_content = ""
  local file = io.open(md_file, "r")
  if file then
    md_content = file:read("*a")
    file:close()
  else
    vim.notify("Could not read markdown file: " .. md_file, vim.log.levels.ERROR)
    return false
  end

  -- Escape markdown content for JavaScript
  md_content = md_content:gsub("\\", "\\\\"):gsub("`", "\\`"):gsub("$", "\\$")

  local html_template = string.format([[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Markdown Preview</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.2.0/github-markdown.min.css">
    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
    <style>
        body {
            background-color: #0d1117;
            color: #c9d1d9;
            margin: 0;
            padding: 20px;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
        }
        .markdown-body {
            box-sizing: border-box;
            min-width: 200px;
            max-width: 980px;
            margin: 0 auto;
            padding: 45px;
            background-color: #0d1117;
            color: #c9d1d9;
        }
        @media (max-width: 767px) {
            .markdown-body {
                padding: 15px;
            }
        }
        .header {
            text-align: center;
            padding: 20px 0;
            border-bottom: 1px solid #30363d;
            margin-bottom: 30px;
        }
        .header h1 {
            margin: 0;
            color: #58a6ff;
        }
        .file-path {
            color: #8b949e;
            font-size: 14px;
            margin-top: 5px;
        }
        .refresh-notice {
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: #238636;
            color: white;
            padding: 10px 20px;
            border-radius: 6px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.3);
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>📝 Markdown Preview</h1>
        <div class="file-path">%s</div>
    </div>
    <div id="content" class="markdown-body"></div>
    <div class="refresh-notice">💡 Save file and refresh to update</div>

    <script>
        const markdownContent = `%s`;

        // Configure marked
        marked.setOptions({
            highlight: function(code, lang) {
                return code;
            },
            breaks: true,
            gfm: true
        });

        // Render markdown
        document.getElementById('content').innerHTML = marked.parse(markdownContent);
    </script>
</body>
</html>
]], md_file, md_content)

  local out_file = io.open(html_file, "w")
  if out_file then
    out_file:write(html_template)
    out_file:close()
    return true
  else
    vim.notify("Could not create HTML file: " .. html_file, vim.log.levels.ERROR)
    return false
  end
end

-- Open HTML file in browser
local function open_in_browser(html_file)
  local open_cmd

  if command_exists("xdg-open") then
    open_cmd = "xdg-open"
  elseif command_exists("open") then
    open_cmd = "open"  -- macOS
  elseif command_exists("start") then
    open_cmd = "start"  -- Windows
  else
    vim.notify("No browser opener found (xdg-open, open, or start)", vim.log.levels.ERROR)
    return false
  end

  os.execute(string.format("%s '%s' &>/dev/null &", open_cmd, html_file))
  return true
end

-- Main preview function
function M.preview()
  local md_file = get_current_file()

  if md_file == "" then
    vim.notify("No file open", vim.log.levels.WARN)
    return
  end

  if not md_file:match("%.md$") then
    vim.notify("Current file is not a markdown file", vim.log.levels.WARN)
    return
  end

  -- Save the file first
  vim.cmd("write")

  -- Create temporary HTML file
  local tmp_dir = os.getenv("TMPDIR") or "/tmp"
  local html_file = tmp_dir .. "/nvim_markdown_preview.html"

  vim.notify("Generating preview...", vim.log.levels.INFO)

  -- Try pandoc first, fall back to embedded renderer
  local success
  if command_exists("pandoc") then
    success = convert_with_pandoc(md_file, html_file)
    if not success then
      vim.notify("Pandoc failed, using built-in renderer", vim.log.levels.WARN)
      success = create_html_with_renderer(md_file, html_file)
    end
  else
    success = create_html_with_renderer(md_file, html_file)
  end

  if success then
    if open_in_browser(html_file) then
      vim.notify("✓ Markdown preview opened in browser", vim.log.levels.INFO)
    end
  end
end

-- Setup function to create commands and keybindings
function M.setup()
  -- Create user command
  vim.api.nvim_create_user_command('MarkdownPreview', function()
    M.preview()
  end, { desc = 'Preview markdown in browser' })

  -- Set up keybinding
  vim.keymap.set('n', '<leader>mp', function()
    M.preview()
  end, { desc = 'Markdown Preview' })
end

return M
