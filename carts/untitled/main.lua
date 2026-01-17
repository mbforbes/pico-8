function _init()
    music(4, 1000)

    chunks = {}
    for offset in all({ 0, -128 }) do
        chunk = {
            offset = offset,
            rows = {}
        }
        -- should be 7, but we'll do 8 to avoid tearing probs b/c of my bad logic
        for i = 0, 8 do
            add(chunk.rows, { celX = 0, celY = i % 2, celW = 4, celH = 2, localY = i * 16 })
        end
        add(chunks, chunk)
    end

    DEFAULT_SPEED = 1

    speed = DEFAULT_SPEED
    car = {
        p = { x = 64, y = 64 },
        xlim = { low = 10, high = 110 },
        ylim = { low = 10, high = 108 }
    }
    roadX = { low = 47, high = 77 }
    cam = { x = 0, y = 0 }
    wobble = { dir = 1, delta = 1, lim = 2 }
end

-- point p {x,y}
-- bounds b {x0, y0, x1, y1}
function intersects(p, b)
    return (p.x >= bounds[1]
                and p.y >= bounds[2]
                and p.x <= bounds[3]
                and p.y <= bounds[4])
end

function _update60()
    for chunk in all(chunks) do
        chunk.offset += speed
        if (chunk.offset >= 128) chunk.offset = -128
    end

    speed_mul = 1
    if car.p.x < roadX.low or car.p.x > roadX.high then
        speed_mul = 0.5
        speed = DEFAULT_SPEED * speed_mul
        if abs(cam.x) > wobble.lim then
            wobble.dir *= -1
        end
        cam.x += wobble.dir * wobble.delta
    else
        speed = DEFAULT_SPEED
        cam.x = 0
    end

    -- move
    if btn(0) then
        car.p.x -= 1 * speed_mul
    elseif btn(1) then
        car.p.x += 1 * speed_mul
    end
    if btn(2) then
        car.p.y -= 1 * speed_mul
    elseif btn(3) then
        car.p.y += 1 * speed_mul
    end
    -- clamp
    car.p.x = min(max(car.xlim.low, car.p.x), car.xlim.high)
    car.p.y = min(max(car.ylim.low, car.p.y), car.ylim.high)
end

function _draw()
    cls(3)

    camera(cam.x, cam.y)

    print(car.p.x)

    for chunk in all(chunks) do
        for rr in all(chunk.rows) do
            -- print(rr.localY)
            map(rr.celX, rr.celY, 50, chunk.offset + rr.localY, rr.celW, rr.celH)
        end
    end
    -- map(0, 3, 50, y, 4, 2)

    -- draw car (2 parts)
    spr(191, car.p.x, car.p.y)
    spr(207, car.p.x, car.p.y + 8)
end
