-- Advanced renderer for note-graph
-- Supports kitty graphics protocol and clustering

local M = {}

-- ============================================================================
-- CLUSTERING FOR LARGE GRAPHS
-- ============================================================================

-- K-means clustering to group nodes
function M.cluster_nodes(nodes, num_clusters)
  if #nodes <= num_clusters then
    return { nodes }
  end

  -- Initialize centroids randomly
  local centroids = {}
  local used = {}
  for i = 1, num_clusters do
    local idx
    repeat
      idx = math.random(1, #nodes)
    until not used[idx]
    used[idx] = true
    centroids[i] = { x = nodes[idx].x, y = nodes[idx].y, nodes = {} }
  end

  -- Run k-means for 10 iterations
  for iteration = 1, 10 do
    -- Clear clusters
    for _, centroid in ipairs(centroids) do
      centroid.nodes = {}
    end

    -- Assign nodes to nearest centroid
    for _, node in ipairs(nodes) do
      local min_dist = math.huge
      local nearest_cluster = 1

      for i, centroid in ipairs(centroids) do
        local dx = node.x - centroid.x
        local dy = node.y - centroid.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist < min_dist then
          min_dist = dist
          nearest_cluster = i
        end
      end

      table.insert(centroids[nearest_cluster].nodes, node)
    end

    -- Recalculate centroids
    for _, centroid in ipairs(centroids) do
      if #centroid.nodes > 0 then
        local sum_x, sum_y = 0, 0
        for _, node in ipairs(centroid.nodes) do
          sum_x = sum_x + node.x
          sum_y = sum_y + node.y
        end
        centroid.x = sum_x / #centroid.nodes
        centroid.y = sum_y / #centroid.nodes
      end
    end
  end

  return centroids
end

-- ============================================================================
-- KITTY GRAPHICS PROTOCOL RENDERER
-- ============================================================================

-- Generate SVG representation of graph
function M.generate_svg(nodes, edges, width, height, opts)
  opts = opts or {}
  local selected = opts.selected
  local current = opts.current
  local zoom = opts.zoom or 1.0
  local offset_x = opts.offset_x or 0
  local offset_y = opts.offset_y or 0

  local colors = {
    bg = '#1e1e2e',
    node = '#89b4fa',
    current = '#f38ba8',
    selected = '#a6e3a1',
    link = '#45475a',
    label = '#cdd6f4',
  }

  local center_x = width / 2
  local center_y = height / 2

  local svg = {
    string.format('<svg width="%d" height="%d" xmlns="http://www.w3.org/2000/svg">', width, height),
    string.format('<rect width="%d" height="%d" fill="%s"/>', width, height, colors.bg),
    '<g id="edges">',
  }

  -- Draw edges
  for _, edge in ipairs(edges) do
    local source = nil
    local target = nil

    for _, node in ipairs(nodes) do
      if node.id == edge.source then source = node end
      if node.id == edge.target then target = node end
    end

    if source and target then
      local sx = center_x + source.x * zoom + offset_x
      local sy = center_y + source.y * zoom + offset_y
      local tx = center_x + target.x * zoom + offset_x
      local ty = center_y + target.y * zoom + offset_y

      table.insert(svg, string.format(
        '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="1" opacity="0.3"/>',
        sx, sy, tx, ty, colors.link
      ))
    end
  end

  table.insert(svg, '</g>')
  table.insert(svg, '<g id="nodes">')

  -- Draw nodes
  for _, node in ipairs(nodes) do
    local x = center_x + node.x * zoom + offset_x
    local y = center_y + node.y * zoom + offset_y

    local color = colors.node
    local radius = 5

    if node.id == current then
      color = colors.current
      radius = 7
    elseif selected and node.id == selected.id then
      color = colors.selected
      radius = 7
    end

    -- Node circle
    table.insert(svg, string.format(
      '<circle cx="%.1f" cy="%.1f" r="%d" fill="%s" stroke="#fff" stroke-width="1"/>',
      x, y, radius, color
    ))

    -- Label for important nodes
    if node.id == current or (selected and node.id == selected.id) then
      local label = node.id:sub(1, 30)
      table.insert(svg, string.format(
        '<text x="%.1f" y="%.1f" fill="%s" font-family="monospace" font-size="12" text-anchor="middle">%s</text>',
        x, y - 12, colors.label, label
      ))
    end

    -- Connection count
    local connection_count = #node.links + #node.backlinks
    if connection_count > 0 then
      table.insert(svg, string.format(
        '<text x="%.1f" y="%.1f" fill="%s" font-family="monospace" font-size="8" text-anchor="middle">%d</text>',
        x, y + 3, '#000', connection_count
      ))
    end
  end

  table.insert(svg, '</g>')
  table.insert(svg, '</svg>')

  return table.concat(svg, '\n')
end

-- Render SVG using kitty graphics protocol
function M.render_kitty(svg_content, buf)
  -- Save SVG to temp file
  local tmp_file = vim.fn.tempname() .. '.svg'
  local file = io.open(tmp_file, 'w')
  if not file then
    return false
  end
  file:write(svg_content)
  file:close()

  -- Convert SVG to PNG using ImageMagick/rsvg-convert if available
  local png_file = vim.fn.tempname() .. '.png'

  -- Try rsvg-convert first (better quality)
  local convert_cmd = string.format('rsvg-convert "%s" -o "%s" 2>/dev/null || convert "%s" "%s" 2>/dev/null',
    tmp_file, png_file, tmp_file, png_file)

  local result = os.execute(convert_cmd)

  if result == 0 and vim.fn.filereadable(png_file) == 1 then
    -- Use image.nvim to display
    local ok, image_nvim = pcall(require, 'image')
    if ok then
      -- Clear previous images
      if M.current_image then
        pcall(function() M.current_image:clear() end)
      end

      -- Render new image
      M.current_image = image_nvim.from_file(png_file, {
        buffer = buf,
        inline = true,
      })

      -- Clean up temp files
      vim.defer_fn(function()
        os.remove(tmp_file)
        os.remove(png_file)
      end, 100)

      return true
    end
  end

  -- Clean up
  os.remove(tmp_file)
  if vim.fn.filereadable(png_file) == 1 then
    os.remove(png_file)
  end

  return false
end

-- ============================================================================
-- WEB-BASED RENDERER (FALLBACK)
-- ============================================================================

-- Generate HTML with D3.js for interactive web view
function M.generate_html(nodes, edges, current_note)
  local html_template = [[
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {
      margin: 0;
      padding: 0;
      overflow: hidden;
      background: #1e1e2e;
      font-family: monospace;
    }
    svg {
      width: 100vw;
      height: 100vh;
    }
    .links line {
      stroke: #45475a;
      stroke-opacity: 0.6;
      stroke-width: 1.5px;
    }
    .nodes circle {
      stroke: #fff;
      stroke-width: 1.5px;
      cursor: pointer;
    }
    .nodes circle:hover {
      stroke-width: 3px;
    }
    .labels text {
      fill: #cdd6f4;
      font-size: 10px;
      pointer-events: none;
      text-anchor: middle;
    }
    .tooltip {
      position: absolute;
      background: #313244;
      color: #cdd6f4;
      padding: 8px;
      border-radius: 4px;
      font-size: 12px;
      pointer-events: none;
      opacity: 0;
      transition: opacity 0.3s;
    }
    .info {
      position: absolute;
      top: 10px;
      left: 10px;
      background: #313244;
      color: #cdd6f4;
      padding: 10px;
      border-radius: 4px;
      font-size: 12px;
    }
  </style>
</head>
<body>
  <div class="info">
    <div>Notes: <span id="node-count"></span></div>
    <div>Links: <span id="edge-count"></span></div>
    <div>Drag nodes | Scroll to zoom</div>
  </div>
  <div class="tooltip" id="tooltip"></div>
  <svg></svg>
  <script src="https://d3js.org/d3.v7.min.js"></script>
  <script>
    const data = DATA_PLACEHOLDER;

    const width = window.innerWidth;
    const height = window.innerHeight;

    const svg = d3.select("svg");
    const g = svg.append("g");

    // Zoom behavior
    const zoom = d3.zoom()
      .scaleExtent([0.1, 10])
      .on("zoom", (event) => {
        g.attr("transform", event.transform);
      });

    svg.call(zoom);

    // Force simulation
    const simulation = d3.forceSimulation(data.nodes)
      .force("link", d3.forceLink(data.edges).id(d => d.id).distance(100))
      .force("charge", d3.forceManyBody().strength(-300))
      .force("center", d3.forceCenter(width / 2, height / 2))
      .force("collision", d3.forceCollide().radius(20));

    // Draw edges
    const link = g.append("g")
      .attr("class", "links")
      .selectAll("line")
      .data(data.edges)
      .enter().append("line");

    // Draw nodes
    const node = g.append("g")
      .attr("class", "nodes")
      .selectAll("circle")
      .data(data.nodes)
      .enter().append("circle")
      .attr("r", d => d.id === data.current ? 8 : 5)
      .attr("fill", d => {
        if (d.id === data.current) return "#f38ba8";
        return "#89b4fa";
      })
      .call(d3.drag()
        .on("start", dragstarted)
        .on("drag", dragged)
        .on("end", dragended))
      .on("click", (event, d) => {
        // Copy filename to clipboard
        navigator.clipboard.writeText(d.id);
        showTooltip(event, "Copied: " + d.id);
      })
      .on("mouseover", (event, d) => {
        const connections = data.edges.filter(e =>
          e.source.id === d.id || e.target.id === d.id
        ).length;
        showTooltip(event, `${d.id}\n${connections} connections`);
      })
      .on("mouseout", hideTooltip);

    // Labels for important nodes
    const label = g.append("g")
      .attr("class", "labels")
      .selectAll("text")
      .data(data.nodes.filter(d => d.id === data.current))
      .enter().append("text")
      .text(d => d.id.substring(0, 30))
      .attr("dy", -12);

    // Update positions on tick
    simulation.on("tick", () => {
      link
        .attr("x1", d => d.source.x)
        .attr("y1", d => d.source.y)
        .attr("x2", d => d.target.x)
        .attr("y2", d => d.target.y);

      node
        .attr("cx", d => d.x)
        .attr("cy", d => d.y);

      label
        .attr("x", d => d.x)
        .attr("y", d => d.y);
    });

    // Drag handlers
    function dragstarted(event) {
      if (!event.active) simulation.alphaTarget(0.3).restart();
      event.subject.fx = event.subject.x;
      event.subject.fy = event.subject.y;
    }

    function dragged(event) {
      event.subject.fx = event.x;
      event.subject.fy = event.y;
    }

    function dragended(event) {
      if (!event.active) simulation.alphaTarget(0);
      event.subject.fx = null;
      event.subject.fy = null;
    }

    // Tooltip
    const tooltip = d3.select("#tooltip");
    function showTooltip(event, text) {
      tooltip
        .style("left", (event.pageX + 10) + "px")
        .style("top", (event.pageY + 10) + "px")
        .style("opacity", 1)
        .text(text);
    }

    function hideTooltip() {
      tooltip.style("opacity", 0);
    }

    // Update info
    document.getElementById("node-count").textContent = data.nodes.length;
    document.getElementById("edge-count").textContent = data.edges.length;
  </script>
</body>
</html>
]]

  -- Prepare data
  local nodes_json = {}
  for _, node in ipairs(nodes) do
    table.insert(nodes_json, string.format(
      '{id:"%s",x:%d,y:%d}',
      node.id:gsub('"', '\\"'), node.x or 0, node.y or 0
    ))
  end

  local edges_json = {}
  for _, edge in ipairs(edges) do
    table.insert(edges_json, string.format(
      '{source:"%s",target:"%s"}',
      edge.source:gsub('"', '\\"'), edge.target:gsub('"', '\\"')
    ))
  end

  local data_json = string.format(
    '{nodes:[%s],edges:[%s],current:"%s"}',
    table.concat(nodes_json, ','),
    table.concat(edges_json, ','),
    current_note or ''
  )

  return html_template:gsub('DATA_PLACEHOLDER', data_json)
end

-- Open web-based graph view in browser
function M.render_web(nodes, edges, current_note)
  local html = M.generate_html(nodes, edges, current_note)
  local tmp_file = vim.fn.tempname() .. '.html'

  local file = io.open(tmp_file, 'w')
  if not file then
    vim.notify('Failed to create HTML file', vim.log.levels.ERROR)
    return false
  end

  file:write(html)
  file:close()

  -- Open in default browser
  local open_cmd
  if vim.fn.has('mac') == 1 then
    open_cmd = 'open'
  elseif vim.fn.has('unix') == 1 then
    open_cmd = 'xdg-open'
  else
    vim.notify('Unsupported platform for web view', vim.log.levels.ERROR)
    return false
  end

  vim.fn.jobstart({open_cmd, tmp_file}, {detach = true})
  vim.notify('Opening graph in browser...', vim.log.levels.INFO)

  return true
end

return M
