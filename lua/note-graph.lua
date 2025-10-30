-- Note Graph Visualization
-- An Obsidian-like network graph view for Neovim

local M = {}
local uv = vim.loop
local api = vim.api

-- Configuration
M.config = {
  notes_dir = vim.fn.expand('~/Documents/Notes'),
  exclude_dirs = { '.git', 'img', 'templates' },
  max_visible_nodes = 100,
  use_graphics = true, -- Use kitty graphics if available
  physics = {
    spring_length = 300,      -- Even longer ideal distance for cleaner spread
    spring_strength = 0.012,  -- Even gentler pull for smoother layout
    repulsion = 22000,        -- Stronger push for maximum clarity
    damping = 0.92,           -- Smoother settling
    iterations = 250,         -- More iterations for better convergence
  },
  show_isolated = false,      -- Hide nodes with no connections by default
  min_connections = 2,        -- Minimum connections to show a node
  line_density = 0.7,         -- Draw 70% of line segments - better visibility while clean
  transparency = 20,          -- Window blend transparency (0-100, 0=opaque, 100=transparent)
  colors = {
    node = '#00d4ff',      -- Bright cyan for regular nodes
    current = '#ff006e',   -- Hot pink for current note
    selected = '#00ff88',  -- Bright green for selected
    hub = '#ff8c00',       -- Bright orange for hub nodes
    link_strong = '#00ffff', -- Bright cyan for strong connections
    link_medium = '#ff69b4', -- Hot pink for medium connections
    link_light = '#9d4edd',  -- Bright purple for light connections
    label = '#ffffff',     -- Pure white for labels
    background = '#1e1e2e', -- Dark background
  },
}

-- Graph state
M.graph = {
  nodes = {},
  edges = {},
  node_map = {},
}

M.ui = {
  buf = nil,
  win = nil,
  selected_node = nil,
  offset_x = 0,
  offset_y = 0,
  zoom = 1.0,
  animation_timer = nil,
  canvas = nil,
  filter_text = '',
  render_mode = 'terminal', -- terminal, svg, or web
}

-- ============================================================================
-- LINK DETECTION & GRAPH BUILDING
-- ============================================================================

-- Extract links from markdown content
local function extract_links(content, filepath)
  local links = {}
  local filename = vim.fn.fnamemodify(filepath, ':t:r')

  -- Wiki-style links: [[note-name]] or [[note-name|alias]]
  for link in content:gmatch('%[%[([^%]|]+)') do
    link = link:gsub('^%s+', ''):gsub('%s+$', '')
    if link ~= '' and link ~= filename then
      table.insert(links, link)
    end
  end

  -- Markdown links: [text](note.md) - extract just the filename
  for link in content:gmatch('%]%(([^)]+%.md)%)') do
    link = vim.fn.fnamemodify(link, ':t:r')
    if link ~= '' and link ~= filename then
      table.insert(links, link)
    end
  end

  return links
end

-- Check if path should be excluded
local function should_exclude(path)
  for _, exclude in ipairs(M.config.exclude_dirs) do
    if path:match(exclude) then
      return true
    end
  end
  return false
end

-- Scan all markdown files and build graph
function M.build_graph()
  M.graph = {
    nodes = {},
    edges = {},
    node_map = {},
  }

  -- Check if notes directory exists
  if vim.fn.isdirectory(M.config.notes_dir) == 0 then
    vim.notify(string.format('Notes directory not found: %s', M.config.notes_dir),
      vim.log.levels.ERROR)
    return false
  end

  -- Use vim.fn.glob for better compatibility
  local pattern = M.config.notes_dir .. '/**/*.md'
  local files_list = vim.fn.glob(pattern, false, true)

  local files = {}
  for _, filepath in ipairs(files_list) do
    if not should_exclude(filepath) then
      table.insert(files, filepath)
    end
  end

  if #files == 0 then
    vim.notify(string.format('No markdown files found in: %s\nTried pattern: %s',
      M.config.notes_dir, pattern), vim.log.levels.WARN)
    return false
  end

  vim.notify(string.format('Found %d markdown files, building graph...', #files),
    vim.log.levels.INFO)

  -- Build nodes
  for _, filepath in ipairs(files) do
    local filename = vim.fn.fnamemodify(filepath, ':t:r')
    local node = {
      id = filename,
      path = filepath,
      x = math.random(-200, 200),
      y = math.random(-200, 200),
      vx = 0,
      vy = 0,
      links = {},
      backlinks = {},
    }
    table.insert(M.graph.nodes, node)
    M.graph.node_map[filename] = node
  end

  -- Build edges by reading file contents
  for _, node in ipairs(M.graph.nodes) do
    local file = io.open(node.path, 'r')
    if file then
      local content = file:read('*a')
      file:close()

      local links = extract_links(content, node.path)
      for _, target in ipairs(links) do
        if M.graph.node_map[target] then
          table.insert(node.links, target)
          table.insert(M.graph.node_map[target].backlinks, node.id)
          table.insert(M.graph.edges, {
            source = node.id,
            target = target,
          })
        end
      end
    end
  end

  vim.notify(string.format('Graph built: %d notes, %d connections',
    #M.graph.nodes, #M.graph.edges), vim.log.levels.INFO)

  return true
end

-- ============================================================================
-- FORCE-DIRECTED LAYOUT (PHYSICS SIMULATION)
-- ============================================================================

local function distance(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

-- Apply spring forces (pull connected nodes together)
local function apply_spring_forces()
  local cfg = M.config.physics

  for _, edge in ipairs(M.graph.edges) do
    local source = M.graph.node_map[edge.source]
    local target = M.graph.node_map[edge.target]

    if source and target then
      local dx = target.x - source.x
      local dy = target.y - source.y
      local dist = distance(source.x, source.y, target.x, target.y)

      if dist > 0 then
        local force = (dist - cfg.spring_length) * cfg.spring_strength
        local fx = (dx / dist) * force
        local fy = (dy / dist) * force

        source.vx = source.vx + fx
        source.vy = source.vy + fy
        target.vx = target.vx - fx
        target.vy = target.vy - fy
      end
    end
  end
end

-- Apply repulsion forces (push all nodes apart)
local function apply_repulsion_forces()
  local cfg = M.config.physics
  local nodes = M.graph.nodes

  for i = 1, #nodes do
    for j = i + 1, #nodes do
      local n1 = nodes[i]
      local n2 = nodes[j]

      local dx = n2.x - n1.x
      local dy = n2.y - n1.y
      local dist = distance(n1.x, n1.y, n2.x, n2.y)

      if dist > 0 and dist < 300 then
        local force = cfg.repulsion / (dist * dist)
        local fx = (dx / dist) * force
        local fy = (dy / dist) * force

        n1.vx = n1.vx - fx
        n1.vy = n1.vy - fy
        n2.vx = n2.vx + fx
        n2.vy = n2.vy + fy
      end
    end
  end
end

-- Update node positions with damping
local function update_positions()
  local cfg = M.config.physics

  for _, node in ipairs(M.graph.nodes) do
    node.vx = node.vx * cfg.damping
    node.vy = node.vy * cfg.damping
    node.x = node.x + node.vx
    node.y = node.y + node.vy
  end
end

-- Run one iteration of physics simulation
function M.simulate_step()
  apply_spring_forces()
  apply_repulsion_forces()
  update_positions()
end

-- ============================================================================
-- RENDERING (TERMINAL + KITTY GRAPHICS)
-- ============================================================================

-- Get current note name
local function get_current_note()
  local current_file = vim.fn.expand('%:p')
  if current_file:match('%.md$') then
    return vim.fn.fnamemodify(current_file, ':t:r')
  end
  return nil
end

-- Get filtered nodes based on search term
local function get_filtered_nodes()
  if M.ui.filter_text == '' then
    return M.graph.nodes
  end

  local filtered = {}
  local filter_lower = M.ui.filter_text:lower()

  for _, node in ipairs(M.graph.nodes) do
    if node.id:lower():match(filter_lower) then
      table.insert(filtered, node)
    end
  end

  return filtered
end

-- Get filtered edges (only edges between visible nodes)
local function get_filtered_edges()
  local visible_nodes = get_filtered_nodes()
  local visible_map = {}
  for _, node in ipairs(visible_nodes) do
    visible_map[node.id] = true
  end

  local filtered_edges = {}
  for _, edge in ipairs(M.graph.edges) do
    if visible_map[edge.source] and visible_map[edge.target] then
      table.insert(filtered_edges, edge)
    end
  end

  return filtered_edges
end

-- Store node screen positions for mouse clicking
M.node_positions = {}

-- Draw a line using Bresenham's algorithm with improved aesthetics
local function draw_line(lines, highlights, x1, y1, x2, y2, width, height, density, connection_strength)
  density = density or 1.0
  connection_strength = connection_strength or 1

  local dx = math.abs(x2 - x1)
  local dy = math.abs(y2 - y1)
  local sx = x1 < x2 and 1 or -1
  local sy = y1 < y2 and 1 or -1
  local err = dx - dy
  local step_count = 0
  local total_steps = math.max(dx, dy)

  -- Use subtle characters for cleaner appearance
  local char, hl
  if connection_strength >= 5 then
    -- Strong connections - use solid but clean characters
    if dx > dy * 2 then
      char = '─'  -- Clean horizontal
    elseif dy > dx * 2 then
      char = '│'  -- Clean vertical
    elseif (sx == sy) then
      char = '╲'  -- Clean diagonal \
    else
      char = '╱'  -- Clean diagonal /
    end
    hl = 'Title'  -- Bright cyan for strong connections
  elseif connection_strength >= 3 then
    -- Medium connections - lighter but visible
    if dx > dy * 2 then
      char = '━'  -- Medium horizontal
    elseif dy > dx * 2 then
      char = '┃'  -- Medium vertical
    else
      char = '·'  -- Dots for diagonal
    end
    hl = 'WarningMsg'  -- Bright pink for medium connections
  else
    -- Light connections - very subtle
    char = '·'  -- Consistent dots for minimal connections
    hl = 'Keyword'  -- Bright purple for light connections
  end

  while true do
    step_count = step_count + 1

    -- Improved density pattern - always show endpoints and more of middle
    local near_endpoint = (step_count <= total_steps * 0.25) or (step_count >= total_steps * 0.75)
    local middle_section = step_count > total_steps * 0.25 and step_count < total_steps * 0.75

    local should_draw = near_endpoint or
      (density >= 1.0) or
      (middle_section and step_count % math.ceil(1.5/density) == 0)

    if should_draw and x1 >= 1 and x1 <= width and y1 >= 1 and y1 <= height then
      -- Only draw if cell is empty or contains weaker character
      local current_char = lines[y1]:sub(x1, x1)
      local current_priority = 0

      -- Set priority for existing characters
      if current_char == ' ' then current_priority = 0
      elseif current_char == '·' then current_priority = 1
      elseif current_char == '-' or current_char == '|' then current_priority = 2
      elseif current_char == '─' or current_char == '│' then current_priority = 3
      else current_priority = 4 end

      -- Set priority for new character
      local new_priority = connection_strength >= 5 and 3 or (connection_strength >= 3 and 2 or 1)

      if new_priority >= current_priority then
        local line = lines[y1]
        lines[y1] = line:sub(1, x1 - 1) .. char .. line:sub(x1 + 1)
        highlights[y1][x1] = hl
      end
    end

    if x1 == x2 and y1 == y2 then break end

    local e2 = 2 * err
    if e2 > -dy then
      err = err - dy
      x1 = x1 + sx
    end
    if e2 < dx then
      err = err + dx
      y1 = y1 + sy
    end
  end
end

-- Render using ASCII art
local function render_terminal()
  if not M.ui.buf or not api.nvim_buf_is_valid(M.ui.buf) then
    return
  end

  local width = api.nvim_win_get_width(M.ui.win)
  local height = api.nvim_win_get_height(M.ui.win)
  local center_x = width / 2
  local center_y = height / 2

  -- Create empty canvas with color support
  local lines = {}
  local highlights = {}
  for i = 1, height do
    lines[i] = string.rep(' ', width)
    highlights[i] = {}
  end

  -- Helper to set character at position with color
  local function set_char(x, y, char, hl_group)
    if y >= 1 and y <= height and x >= 1 and x <= width then
      local line = lines[y]
      lines[y] = line:sub(1, x - 1) .. char .. line:sub(x + 1)
      if hl_group then
        highlights[y][x] = hl_group
      end
    end
  end

  -- Get filtered data
  local visible_nodes = get_filtered_nodes()
  local visible_edges = get_filtered_edges()

  -- Filter to show only well-connected nodes
  local display_nodes = {}
  local current_note_name = get_current_note()

  for _, node in ipairs(visible_nodes) do
    local connection_count = #node.links + #node.backlinks

    -- Always show current node, otherwise filter by min_connections
    if node.id == current_note_name or
       connection_count >= M.config.min_connections or
       (M.ui.selected_node and node.id == M.ui.selected_node.id) then
      table.insert(display_nodes, node)
    end
  end

  -- If no nodes pass filter, show all connected nodes
  if #display_nodes == 0 then
    for _, node in ipairs(visible_nodes) do
      if #node.links > 0 or #node.backlinks > 0 then
        table.insert(display_nodes, node)
      end
    end
  end

  -- Create a map of visible node positions
  local visible_node_positions = {}
  for _, node in ipairs(display_nodes) do
    visible_node_positions[node.id] = {
      x = math.floor(center_x + node.x * M.ui.zoom / 10 + M.ui.offset_x),
      y = math.floor(center_y + node.y * M.ui.zoom / 10 + M.ui.offset_y)
    }
  end

  -- Draw edges only between visible nodes
  for _, edge in ipairs(visible_edges) do
    local source = M.graph.node_map[edge.source]
    local target = M.graph.node_map[edge.target]

    -- Only draw if BOTH nodes are in the visible/display set
    if source and target and visible_node_positions[edge.source] and visible_node_positions[edge.target] then
      local source_pos = visible_node_positions[edge.source]
      local target_pos = visible_node_positions[edge.target]

      local sx = source_pos.x
      local sy = source_pos.y
      local tx = target_pos.x
      local ty = target_pos.y

      -- Only draw if both endpoints are on screen
      if sx >= 1 and sx <= width and sy >= 1 and sy <= height and
         tx >= 1 and tx <= width and ty >= 1 and ty <= height then

        -- Calculate connection strength (how many connections each node has)
        local source_strength = #source.links + #source.backlinks
        local target_strength = #target.links + #target.backlinks
        local connection_strength = math.max(source_strength, target_strength)

        -- Draw lines with density control and strength indication
        draw_line(lines, highlights, sx, sy, tx, ty, width, height, M.config.line_density, connection_strength)
      end
    end
  end

  -- Draw nodes with halos and store positions for mouse clicks
  M.node_positions = {}
  local current_note = get_current_note()

  for _, node in ipairs(display_nodes) do
    local x = math.floor(center_x + node.x * M.ui.zoom / 10 + M.ui.offset_x)
    local y = math.floor(center_y + node.y * M.ui.zoom / 10 + M.ui.offset_y)

    -- Only draw if on screen
    if x >= 1 and x <= width and y >= 1 and y <= height then
      -- Store position for mouse clicking
      table.insert(M.node_positions, {
        node = node,
        x = x,
        y = y,
        radius = 3,
      })

      -- Clean node styling based on importance and type
      local connection_count = #node.links + #node.backlinks
      local char, hl_group, size

      if node.id == current_note then
        char = '●'  -- Current note - solid circle
        size = 3
        hl_group = 'ErrorMsg'  -- Hot pink for current note
      elseif M.ui.selected_node and M.ui.selected_node.id == node.id then
        char = '●'  -- Selected - solid circle
        size = 3
        hl_group = 'DiffAdd'  -- Bright green for selected
      elseif connection_count >= 5 then
        char = '○'  -- Hub nodes - large circle
        size = 2
        hl_group = 'WarningMsg'  -- Bright orange for hub nodes
      elseif connection_count >= 3 then
        char = '●'  -- Well-connected - medium circle
        size = 1
        hl_group = 'Title'  -- Bright cyan for regular nodes
      else
        char = '○'  -- Basic nodes - small circle
        size = 0
        hl_group = 'Keyword'  -- Bright purple for basic nodes
      end

      -- Clean Obsidian-style node rendering
      if size >= 3 then
        -- Current/Selected: clean emphasis without clutter
        set_char(x - 1, y, '◦', 'NonText')
        set_char(x, y, char, hl_group)
        set_char(x + 1, y, '◦', 'NonText')
      elseif size == 2 then
        -- Hub nodes: slightly larger with subtle indicators
        set_char(x - 1, y, '·', 'NonText')
        set_char(x, y, char, hl_group)
        set_char(x + 1, y, '·', 'NonText')
      elseif size == 1 then
        -- Regular nodes: clean single character
        set_char(x, y, char, hl_group)
      else
        -- Small nodes: minimal and subtle
        set_char(x, y, char, 'NonText')
      end

      -- Clean label rendering - only for selected/current nodes
      if node.id == current_note or (M.ui.selected_node and M.ui.selected_node.id == node.id) then
        local label = node.id:sub(1, 25)  -- Shorter for cleanliness
        local label_y = y - 2
        local label_x = x - math.floor(#label / 2)

        -- Draw label with clean styling
        for i = 1, #label do
          set_char(label_x + i - 1, label_y, label:sub(i, i), hl_group)
        end

        -- Bright connection count
        local count = string.format('%d', connection_count)
        local count_x = x - math.floor(#count / 2)
        for i = 1, #count do
          set_char(count_x + i - 1, y + 2, count:sub(i, i), 'Number')
        end

      elseif connection_count >= 6 then
        -- Only major hubs get labels to reduce clutter
        local label = node.id:sub(1, 15)
        local label_y = y + 2
        local label_x = x - math.floor(#label / 2)

        for i = 1, #label do
          set_char(label_x + i - 1, label_y, label:sub(i, i), 'Title')
        end
      end
    end
  end

  -- Add header with filter info
  local filter_info = M.ui.filter_text ~= '' and string.format(' [Filter: %s]', M.ui.filter_text) or ''

  -- Count hub nodes
  local hub_count = 0
  for _, node in ipairs(display_nodes) do
    if #node.links + #node.backlinks >= 5 then
      hub_count = hub_count + 1
    end
  end

  lines[1] = string.format(' Note Graph: %d nodes (%d hubs), %d connections%s',
    #display_nodes, hub_count, #visible_edges, filter_info)

  -- Add legend at bottom
  local legend_y = height - 1
  local min_conn_status = string.format(' [showing %d+ connections]', M.config.min_connections)
  local legend = string.format('  ◦●◦ Current  ·○· Hub  ● Node  ─ Strong · Light%s  |  q:quit /:filter +-:zoom hjkl:pan o:open w:web t:transparent', min_conn_status)
  if #legend <= width then
    for i = 1, math.min(#legend, width) do
      set_char(i, legend_y, legend:sub(i, i))
    end
  end


  -- Show helpful message if no nodes
  if #display_nodes == 0 then
    local msg_y = math.floor(height / 2)
    local msg = 'No connected notes to display'
    local msg_x = math.floor((width - #msg) / 2)
    for i = 1, #msg do
      set_char(msg_x + i - 1, msg_y, msg:sub(i, i), 'Comment')
    end

    if #M.graph.nodes == 0 then
      msg = 'No markdown files found in: ' .. M.config.notes_dir
      msg_x = math.floor((width - #msg) / 2)
      for i = 1, #msg do
        set_char(msg_x + i - 1, msg_y + 2, msg:sub(i, i), 'Comment')
      end
    else
      msg = 'Try creating links between notes using [[note-name]]'
      msg_x = math.floor((width - #msg) / 2)
      for i = 1, #msg do
        set_char(msg_x + i - 1, msg_y + 2, msg:sub(i, i), 'String')
      end
    end
  end

  -- Update buffer
  api.nvim_buf_set_option(M.ui.buf, 'modifiable', true)
  api.nvim_buf_set_lines(M.ui.buf, 0, -1, false, lines)

  -- Apply syntax highlighting
  vim.api.nvim_buf_clear_namespace(M.ui.buf, -1, 0, -1)
  for y, line_highlights in pairs(highlights) do
    for x, hl_group in pairs(line_highlights) do
      if y > 0 and y <= #lines and x > 0 then
        pcall(vim.api.nvim_buf_add_highlight, M.ui.buf, -1, hl_group, y - 1, x - 1, x)
      end
    end
  end

  api.nvim_buf_set_option(M.ui.buf, 'modifiable', false)
end

-- Render using kitty graphics protocol (advanced)
local function render_graphics()
  -- TODO: Implement kitty graphics rendering
  -- This would generate an actual PNG/SVG image and display it using kitty protocol
  -- For now, fall back to terminal rendering
  render_terminal()
end

function M.render()
  if M.config.use_graphics and vim.fn.exists('$TERM') and vim.env.TERM:match('kitty') then
    render_graphics()
  else
    render_terminal()
  end
end

-- ============================================================================
-- USER INTERACTION & CONTROLS
-- ============================================================================

-- Find nearest node to screen center
local function find_nearest_node()
  local width = api.nvim_win_get_width(M.ui.win)
  local height = api.nvim_win_get_height(M.ui.win)
  local center_x = width / 2
  local center_y = height / 2

  local nearest = nil
  local min_dist = math.huge

  for _, node in ipairs(M.graph.nodes) do
    local x = center_x + node.x * M.ui.zoom / 10 + M.ui.offset_x
    local y = center_y + node.y * M.ui.zoom / 10 + M.ui.offset_y
    local dist = distance(x, y, center_x, center_y)

    if dist < min_dist then
      min_dist = dist
      nearest = node
    end
  end

  return nearest
end

-- Open selected note
local function open_note()
  if M.ui.selected_node then
    local node_path = M.ui.selected_node.path
    M.close()
    vim.cmd('edit ' .. vim.fn.fnameescape(node_path))
  end
end

-- Filter graph by search term
local function filter_graph()
  vim.ui.input({
    prompt = 'Filter notes (empty to clear): ',
    default = M.ui.filter_text
  }, function(search)
    if search == nil then
      return
    end

    M.ui.filter_text = search or ''
    M.render()

    local filtered_count = #get_filtered_nodes()
    vim.notify(string.format('Showing %d/%d notes', filtered_count, #M.graph.nodes),
      vim.log.levels.INFO)
  end)
end

-- Handle mouse click on node
local function handle_mouse_click(mouse_row, mouse_col)
  -- Find clicked node
  for _, pos in ipairs(M.node_positions) do
    local dx = math.abs(pos.x - mouse_col)
    local dy = math.abs(pos.y - mouse_row)

    if dx <= pos.radius and dy <= pos.radius then
      M.ui.selected_node = pos.node
      M.render()
      vim.notify(string.format('Selected: %s (%d connections)',
        pos.node.id, #pos.node.links + #pos.node.backlinks), vim.log.levels.INFO)
      return true
    end
  end

  return false
end

-- Set up keybindings
local function setup_keymaps()
  local opts = { silent = true, noremap = true }

  -- Close window
  vim.keymap.set('n', 'q', function() require("note-graph").close() end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Close graph' }))
  vim.keymap.set('n', '<Esc>', function() require("note-graph").close() end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Close graph' }))

  -- Open note
  vim.keymap.set('n', '<CR>', function() require("note-graph").open_selected() end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Open note' }))
  vim.keymap.set('n', 'o', function() require("note-graph").open_selected() end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Open note' }))

  -- Pan
  vim.keymap.set('n', 'h', function() require("note-graph").pan(-5, 0) end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Pan left' }))
  vim.keymap.set('n', 'l', function() require("note-graph").pan(5, 0) end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Pan right' }))
  vim.keymap.set('n', 'k', function() require("note-graph").pan(0, -3) end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Pan up' }))
  vim.keymap.set('n', 'j', function() require("note-graph").pan(0, 3) end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Pan down' }))

  -- Zoom
  vim.keymap.set('n', '+', function() require("note-graph").zoom(1.1) end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Zoom in' }))
  vim.keymap.set('n', '-', function() require("note-graph").zoom(0.9) end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Zoom out' }))
  vim.keymap.set('n', '=', function() require("note-graph").zoom(1.1) end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Zoom in' }))

  -- Filter
  vim.keymap.set('n', '/', function() require("note-graph").filter() end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Filter notes' }))
  vim.keymap.set('n', 'f', function() require("note-graph").filter() end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Filter notes' }))

  -- Web view
  vim.keymap.set('n', 'w', function() require("note-graph").open_web_view() end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Open web view' }))

  -- Focus on current note
  vim.keymap.set('n', 'c', function() require("note-graph").focus_current() end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Focus current' }))

  -- Toggle isolated nodes
  vim.keymap.set('n', 'i', function() require("note-graph").toggle_isolated() end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Toggle isolated nodes' }))

  -- Toggle transparency
  vim.keymap.set('n', 't', function() require("note-graph").toggle_transparency() end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Toggle transparency' }))

  -- Mouse click handler
  vim.keymap.set('n', '<LeftMouse>', function() require("note-graph").handle_click() end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Click node' }))
  vim.keymap.set('n', '<2-LeftMouse>', function() require("note-graph").handle_double_click() end,
    vim.tbl_extend('force', opts, { buffer = M.ui.buf, desc = 'Open node' }))
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function M.pan(dx, dy)
  M.ui.offset_x = M.ui.offset_x + dx
  M.ui.offset_y = M.ui.offset_y + dy
  M.render()
end

function M.zoom(factor)
  M.ui.zoom = M.ui.zoom * factor
  M.render()
end

function M.open_selected()
  if not M.ui.selected_node then
    vim.notify('No node selected', vim.log.levels.WARN)
    return
  end
  open_note()
end

function M.filter()
  filter_graph()
end

function M.handle_click()
  local mouse = vim.fn.getmousepos()
  local mouse_row = mouse.line
  local mouse_col = mouse.column

  -- Single click just selects the node (selection and notification handled in handle_mouse_click)
  handle_mouse_click(mouse_row, mouse_col)
end

function M.handle_double_click()
  local mouse = vim.fn.getmousepos()
  local mouse_row = mouse.line
  local mouse_col = mouse.column

  if handle_mouse_click(mouse_row, mouse_col) then
    -- Double click opens the note immediately
    M.open_selected()
  end
end

function M.open_web_view()
  local renderer = require('note-graph-renderer')
  local current_note = get_current_note()

  -- Use filtered nodes for web view
  local visible_nodes = get_filtered_nodes()
  local visible_edges = get_filtered_edges()

  renderer.render_web(visible_nodes, visible_edges, current_note)
end

function M.focus_current()
  local current_note = get_current_note()
  if current_note and M.graph.node_map[current_note] then
    M.ui.selected_node = M.graph.node_map[current_note]
    -- Center the view on current note
    M.ui.offset_x = 0
    M.ui.offset_y = 0
    M.ui.zoom = 1.0
    M.render()
    vim.notify('Focused on: ' .. current_note, vim.log.levels.INFO)
  else
    vim.notify('No current note open', vim.log.levels.WARN)
  end
end

function M.toggle_isolated()
  M.config.show_isolated = not M.config.show_isolated
  M.render()
  local status = M.config.show_isolated and 'Showing all notes' or 'Showing only connected notes'
  vim.notify(status, vim.log.levels.INFO)
end

function M.toggle_transparency()
  if M.config.transparency == 0 then
    M.config.transparency = 20
  else
    M.config.transparency = 0
  end

  if M.ui.win and api.nvim_win_is_valid(M.ui.win) then
    vim.api.nvim_set_option_value('winblend', M.config.transparency, { win = M.ui.win })
  end

  local status = M.config.transparency == 0 and 'Transparency disabled' or string.format('Transparency set to %d%%', M.config.transparency)
  vim.notify(status, vim.log.levels.INFO)
end

function M.close()
  if M.ui.animation_timer then
    M.ui.animation_timer:stop()
    M.ui.animation_timer:close()
    M.ui.animation_timer = nil
  end

  if M.ui.win and api.nvim_win_is_valid(M.ui.win) then
    api.nvim_win_close(M.ui.win, true)
  end

  if M.ui.buf and api.nvim_buf_is_valid(M.ui.buf) then
    api.nvim_buf_delete(M.ui.buf, { force = true })
  end

  M.ui = {
    buf = nil,
    win = nil,
    selected_node = nil,
    offset_x = 0,
    offset_y = 0,
    zoom = 1.0,
    animation_timer = nil,
    canvas = nil,
    filter_text = '',
    render_mode = 'terminal',
  }
end

-- Calculate bounding box of all nodes
local function calculate_bounding_box(nodes)
  if #nodes == 0 then return 0, 0, 0, 0 end

  local min_x, max_x = math.huge, -math.huge
  local min_y, max_y = math.huge, -math.huge

  for _, node in ipairs(nodes) do
    min_x = math.min(min_x, node.x)
    max_x = math.max(max_x, node.x)
    min_y = math.min(min_y, node.y)
    max_y = math.max(max_y, node.y)
  end

  return min_x, max_x, min_y, max_y
end

-- Center and scale graph to fit window
local function center_and_scale_graph()
  if #M.graph.nodes == 0 then return end

  -- Check if window is still valid
  if not M.ui.win or not api.nvim_win_is_valid(M.ui.win) then
    return
  end

  local width = api.nvim_win_get_width(M.ui.win)
  local height = api.nvim_win_get_height(M.ui.win)

  -- Calculate current bounding box
  local min_x, max_x, min_y, max_y = calculate_bounding_box(M.graph.nodes)

  -- Calculate graph dimensions
  local graph_width = max_x - min_x
  local graph_height = max_y - min_y

  if graph_width == 0 or graph_height == 0 then return end

  -- Calculate center of graph
  local graph_center_x = (min_x + max_x) / 2
  local graph_center_y = (min_y + max_y) / 2

  -- Calculate scale to fit in 80% of window
  local scale_x = (width * 0.8) / (graph_width / 10)
  local scale_y = (height * 0.8) / (graph_height / 10)
  local scale = math.min(scale_x, scale_y, 2.0) -- Max zoom of 2x

  -- Center the graph
  M.ui.offset_x = -graph_center_x * scale / 10
  M.ui.offset_y = -graph_center_y * scale / 10
  M.ui.zoom = scale
end

function M.open()
  -- Build graph
  if not M.build_graph() then
    return
  end

  if #M.graph.nodes == 0 then
    vim.notify('No notes found', vim.log.levels.WARN)
    return
  end

  -- Create floating window
  M.ui.buf = api.nvim_create_buf(false, true)

  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  M.ui.win = api.nvim_open_win(M.ui.buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
  })

  -- Buffer options
  api.nvim_buf_set_option(M.ui.buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(M.ui.buf, 'filetype', 'notegraph')
  api.nvim_buf_set_option(M.ui.buf, 'modifiable', false)

  -- Window options for better visuals
  vim.api.nvim_set_option_value('cursorline', false, { win = M.ui.win })
  vim.api.nvim_set_option_value('wrap', false, { win = M.ui.win })
  vim.api.nvim_set_option_value('signcolumn', 'no', { win = M.ui.win })

  -- Set transparency
  vim.api.nvim_set_option_value('winblend', M.config.transparency, { win = M.ui.win })

  -- Set up keybindings
  setup_keymaps()

  -- Select current note if open
  local current_note = get_current_note()
  if current_note then
    M.ui.selected_node = M.graph.node_map[current_note]
  else
    M.ui.selected_node = M.graph.nodes[1]
  end

  -- Initialize view centering
  M.ui.offset_x = 0
  M.ui.offset_y = 0
  M.ui.zoom = 1.0

  -- Animate layout with periodic centering
  local iteration = 0
  M.ui.animation_timer = uv.new_timer()
  M.ui.animation_timer:start(0, 16, vim.schedule_wrap(function()
    -- Check if window is still valid before continuing
    if not M.ui.win or not api.nvim_win_is_valid(M.ui.win) then
      if M.ui.animation_timer then
        M.ui.animation_timer:stop()
      end
      return
    end

    iteration = iteration + 1

    if iteration <= M.config.physics.iterations then
      M.simulate_step()

      -- Center and scale during animation at key points
      if iteration == 50 or iteration == 100 or iteration == M.config.physics.iterations then
        center_and_scale_graph()
      end

      if iteration % 3 == 0 then -- Update display every 3 frames
        M.render()
      end
    else
      -- Final centering and scaling
      center_and_scale_graph()
      M.render()
      if M.ui.animation_timer then
        M.ui.animation_timer:stop()
      end
    end
  end))
end

return M
