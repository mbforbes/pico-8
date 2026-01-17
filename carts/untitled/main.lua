function _init()
    music(4, 1000)
    -- enable mouse
    poke(0x5f2d, 0x3)

    -- settings
    defaultcol = 9

    -- state
    col = defaultcol
end

-- point p {x,y}
-- bounds b {x0, y0, x1, y1}
function intersects(p, b)
    return (p.x >= bounds[1]
                and p.y >= bounds[2]
                and p.x <= bounds[3]
                and p.y <= bounds[4])
end

function _update()
    mouse = { x = stat(32), y = stat(33) }
    bounds = { 14, 20, 114, 40 }

    -- left pointer = x = btn 5
    if btnp(5) then
        col = 8
        if intersects(mouse, bounds) then
            col = 14
            -- todo: change track
            music(0)
        end
    else
        col = defaultcol
    end
end

function _draw()
    cls(1)

    -- draw hit area
    bcol = 12
    if intersects(mouse, bounds) then
        bcol = 3
    end
    rectfill(14, 20, 114, 40, bcol)

    -- draw mouse
    -- x, y, r, color
    circfill(stat(32), stat(33), 8, col)
end
