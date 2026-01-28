--initialize the game
function _init()
  --set transparencies
  palt(15, true)

  --load high score
  cartdata("picoman")
  hi_score = dget(0)
end

--game stats
lives = 3
score = 0
game_time = 0

--player object
player = {
  x = 7 * 8,
  y = 10 * 8,
  speed = 2,
  v_speed = 0,
  h_speed = 0,
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

function new_pellet(_id, _x, _y)
  return {
    id = _id,
    x = _x,
    y = _y,
    flag = 5,
    frame = 5
  }
end

function new_ghost(_id, _x, _y, _frame)
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
    home = { x = 56, y = 64 },
    released = false,
    release_time = 60 * _id, -- stagger exits
    target = { x = 0, y = 0 },
    hide_timer = 0
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

--utility functions
function animate(_obj, _x, _y, _flip_x, _flip_y, _mode)
  --draw the sprite
  spr(_obj.anim.frame, _x, _y, 1, 1, _flip_x, _flip_y)

  --update the sprite frame
  _obj.anim.frame += _obj.anim.speed

  --loop type
  --repeat animation
  if _mode == 0 then
    if _obj.anim.frame >= _obj.anim.last + 1 then
      _obj.anim.frame = _obj.anim.first
    end

    --play once
  elseif _mode == 1 then
    if _obj.anim.frame >= _obj.anim.last + 1 then
      _obj.anim.frame = _obj.anim.last
      _obj.anim.speed = 0
    end

    --ping pong animation
  elseif _mode == 2 then
    if _obj.anim.frame >= _obj.anim.last + 1 then
      _obj.anim.frame = _obj.anim.last
      _obj.anim.speed = _obj.anim.speed * -1
    elseif _obj.anim.frame <= _obj.anim.first then
      _obj.anim.frame = _obj.anim.first + 1
      _obj.anim.speed = _obj.anim.speed * -1
    end
  end

  --debug
  --print("frame: " .. tostring(_obj.anim.frame))
  --print("speed: " .. tostring(_obj.anim.speed))
end

function clamp_position(obj)
  -- horizontal bounds
  if obj.x < -8 then obj.x = -8 end
  if obj.x > 120 then obj.x = 120 end

  -- vertical bounds
  if obj.y < 0 then obj.y = 0 end
  if obj.y > 120 then obj.y = 120 end
end

function can_move_vert(obj)
  if obj.x < 0 or obj.x > 112 then
    return false -- outside main maze
  end
  return true
end

--ghost functions
function spawn_ghosts()
  for i = 0, 3 do
    add(ghosts, new_ghost(i, 56, 64, (16 * i) + 6))
  end
end

function update_ghost_target(g)
  if g.id == 0 then
    -- blinky: directly chase player
    g.target.x = player.x
    g.target.y = player.y
  elseif g.id == 1 then
    -- pinky: ambush (2 tiles ahead of player)
    g.target.x = player.x + player.h_speed * 16
    g.target.y = player.y + player.v_speed * 16
  elseif g.id == 2 then
    -- inky: offset upward
    g.target.x = player.x
    g.target.y = player.y - 16
  elseif g.id == 3 then
    -- clyde: fixed corner
    g.target.x = 56
    g.target.y = 80
  end
end

function draw_ghosts()
  for g in all(ghosts) do
    spr(g.frame, g.x, g.y)
  end
end

function can_move(g, dir)
  local nx = g.x + dir.x * 8
  local ny = g.y + dir.y * 8

  local tx = flr((nx + 4) / 8)
  local ty = flr((ny + 4) / 8)

  local spr = mget(tx, ty)

  -- walls always block
  if fget(spr, 0) then return false end

  -- gate blocks unless retreating
  if fget(spr, 1) and g.mode ~= 3 then
    return false
  end

  return not fget(mget(tx, ty), 0)
end

function at_center(g)
  return g.x % 8 == 0 and g.y % 8 == 0
end

function in_pen(g)
  return g.y >= 64 and g.y <= 72 and g.x >= 48 and g.x <= 72
end

function get_valid_dirs(g)
  local options = {}

  for i, d in ipairs(dirs) do
    -- rule 1: prevent reversing
    if d.x ~= -g.dx or d.y ~= -g.dy then
      -- rule 2: block sideways movement inside the pen
      if not (in_pen(g) and d.x ~= 0) then
        -- rule 3: must not hit a wall
        if can_move(g, d) then
          add(options, i)
        end
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

function warp_ghost(g)
  -- moving left through tunnel
  if g.dx < 0 and g.x <= -8 then
    g.x = 120
    -- moving right through tunnel
  elseif g.dx > 0 and g.x >= 120 then
    g.x = -8
  end
end

function move_ghost(g)
  -- still waiting in pen?
  if not g.released then
    if game_time >= g.release_time then
      g.released = true
      -- pick first valid direction upon release
      local options = get_valid_dirs(g)
      if #options > 0 then
        g.dir = options[1]
      else
        g.dir = 4 -- fallback up
      end
      local d = dirs[g.dir]
      g.dx = d.x
      g.dy = d.y
    else
      return
    end
  end

  -- hide timer logic: decrement every frame
  if g.mode == 2 then
    g.hide_timer -= 1
    if g.hide_timer <= 0 then
      g.mode = current_mode -- revert to global mode
      g.frame = g.orig_frame
    end

    -- check collision with player if hiding
    local gx = g.x + 4
    local gy = g.y + 4
    local px = player.x + 4
    local py = player.y + 4
    if abs(gx - px) < 4 and abs(gy - py) < 4 then
      score += g.value
      g.mode = 3 -- retreat
      g.frame = 27
      g.hide_timer = 0
    end
  end

  -- only decide new direction at tile centers
  if at_center(g) then
    local options = get_valid_dirs(g)
    if #options > 0 then
      if g.mode == 0 then
        ghost_search(g)
      elseif g.mode == 1 then
        update_ghost_target(g)
        ghost_chase(g, g.target.x, g.target.y)
      elseif g.mode == 2 then
        ghost_search(g) -- random movement while hiding
      elseif g.mode == 3 then
        -- retreat mode
        if in_pen(g) then
          -- if inside pen, always move up to exit
          g.dir = 4
        else
          ghost_retreat(g)
        end
      end
      -- update dx/dy for movement
      local d = dirs[g.dir]
      g.dx = d.x
      g.dy = d.y
    end
  end

  -- move the ghost
  g.x += g.dx * g.speed
  if can_move_vert(g) then
    g.y += g.dy * g.speed
  end

  -- retreat mode: check if ghost reached pen gate
  if g.mode == 3 then
    if in_pen(g) and g.y <= g.home.y then
      g.mode = 0
      g.frame = g.orig_frame
      g.released = true
    end
  end

  clamp_position(g)
  warp_ghost(g)
end

--dot functions
function spawn_dots()
  for i = 0, 15 do
    for j = 0, 15 do
      --get sprite for each tile on 16x16 map
      local _spr = mget(i, j)
      --check for dot spawner flag
      if fget(_spr, 6) then
        --add to dots table
        add(dots, new_dot(#dots, i * 8, j * 8))
      end
      if fget(_spr, 7) then
        --add to pellets table
        add(pellets, new_pellet(#pellets, i * 8, j * 8))
      end
    end
  end
end

function eat_dot()
  local px = flr((player.x + 4) / 8)
  local py = flr((player.y + 4) / 8)

  for d in all(dots) do
    local dx = flr(d.x / 8)
    local dy = flr(d.y / 8)

    if dx == px and dy == py then
      score += 100
      sfx(00)
      del(dots, d)
      break
    end
  end

  for v in all(pellets) do
    local vx = flr(v.x / 8)
    local vy = flr(v.y / 8)

    if vx == px and vy == py then
      score += 250
      del(pellets, v)

      --trigger ghost hiding
      for g in all(ghosts) do
        --don't override retreating ghosts
        if g.mode ~= 3 then
          g.mode = 2
          g.frame = 11 --hiding sprite
          g.hide_timer = 5 * 30 -- 5 seconds of hiding
        end
      end
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

--player functions
function move_player_h()
  local last_x = player.x

  --update position
  player.x += player.h_speed
  clamp_position(player)

  --if player collides with wall, move back to last x,y, reset speed

  if check_collision(player, 0) then
    player.x = last_x
    player.h_speed = 0
  end

  --update sprite according to direction
  if player.h_speed > 0 then
    if player.anim.frame > 4 then
      player.anim.frame = 1
      player.anim.first = 1
      player.anim.last = 3
    end
    player.anim.flip_x = false
    player.anim.flip_y = false
  elseif player.h_speed < 0 then
    if player.anim.frame > 4 then
      player.anim.frame = 1
      player.anim.first = 1
      player.anim.last = 3
    end
    player.anim.flip_x = true
    player.anim.flip_y = false
  end
end

function move_player_v()
  local last_y = player.y

  --update position
  player.y += player.v_speed
  clamp_position(player)

  --if player collides with wall, move back to last x,y, reset speed
  if check_collision(player, 0) then
    player.y = last_y
    player.v_speed = 0
  end

  --if player collides with ghost gate, move back to last x,y, reset speed
  if check_collision(player, 1) then
    player.y = last_y
    player.v_speed = 0
  end

  --update sprite according to direction
  if player.v_speed > 0 then
    if player.anim.frame < 4 then
      player.anim.frame = 17
      player.anim.first = 17
      player.anim.last = 19
    end
    player.anim.flip_x = false
    player.anim.flip_y = true
  elseif player.v_speed < 0 then
    if player.anim.frame < 4 then
      player.anim.frame = 17
      player.anim.first = 17
      player.anim.last = 19
    end
    player.anim.flip_x = false
    player.anim.flip_y = false
  end
end

function warp_player()
  if player.x <= -8 then
    player.x = 120
  elseif player.x >= 120 then
    player.x = -8
  end
end

function check_collision(_obj, _flag)
  --get object edges, divide by 8 for map coordinates (not pixels)
  local x1 = flr(_obj.x / 8)
  local y1 = flr(_obj.y / 8)
  local x2 = flr((_obj.x + 7) / 8)
  local y2 = flr((_obj.y + 7) / 8)

  --check for collisions with flag
  local a = fget(mget(x1, y1), _flag)
  local b = fget(mget(x1, y2), _flag)
  local c = fget(mget(x2, y1), _flag)
  local d = fget(mget(x2, y2), _flag)

  --if any edge collides, return true
  if a or b or c or d then
    return true
  else
    return false
  end
end

function draw_lives()
  for i = 0, lives - 1 do
    spr(2, i * 8, 120)
  end
end

--game loop
function _update()
  --spawn dots if map empty
  if #dots == 0 and #pellets == 0 then
    spawn_dots()
  end

  --spawn ghosts if map empty
  if #ghosts == 0 then
    spawn_ghosts()
  end

  --set ghost mode
  mode_timer -= 1

  if mode_timer <= 0 then
    mode_index += 1
    if mode_index > #mode_schedule then
      mode_index = #mode_schedule
    end

    current_mode = mode_schedule[mode_index].mode
    mode_timer = mode_schedule[mode_index].time * 30

    -- apply to all ghosts that are not retreating or hiding
    for g in all(ghosts) do
      if g.mode ~= 2 and g.mode ~= 3 then
        g.mode = current_mode
      end
    end
  end

  --get player input
  if btn(➡️) then
    player.h_speed = player.speed
  elseif btn(⬅️) then
    player.h_speed = player.speed * -1
  elseif btn(⬆️) and can_move_vert(player) then
    player.v_speed = player.speed * -1
  elseif btn(⬇️) and can_move_vert(player) then
    player.v_speed = player.speed
  end

  --move objects
  --check for dot collision after each move update to ensure no dots skipped
  move_player_h()
  eat_dot()

  move_player_v()
  eat_dot()

  warp_player()

  --move ghosts
  for g in all(ghosts) do
    move_ghost(g)
  end

  --update score
  if score > hi_score then
    hi_score = score
    dset(0, hi_score)
  end

  --update game time
  game_time += 1
end

--draw to screen
function _draw()
  --clear screen
  cls()

  --draw map
  map()

  -- draw dots
  draw_dots()

  --pause player animation when stopped
  if player.h_speed == 0 and player.v_speed == 0 then
    player.anim.frame = player.anim.first + 1
  end

  --animate player
  animate(player, player.x, player.y, player.anim.flip_x, player.anim.flip_y, 2)

  --draw ghosts
  draw_ghosts()

  --draw tunnel lid
  palt(0, false)
  spr(128, 120, 56)
  spr(128, 120, 64)
  spr(128, 120, 72)
  palt(0, true)

  --draw scores
  print("score", 0, 0, 7)
  print(tostring(score), 0, 8, 7)
  print("high score", 50, 0, 7)
  print(tostring(hi_score), 50, 8, 7)

  --draw lives
  draw_lives()

  --debug
  --print(tostring(#dots + #pellets), 0, 0)
  --print("player x: " .. tostring(player.x), 0, 8)
  --print("player y: " .. tostring(player.y), 64, 8)
  -- debug: show ghost modes with remaining time
  local mode_names = { "SEARCH", "CHASE", "HIDE", "RETREAT" }
  local ghost_colors = { 8, 12, 14, 9 }
  -- red, blue, pink, orange
  for i, g in ipairs(ghosts) do
    local mode_text = mode_names[g.mode + 1] or tostring(g.mode)
    local color = ghost_colors[i] or 7 -- fallback white

    -- calculate remaining time
    local time_left = 0
    if g.mode == 2 then
      -- hiding mode uses per-ghost timer
      time_left = g.hide_timer
    elseif g.mode == 0 or g.mode == 1 then
      -- search/chase modes use global mode timer
      time_left = mode_timer
    end
    -- convert to seconds assuming 30 fps
    local seconds = flr(time_left / 30)

    print("G" .. g.id .. ": " .. mode_text .. " (" .. seconds .. ")", 0, 16 + i * 6, color)
  end
end