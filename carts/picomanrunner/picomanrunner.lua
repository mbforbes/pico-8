--picoman runner hybrid

--initialize the game
function _init()
  --set transparencies
  palt(15, true)
  palt(0, false)

  --configure items FIRST to ensure they aren't detected as walls
  --dots (flag 6, clear flag 0)
  fset(4, 6, true)
  fset(4, 0, false)

  --fruits (flag 7, clear flag 0)
  for i = 32, 35 do
    fset(i, 7, true) fset(i, 0, false)
  end

  --detect wall sprite (flag 0)
  wall_spr = 64
  -- default fallback (0x40)
  for i = 1, 255 do
    if fget(i, 0) then
      wall_spr = i break
    end
  end

  --load high score
  cartdata("picomanrunner")
  hi_score = dget(0)

  start_level(1)
  music(0)
end

--game stats
lives = 3
score = 0
game_time = 0
curr_level = 1
max_levels = 20
game_won = false
door_pos = { x = 15, y = 7 }

--player object
player = {
  x = 8,
  y = 56, -- centered vertically (7*8)
  speed = 2,
  v_speed = 0,
  h_speed = 0,
  dir = -1,
  next_dir = -1,
  anim = {
    first = 1,
    last = 3,
    speed = 0.34,
    frame = 1,
    flip_x = false,
    flip_y = false
  }
}

--constructors
function new_dot(_id, _x, _y)
  return {
    id = _id,
    x = _x,
    y = _y,
    flag = 4,
    frame = 4
  }
end

function new_pellet(_id, _x, _y, _frame)
  return {
    id = _id,
    x = _x,
    y = _y,
    flag = 5,
    frame = _frame or 5
  }
end

function new_ghost(_id, _x, _y, _type_idx)
  -- type_idx 0..3 maps to sprite colors
  local _frame = (16 * _type_idx) + 6
  return {
    id = _id,
    x = _x,
    y = _y,
    dx = 0,
    dy = 0,
    dir = 4, --start facing up
    mode = 0, --search mode
    value = 200,
    frame = _frame,
    orig_frame = _frame,
    speed = 1,
    home = { x = _x, y = _y },
    released = true,
    release_time = 0,
    target = { x = 0, y = 0 },
    hide_timer = 0,
    type_idx = _type_idx
  }
end

--tables
dots = {}
pellets = {}
ghosts = {}
dirs = {
  { x = 1, y = 0 }, --right
  { x = -1, y = 0 }, --left
  { x = 0, y = 1 }, --down
  { x = 0, y = -1 } --up
}
mode_schedule = {
  { mode = 0, time = 7 }, -- search
  { mode = 1, time = 20 } -- chase
}

--mode state
mode_index = 1
mode_timer = mode_schedule[1].time * 30
current_mode = mode_schedule[1].mode

-- Level Generation
function start_level(n)
  curr_level = n

  if n > max_levels then
    game_won = true
    return
  end

  dots = {}
  pellets = {}
  ghosts = {}
  gate_open_sfx_played = false
  dead_timer = 0

  -- Clear map
  for x = 0, 15 do
    for y = 0, 15 do
      mset(x, y, 0)
    end
  end

  generate_level(n)
  scan_map_for_items()
  spawn_enemies(n)

  -- Reset Player velocity
  player.h_speed = 0
  player.v_speed = 0
  player.dir = -1
  player.next_dir = -1
  player.anim.frame = 1

  game_time = 0

  -- Reset Ghost Modes
  mode_index = 1
  current_mode = mode_schedule[1].mode
  mode_timer = mode_schedule[1].time * 30
end

function generate_level(n)
  -- Map Dimensions based on level (start small, max 15)
  local size = min(9 + n, 15)
  local w, h = size, size

  -- Draw Borders
  for x = 0, w do
    mset(x, 0, wall_spr)
    mset(x, h, wall_spr)
  end
  for y = 0, h do
    mset(0, y, wall_spr)
    mset(w, y, wall_spr)
  end

  -- Entrance and Exit
  local start_y = flr(h / 2)
  mset(1, start_y, 0)
  player.x = 8
  player.y = start_y * 8

  local exit_y = flr(h / 2)
  mset(w, exit_y, wall_spr)
  -- Blocked Exit
  door_pos = { x = w, y = exit_y }

  -- Place Geometric Obstacles (Rectangles)
  local num_obstacles = 2 + flr(n / 2)
  for i = 1, num_obstacles do
    local ox = 2 + flr(rnd(w - 4))
    local oy = 2 + flr(rnd(h - 4))
    local ow = 1 + flr(rnd(3)) -- width 1-3
    local oh = 1 + flr(rnd(3)) -- height 1-3

    for xx = ox, min(ox + ow, w - 1) do
      for yy = oy, min(oy + oh, h - 1) do
        mset(xx, yy, wall_spr)
      end
    end
  end

  -- Ensure path exists
  if not check_path(1, start_y, w - 1, exit_y, w, h) then
    -- If blocked, clear a central corridor
    for x = 1, w - 1 do
      mset(x, start_y, 0)
    end
  end

  -- Place Fruits (before scan so they become items)
  local num_ghosts = 0
  if n >= 3 then
    num_ghosts = 1 + flr((n - 3) / 2)
  end
  local num_fruits = 0
  if num_ghosts > 0 then
    num_fruits = flr((num_ghosts + 2) / 3)
  end

  for i = 1, num_fruits do
    local fx, fy
    repeat
      fx = 2 + flr(rnd(w - 3))
      fy = 1 + flr(rnd(h - 2))
    until not fget(mget(fx, fy), 0)
    local fspr = 32 + flr(rnd(4))
    mset(fx, fy, fspr)
  end

  -- Place Dots
  local dot_chance = 0.3
  for x = 1, w - 1 do
    for y = 1, h - 1 do
      if mget(x, y) == 0 then
        if rnd() < dot_chance then
          mset(x, y, 4) -- Sprite 4 (Dot)
        end
      end
    end
  end
end

function check_path(sx, sy, ex, ey, w, h)
  local q = {}
  add(q, { x = sx, y = sy })
  local visited = {}
  visited[sx .. "," .. sy] = true

  local head = 1
  while head <= #q do
    local curr = q[head]
    head += 1

    if curr.x == ex and curr.y == ey then return true end

    local neighbors = { { x = 1, y = 0 }, { x = -1, y = 0 }, { x = 0, y = 1 }, { x = 0, y = -1 } }
    for n in all(neighbors) do
      local nx, ny = curr.x + n.x, curr.y + n.y
      if nx >= 1 and nx <= w and ny >= 1 and ny <= h then
        if not fget(mget(nx, ny), 0) and not visited[nx .. "," .. ny] then
          visited[nx .. "," .. ny] = true
          add(q, { x = nx, y = ny })
        end
      end
    end
  end
  return false
end

function spawn_enemies(n)
  local num_ghosts = 0
  if n >= 3 then
    num_ghosts = 1 + flr((n - 3) / 2)
  end

  local size = min(9 + n, 15)
  local w, h = size, size

  for i = 0, num_ghosts - 1 do
    local type_idx = i % 4
    local gx, gy
    repeat
      gx = 2 + flr(rnd(w - 3))
      gy = 1 + flr(rnd(h - 2))
    until not fget(mget(gx, gy), 0)
    -- dots are already cleared by scan_map, so space is 0

    add(ghosts, new_ghost(i, gx * 8, gy * 8, type_idx))
  end
end

function scan_map_for_items()
  for i = 0, 15 do
    for j = 0, 15 do
      local _spr = mget(i, j)
      if fget(_spr, 6) then
        -- dot
        add(dots, new_dot(#dots, i * 8, j * 8))
        mset(i, j, 0)
      end
      if fget(_spr, 7) then
        -- pellet/fruit
        add(pellets, new_pellet(#pellets, i * 8, j * 8, _spr))
        mset(i, j, 0)
      end
    end
  end
end

--utility functions
function animate(_obj, _x, _y, _flip_x, _flip_y, _mode)
  spr(_obj.anim.frame, _x, _y, 1, 1, _flip_x, _flip_y)
  _obj.anim.frame += _obj.anim.speed

  if _mode == 0 then
    if _obj.anim.frame >= _obj.anim.last + 1 then
      _obj.anim.frame = _obj.anim.first
    end
  elseif _mode == 1 then
    if _obj.anim.frame >= _obj.anim.last + 1 then
      _obj.anim.frame = _obj.anim.last
      _obj.anim.speed = 0
    end
  elseif _mode == 2 then
    if _obj.anim.frame >= _obj.anim.last + 1 then
      _obj.anim.frame = _obj.anim.last
      _obj.anim.speed = _obj.anim.speed * -1
    elseif _obj.anim.frame <= _obj.anim.first then
      _obj.anim.frame = _obj.anim.first + 1
      _obj.anim.speed = _obj.anim.speed * -1
    end
  end
end

function clamp_position(obj)
  if obj.x < -8 then obj.x = -8 end
  if obj.x > 128 then obj.x = 128 end
  if obj.y < 0 then obj.y = 0 end
  if obj.y > 120 then obj.y = 120 end
end

function can_move_vert(obj)
  return true
end

function update_ghost_target(g)
  if g.type_idx == 0 then
    -- blinky
    g.target.x = player.x
    g.target.y = player.y
  elseif g.type_idx == 1 then
    -- pinky
    g.target.x = player.x + player.h_speed * 16
    g.target.y = player.y + player.v_speed * 16
  elseif g.type_idx == 2 then
    -- inky
    g.target.x = player.x
    g.target.y = player.y - 16
  elseif g.type_idx == 3 then
    -- clyde
    g.target.x = 0
    g.target.y = 120
  end
end

function draw_ghosts()
  for g in all(ghosts) do
    spr(g.frame, g.x, g.y)
  end
end

function can_move(g, dir)
  if g.mode == 3 then return true end

  local nx = g.x + dir.x * 8
  local ny = g.y + dir.y * 8
  local tx = flr((nx + 4) / 8)
  local ty = flr((ny + 4) / 8)

  if tx < 0 or tx > 15 or ty < 0 or ty > 15 then return false end
  local spr = mget(tx, ty)
  if fget(spr, 0) then return false end
  -- wall
  if fget(spr, 1) then return false end
  -- gate
  return true
end

function at_center(g)
  return g.x % 8 == 0 and g.y % 8 == 0
end

function get_valid_dirs(g)
  local options = {}
  for i, d in ipairs(dirs) do
    if d.x ~= -g.dx or d.y ~= -g.dy then
      if can_move(g, d) then
        add(options, i)
      end
    end
  end
  return options
end

function ghost_search(g)
  local options = get_valid_dirs(g)
  if #options > 0 then
    g.dir = options[flr(rnd(#options)) + 1]
  end
end

function ghost_chase(g, tx, ty)
  local options = get_valid_dirs(g)
  local best = nil
  local best_dist = 9999
  for i in all(options) do
    local d = dirs[i]
    local nx = g.x + d.x * 8
    local ny = g.y + d.y * 8
    local dist = abs(nx - tx) + abs(ny - ty)
    if dist < best_dist or (dist == best_dist and rnd() < 0.5) then
      best_dist = dist
      best = i
    end
  end
  if best then g.dir = best end
end

function ghost_hide(g)
  g.dx = -g.dx
  g.dy = -g.dy
end

function ghost_retreat(g)
  ghost_chase(g, g.home.x, g.home.y)
end

function move_ghost(g)
  if g.mode == 2 then
    g.hide_timer -= 1
    if g.hide_timer <= 0 then
      g.mode = current_mode
      g.frame = g.orig_frame
    end
    local gx = g.x + 4
    local gy = g.y + 4
    local px = player.x + 4
    local py = player.y + 4
    if abs(gx - px) < 6 and abs(gy - py) < 6 then
      score += g.value
      g.mode = 3
      g.frame = 27
      g.hide_timer = 0
      g.home = { x = 60, y = -20 } -- Banishment target
      sfx(0)
    end
  else
    local gx = g.x + 4
    local gy = g.y + 4
    local px = player.x + 4
    local py = player.y + 4
    if abs(gx - px) < 6 and abs(gy - py) < 6 and g.mode ~= 3 then
      sfx(2, 3)
      dead_timer = 30
      return
    end
  end

  if at_center(g) then
    local options = get_valid_dirs(g)
    if #options > 0 then
      if g.mode == 0 then
        ghost_search(g)
      elseif g.mode == 1 then
        update_ghost_target(g)
        ghost_chase(g, g.target.x, g.target.y)
      elseif g.mode == 2 then
        ghost_search(g)
      elseif g.mode == 3 then
        if abs(g.x - g.home.x) < 4 and abs(g.y - g.home.y) < 4 then
          del(ghosts, g)
          return
        else
          ghost_retreat(g)
        end
      end
      local d = dirs[g.dir]
      g.dx = d.x
      g.dy = d.y
    else
      g.dx = -g.dx
      g.dy = -g.dy
    end
  end

  g.x += g.dx * g.speed
  g.y += g.dy * g.speed
  if g.mode != 3 then clamp_position(g) end
end

function eat_dot()
  local px = flr((player.x + 4) / 8)
  local py = flr((player.y + 4) / 8)

  for d in all(dots) do
    local dx = flr(d.x / 8)
    local dy = flr(d.y / 8)
    if dx == px and dy == py then
      score += 10
      sfx(0)
      del(dots, d)
      break
    end
  end

  for v in all(pellets) do
    local vx = flr(v.x / 8)
    local vy = flr(v.y / 8)
    if vx == px and vy == py then
      score += 50
      del(pellets, v)
      for g in all(ghosts) do
        if g.mode ~= 3 then
          g.mode = 2
          g.frame = 11
          g.hide_timer = 5 * 30
        end
      end
      break
    end
  end
end

function draw_dots()
  for i = 1, #dots do
    local d = dots[i]
    spr(d.frame, d.x, d.y)
  end
  for i = 1, #pellets do
    local p = pellets[i]
    spr(p.frame, p.x, p.y)
  end
end

function move_player_grid()
  local function get_vec(idx)
    if idx < 1 or idx > 4 then return { x = 0, y = 0 } end
    return dirs[idx]
  end

  local d_curr = get_vec(player.dir)
  local d_next = get_vec(player.next_dir)

  -- 1. Handle Immediate Reversal
  if player.dir ~= -1 and player.next_dir ~= -1 then
    if d_curr.x == -d_next.x and d_curr.y == -d_next.y then
      player.dir = player.next_dir
      player.next_dir = -1
      player.h_speed = d_next.x * player.speed
      player.v_speed = d_next.y * player.speed
      d_curr = d_next

      if d_next.x < 0 then
        player.anim.flip_x = true
      elseif d_next.x > 0 then
        player.anim.flip_x = false
      end
      if d_next.y > 0 then player.anim.flip_y = true end
      if d_next.y < 0 then player.anim.flip_y = false end

      if player.h_speed ~= 0 then
        player.anim.first = 1 player.anim.last = 3 player.anim.frame = 1
      else
        player.anim.first = 17 player.anim.last = 19 player.anim.frame = 17
      end
    end
  end

  -- 2. Handle Grid Aligned Turns
  if player.x % 8 == 0 and player.y % 8 == 0 then
    local cx = flr(player.x / 8)
    local cy = flr(player.y / 8)

    if player.next_dir ~= -1 then
      local turn_tx = cx + d_next.x
      local turn_ty = cy + d_next.y

      if not fget(mget(turn_tx, turn_ty), 0) then
        player.dir = player.next_dir
        player.next_dir = -1
        player.h_speed = d_next.x * player.speed
        player.v_speed = d_next.y * player.speed

        if d_next.x < 0 then
          player.anim.flip_x = true
        elseif d_next.x > 0 then
          player.anim.flip_x = false
        end
        if d_next.y > 0 then player.anim.flip_y = true end
        if d_next.y < 0 then player.anim.flip_y = false end

        if player.h_speed ~= 0 then
          player.anim.first = 1 player.anim.last = 3 player.anim.frame = 1
        else
          player.anim.first = 17 player.anim.last = 19 player.anim.frame = 17
        end
      end
    end

    -- Check wall in current direction
    if player.h_speed ~= 0 or player.v_speed ~= 0 then
      local dx = 0
      local dy = 0
      if player.h_speed > 0 then
        dx = 1
      elseif player.h_speed < 0 then
        dx = -1
      end
      if player.v_speed > 0 then
        dy = 1
      elseif player.v_speed < 0 then
        dy = -1
      end

      local next_tx = cx + dx
      local next_ty = cy + dy
      if fget(mget(next_tx, next_ty), 0) then
        player.h_speed = 0
        player.v_speed = 0
      end
    end
  end

  player.x += player.h_speed
  player.y += player.v_speed
end

function _update()
  if game_won then return end

  if dead_timer > 0 then
    dead_timer -= 1
    if dead_timer == 0 then
      start_level(curr_level)
    end
    return
  end

  if #dots == 0 and #pellets == 0 then
    if not gate_open_sfx_played then
      sfx(1)
      gate_open_sfx_played = true
    end
    mset(door_pos.x, door_pos.y, 0)
    mset(door_pos.x, door_pos.y - 1, 0)
    mset(door_pos.x, door_pos.y + 1, 0)
  end

  if player.x > door_pos.x * 8 then
    start_level(curr_level + 1)
    return
  end

  mode_timer -= 1
  if mode_timer <= 0 then
    mode_index += 1
    if mode_index > #mode_schedule then
      mode_index = #mode_schedule
    end
    current_mode = mode_schedule[mode_index].mode
    mode_timer = mode_schedule[mode_index].time * 30
    for g in all(ghosts) do
      if g.mode ~= 2 and g.mode ~= 3 then
        g.mode = current_mode
      end
    end
  end

  -- Grid Input Logic
  if btn(0) then
    player.next_dir = 2 -- Left
  elseif btn(1) then
    player.next_dir = 1 -- Right
  elseif btn(2) then
    player.next_dir = 4 -- Up
  elseif btn(3) then
    player.next_dir = 3 -- Down
  end

  move_player_grid()
  eat_dot()

  clamp_position(player)

  for g in all(ghosts) do
    move_ghost(g)
  end

  if score > hi_score then
    hi_score = score
    dset(0, hi_score)
  end

  game_time += 1
end

function _draw()
  cls()
  if game_won then
    print("YOU WIN!", 50, 60, 7)
    print("SCORE: " .. score, 48, 70, 7)
    return
  end

  map()
  draw_dots()

  if player.h_speed == 0 and player.v_speed == 0 then
    player.anim.frame = player.anim.first + 1
  end

  animate(player, player.x, player.y, player.anim.flip_x, player.anim.flip_y, 2)
  draw_ghosts()

  print("SCORE " .. score, 0, 0, 7)
  print("LEVEL " .. curr_level, 90, 0, 7)
end
