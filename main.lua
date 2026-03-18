-- main.lua
display.setStatusBar( display.HiddenStatusBar )

local physics = require( "physics" )
physics.start()
physics.setGravity( 0, 0 )

local socket = require("socket")
local json = require("json")

local udp = socket.udp()
udp:settimeout(0)
local SERVER_IP = "127.0.0.1"
udp:setpeername(SERVER_IP, 9999) 

local cw = display.contentWidth
local ch = display.contentHeight

-- Groups
local bgGroup = display.newGroup()
local menuGroup = display.newGroup()
local gameGroup = display.newGroup()
local gridGroup = display.newGroup()
local glowGroup = display.newGroup()
local wallsGroup = display.newGroup()
local bulletsGroup = display.newGroup()
local tanksGroup = display.newGroup()
local uiGroup = display.newGroup()

gameGroup:insert(gridGroup)
gameGroup:insert(glowGroup)
gameGroup:insert(wallsGroup)
gameGroup:insert(bulletsGroup)
gameGroup:insert(tanksGroup)
gameGroup:insert(uiGroup)
gameGroup.isVisible = false

-- ====== MODERN BACKGROUND ======
local bgPaint = {
    type = "gradient",
    color1 = { 0.05, 0.05, 0.1 },
    color2 = { 0.1, 0.1, 0.15 },
    direction = "down"
}
local background = display.newRect( bgGroup, cw/2, ch/2, cw, ch )
background:setFillColor( bgPaint )

-- Cyber grid lines
for i=0, cw, 40 do
    local l = display.newLine(gridGroup, i, 0, i, ch)
    l.strokeWidth = 1; l:setStrokeColor(0.2, 0.4, 0.8, 0.15)
end
for i=0, ch, 40 do
    local l = display.newLine(gridGroup, 0, i, cw, i)
    l.strokeWidth = 1; l:setStrokeColor(0.2, 0.4, 0.8, 0.15)
end

-- Game state
local localPlayerId = 1
local activePlayers = 2 -- Default to 2 players
local tanks = {}
local isGameOver = false

-- ====== SOUND EFFECTS ======
-- แนะนำให้ใช้ไฟล์นามสกุล .wav เสียงจะออกทันทีแบบ 0 ดีเลย์ครับ (MP3 มักจะหน่วงเพราะต้องถอดรหัส)
local sndShoot = audio.loadSound( "shoot.wav" )
local sndExplode = audio.loadSound( "explode.wav" )
local sndWin = audio.loadSound( "win.wav" )

-- ====== MODERN MENU SYSTEM ======
local titleGlow = display.newText( menuGroup, "NEON TANKS", cw/2, ch*0.12, native.systemFontBold, 44 )
titleGlow:setFillColor( 0, 0.8, 1, 0.4 )
local title = display.newText( menuGroup, "NEON TANKS", cw/2, ch*0.12 - 2, native.systemFontBold, 44 )
title:setFillColor( 1, 1, 1 )

local panel = display.newRoundedRect( menuGroup, cw/2, ch*0.58, cw*0.55, ch*0.75, 16 )
panel:setFillColor( 0.1, 0.15, 0.25, 0.8 )
panel.strokeWidth = 2
panel:setStrokeColor( 0, 0.5, 1, 0.5 )

local nText = display.newText( menuGroup, "--- LAN MULTIPLAYER ---", cw/2, ch*0.25, native.systemFontBold, 14 )
nText:setFillColor( 0, 0.8, 1 )

local countText = display.newText( menuGroup, "1. SELECT PLAYERS", cw/2, ch*0.33, native.systemFontBold, 16 )
local joinText = display.newText( menuGroup, "2. CHOOSE YOUR TANK", cw/2, ch*0.48, native.systemFontBold, 16 )

local countBtns = {}
local joinBtns = {}

local function updateMenuVisibility()
    for i=1, 4 do
        if joinBtns[i] then joinBtns[i].isVisible = (i <= activePlayers) end
    end
    for i=2, 4 do
        if countBtns[i] then
            if i == activePlayers then
                countBtns[i].bg:setFillColor( 1, 0.6, 0 )
                countBtns[i].bg:setStrokeColor( 1, 0.8, 0 )
            else
                countBtns[i].bg:setFillColor( 0.2, 0.2, 0.3 )
                countBtns[i].bg:setStrokeColor( 0.4, 0.4, 0.5 )
            end
        end
    end
end

local function applyBtnEffect(btn)
    transition.to(btn, {time=100, xScale=0.9, yScale=0.9, onComplete=function()
        transition.to(btn, {time=100, xScale=1, yScale=1})
    end})
end

local function createCountBtn(x, y, count)
    local btn = display.newGroup()
    btn.x, btn.y = x, y
    
    btn.bg = display.newRoundedRect( btn, 0, 0, 60, 45, 10 )
    btn.bg.strokeWidth = 2
    local txt = display.newText( btn, count.."P", 0, 0, native.systemFontBold, 20 )
    
    btn:addEventListener("touch", function(e)
        if e.phase == "began" then
            display.getCurrentStage():setFocus( btn )
            applyBtnEffect(btn)
        elseif e.phase == "ended" or e.phase == "cancelled" then
            display.getCurrentStage():setFocus( nil )
            if e.phase == "ended" then
                activePlayers = count
                updateMenuVisibility()
            end
        end
        return true
    end)
    menuGroup:insert(btn)
    countBtns[count] = btn
end

createCountBtn(cw/2 - 80, ch*0.40, 2)
createCountBtn(cw/2, ch*0.40, 3)
createCountBtn(cw/2 + 80, ch*0.40, 4)

local function createJoinBtn(y, text, pId, colorRGB)
    local btn = display.newGroup()
    btn.x, btn.y = cw/2, y
    
    local grad = { type="gradient", color1={colorRGB[1]*0.8, colorRGB[2]*0.8, colorRGB[3]*0.8}, color2={colorRGB[1]*0.4, colorRGB[2]*0.4, colorRGB[3]*0.4}, direction="down" }
    local bg = display.newRoundedRect( btn, 0, 0, 220, 42, 12 )
    bg:setFillColor( grad )
    bg.strokeWidth = 2
    bg:setStrokeColor( unpack(colorRGB) )
    
    local txt = display.newText( btn, text, 0, 0, native.systemFontBold, 16 )
    
    btn:addEventListener("touch", function(e)
        if e.phase == "began" then
            display.getCurrentStage():setFocus( btn )
            applyBtnEffect(btn)
            bg:setFillColor( unpack(colorRGB) )
        elseif e.phase == "ended" or e.phase == "cancelled" then
            bg:setFillColor( grad )
            display.getCurrentStage():setFocus( nil )
            if e.phase == "ended" then
                localPlayerId = pId
                pcall(function() udp:send(json.encode({type="join", p=pId})) end)
                startGame()
            end
        end
        return true
    end)
    menuGroup:insert(btn)
    joinBtns[pId] = btn
end

createJoinBtn(ch*0.55, "JOIN P1 (RED)", 1, {1, 0.2, 0.3})
createJoinBtn(ch*0.65, "JOIN P2 (BLUE)", 2, {0, 0.6, 1})
createJoinBtn(ch*0.75, "JOIN P3 (GREEN)", 3, {0.1, 0.9, 0.2})
createJoinBtn(ch*0.85, "JOIN P4 (YELLOW)", 4, {1, 0.8, 0})

updateMenuVisibility()

-- ====== GAME SYSTEM ======

local function createWall(x, y, w, h)
    -- Glow effect underneath
    local wg = display.newRect( glowGroup, x, y, w+8, h+8 )
    wg:setFillColor( 0, 0.6, 1, 0.2 )
    
    local wall = display.newRect( wallsGroup, x, y, w, h )
    wall:setFillColor( 0.1, 0.15, 0.25 ) -- Dark fill
    wall.strokeWidth = 2
    wall:setStrokeColor( 0, 0.6, 1 ) -- Neon stroke
    
    physics.addBody( wall, "static", { bounce = 1.0, friction = 0 } )
    wall.isWall = true
    return wall
end

local function buildMap()
    for i=wallsGroup.numChildren, 1, -1 do display.remove(wallsGroup[i]) end
    for i=glowGroup.numChildren, 1, -1 do display.remove(glowGroup[i]) end
    
    local wThick = 10
    -- Frame borders
    createWall( cw/2, wThick/2, cw, wThick ) 
    createWall( cw/2, ch-wThick/2, cw, wThick ) 
    createWall( wThick/2, ch/2, wThick, ch ) 
    createWall( cw-wThick/2, ch/2, wThick, ch ) 
    
    -- 21-piece dense tactical maze
    local mazeData = {
        -- Central cover
        {cw/2, ch/2, cw*0.1, ch*0.15}, 
        
        -- Inner ring L-shapes
        {cw*0.35, ch*0.35, cw*0.15, wThick},
        {cw*0.65, ch*0.35, cw*0.15, wThick},
        {cw*0.35, ch*0.65, cw*0.15, wThick},
        {cw*0.65, ch*0.65, cw*0.15, wThick},
        {cw*0.35, ch*0.35, wThick, ch*0.2},
        {cw*0.65, ch*0.35, wThick, ch*0.2},
        {cw*0.35, ch*0.65, wThick, ch*0.2},
        {cw*0.65, ch*0.65, wThick, ch*0.2},
        
        -- Outer vertical columns
        {cw*0.15, ch*0.25, wThick, ch*0.3},
        {cw*0.15, ch*0.75, wThick, ch*0.3},
        {cw*0.85, ch*0.25, wThick, ch*0.3},
        {cw*0.85, ch*0.75, wThick, ch*0.3},
        
        -- Top & Bottom horizontal blockers
        {cw*0.3, ch*0.15, cw*0.2, wThick},
        {cw*0.7, ch*0.15, cw*0.2, wThick},
        {cw*0.3, ch*0.85, cw*0.2, wThick},
        {cw*0.7, ch*0.85, cw*0.2, wThick},
        
        -- Mid-edge horizontal & vertical blockers
        {cw*0.2, ch/2, cw*0.15, wThick},
        {cw*0.8, ch/2, cw*0.15, wThick},
        {cw/2, ch*0.2, wThick, ch*0.15},
        {cw/2, ch*0.8, wThick, ch*0.15},
    }
    for i=1, #mazeData do
        createWall(mazeData[i][1], mazeData[i][2], mazeData[i][3], mazeData[i][4])
    end
end

local scores = {0, 0, 0, 0}

local function updateScoreDisplay()
    -- ระบบนับคะแนนจะรันเก็บแต้มไว้ในตัวแปรแบบเงียบๆ 
    -- แต่เราถอดการแสดงผลบนจอออกเพื่อความเคลียร์ของสนามครับ!
end

local tankConfigs = {
    { x=cw/2, y=ch-40, rot=0,   color={1, 0.2, 0.3}, keys={up="w", down="s", left="a", right="d", shoot="space"} },
    { x=cw/2, y=40,    rot=180, color={0, 0.6, 1}, keys={up="w", down="s", left="a", right="d", shoot="space"} },
    { x=40, y=ch/2,    rot=90,  color={0.1, 0.9, 0.2}, keys={up="w", down="s", left="a", right="d", shoot="space"} },
    { x=cw-40, y=ch/2, rot=-90, color={1, 0.8, 0}, keys={up="w", down="s", left="a", right="d", shoot="space"} } 
}

local function spawnTanks()
    for i=1, #tanks do if tanks[i] then display.remove(tanks[i]) end end
    tanks = {}
    for i=bulletsGroup.numChildren, 1, -1 do display.remove(bulletsGroup[i]) end
    
    for i=1, activePlayers do
        local cfg = tankConfigs[i]
        local tGroup = display.newGroup()
        tGroup.x, tGroup.y = cfg.x, cfg.y
        tGroup.rotation = cfg.rot
        tGroup.playerIdx = i
        
        -- Aura Glow
        local aura = display.newCircle( tGroup, 0, 0, 22 )
        aura:setFillColor( unpack(cfg.color) )
        aura.alpha = 0.25
        
        local body = display.newRoundedRect( tGroup, 0, 0, 18, 24, 4 )
        body:setFillColor( unpack(cfg.color) )
        local barrel = display.newRect( tGroup, 0, -16, 5, 18 )
        barrel:setFillColor( 0.8, 0.9, 1 )
        local turret = display.newCircle( tGroup, 0, 0, 7 )
        turret:setFillColor( cfg.color[1]*0.4, cfg.color[2]*0.4, cfg.color[3]*0.4 )
        turret.strokeWidth = 1
        turret:setStrokeColor(1,1,1, 0.5)
        
        if i == localPlayerId then
            physics.addBody( tGroup, "dynamic", { radius=11, bounce=0.2 } )
        else
            physics.addBody( tGroup, "kinematic", { radius=11, bounce=0 } )
        end
        
        tGroup.angularDamping = 6
        tGroup.linearDamping = 4
        tGroup.isTank = true
        tGroup.bulletsFired = 0
        tGroup.color = cfg.color
        tGroup.cfg = cfg
        
        tanksGroup:insert(tGroup)
        table.insert(tanks, tGroup)
    end
end

function startGame()
    menuGroup.isVisible = false
    gameGroup.isVisible = true
    isGameOver = false
    scores = {0, 0, 0, 0}
    buildMap()
    updateScoreDisplay()
    spawnTanks()
end

local function checkRoundOver()
    if isGameOver then return end
    
    local alive = 0
    local winnerIdx = 0
    for i=1, #tanks do
        if tanks[i] and not tanks[i].isDead then
            alive = alive + 1
            winnerIdx = tanks[i].playerIdx
        end
    end
    
    if alive <= 1 then
        isGameOver = true
        local wText = ""
        local winColor = {1, 1, 1}
        
        if alive == 1 then
            scores[winnerIdx] = scores[winnerIdx] + 1
            local names = {"P1 (RED)", "P2 (BLUE)", "P3 (GREEN)", "P4 (YELLOW)"}
            wText = names[winnerIdx] .. " WINS!"
            winColor = tankConfigs[winnerIdx].color
        else
            wText = "DRAW MATCH!"
        end
        updateScoreDisplay()
        
        -- Premium Victory Element
        local vPanel = display.newRoundedRect( uiGroup, cw/2, ch/2 - 60, cw*0.8, 80, 12 )
        vPanel:setFillColor( 0, 0, 0, 0.8 )
        vPanel.strokeWidth = 2
        vPanel:setStrokeColor( unpack(winColor) )
        
        local winDisplay = display.newText( uiGroup, wText, cw/2, ch/2 - 60, native.systemFontBold, 36 )
        winDisplay:setFillColor( unpack(winColor) )
        
        if sndWin then audio.play( sndWin ) end
        
        timer.performWithDelay( 3500, function()
            display.remove(winDisplay)
            display.remove(vPanel)
            
            gameGroup.isVisible = false
            menuGroup.isVisible = true
            isGameOver = false
            for i=1, #tanks do
                if tanks[i] then display.remove(tanks[i]) end
            end
            tanks = {}
            for i=bulletsGroup.numChildren, 1, -1 do display.remove(bulletsGroup[i]) end
        end )
    end
end

local function shoot( tank, isRemote, rX, rY, rRot )
    if isGameOver or not tank or tank.isDead then return end
    if tank.bulletsFired >= 5 then return end
    
    tank.bulletsFired = tank.bulletsFired + 1
    
    local r = math.rad( tank.rotation - 90 )
    local startX = tank.x + math.cos(r) * 22
    local startY = tank.y + math.sin(r) * 22
    
    if isRemote then
        startX, startY = rX, rY
        r = math.rad( rRot - 90 )
    else
        pcall(function() udp:send(json.encode({type="shoot", p=localPlayerId, x=startX, y=startY, rot=tank.rotation})) end)
    end
    
    if sndShoot then audio.play( sndShoot ) end
    
    local bullet = display.newCircle( bulletsGroup, startX, startY, 4 )
    bullet:setFillColor( 1, 1, 0.8 )
    
    -- Bullet Neon Glow
    local bGlow = display.newCircle( bulletsGroup, startX, startY, 8 )
    bGlow:setFillColor( unpack(tank.color) )
    bGlow.alpha = 0.5
    bullet.glow = bGlow
    
    bullet.isBullet = true
    bullet.bounces = 0
    bullet.owner = tank
    
    physics.addBody( bullet, "dynamic", { radius=4, bounce=1.0, friction=0 } )
    bullet.isSensor = false
    bullet:setLinearVelocity( math.cos(r) * 350, math.sin(r) * 350 )
    
    -- Sync glow position
    bullet.enterFrame = function(self)
        if self.x and self.glow and self.glow.x then
            self.glow.x, self.glow.y = self.x, self.y
        end
    end
    Runtime:addEventListener("enterFrame", bullet)
end

local function onCollision( event )
    if event.phase == "began" then
        local obj1 = event.object1
        local obj2 = event.object2
        
        local bullet, tank
        if obj1.isBullet and obj2.isTank then
            bullet, tank = obj1, obj2
        elseif obj2.isBullet and obj1.isTank then
            bullet, tank = obj2, obj1
        end
        
        if bullet and tank then
            if not isGameOver and not tank.isDead then
                tank.isDead = true
                tank.isVisible = false
                
                if tank.playerIdx == localPlayerId then
                    pcall(function() udp:send(json.encode({type="dead", p=localPlayerId})) end)
                end
                
                -- Premium explosion
                if sndExplode then audio.play( sndExplode ) end
                local exp1 = display.newCircle(tank.x, tank.y, 10)
                exp1:setFillColor(1, 1, 1)
                transition.to(exp1, {time=150, alpha=0, xScale=5, yScale=5, onComplete=function() display.remove(exp1) end})
                
                local exp2 = display.newCircle(tank.x, tank.y, 20)
                exp2:setFillColor(unpack(tank.color))
                transition.to(exp2, {time=500, alpha=0, xScale=4, yScale=4, onComplete=function() display.remove(exp2) end})
                
                timer.performWithDelay( 1, function()
                    Runtime:removeEventListener("enterFrame", bullet)
                    display.remove(bullet.glow)
                    display.remove(bullet)
                    display.remove(tank)
                end )
                
                checkRoundOver()
            end
            return
        end
        
        if (obj1.isBullet and obj2.isWall) or (obj2.isBullet and obj1.isWall) then
            local b = obj1.isBullet and obj1 or obj2
            b.bounces = b.bounces + 1
            if b.bounces > 5 then
                if b.owner then b.owner.bulletsFired = b.owner.bulletsFired - 1 end
                timer.performWithDelay( 1, function() 
                    Runtime:removeEventListener("enterFrame", b)
                    display.remove(b.glow)
                    display.remove(b) 
                end )
            end
        end
    end
end

Runtime:addEventListener( "collision", onCollision )

local keys = {}

local function onKeyEvent( event )
    keys[event.keyName] = (event.phase == "down" or event.phase == "repeat")
    
    if event.phase == "down" and not isGameOver and gameGroup.isVisible then
        local t = tanks[localPlayerId]
        if t and not t.isDead then
            if event.keyName == t.cfg.keys.shoot then 
                shoot(t) 
            end
        end
        if event.keyName == "escape" then
            gameGroup.isVisible = false
            menuGroup.isVisible = true
        end
    end
    return false
end

Runtime:addEventListener( "key", onKeyEvent )

local speed = 130
local turnSpeed = 4.5

local function moveTanks()
    if isGameOver or not gameGroup.isVisible then return end
    
    repeat
        local data, err = udp:receive()
        if data then
            local msg = json.decode(data)
            if msg and msg.p and msg.p ~= localPlayerId then
                local t = tanks[msg.p]
                if t and not t.isDead then
                    if msg.type == "pos" then
                        t.x, t.y, t.rotation = msg.x, msg.y, msg.rot
                    elseif msg.type == "shoot" then
                        shoot(t, true, msg.x, msg.y, msg.rot)
                    elseif msg.type == "dead" then
                        t.isDead = true
                        t.isVisible = false
                        if sndExplode then audio.play( sndExplode ) end
                        local exp = display.newCircle(t.x, t.y, 40)
                        exp:setFillColor(unpack(t.color))
                        transition.to(exp, {time=400, alpha=0, xScale=1.5, yScale=1.5, onComplete=function() display.remove(exp) end})
                        timer.performWithDelay(1, function() display.remove(t) end)
                        checkRoundOver()
                    end
                end
            end
        end
    until not data

    local t = tanks[localPlayerId]
    if t and not t.isDead then
        if keys[t.cfg.keys.up] then
            local r = math.rad( t.rotation - 90 )
            t:setLinearVelocity( math.cos(r)*speed, math.sin(r)*speed )
        elseif keys[t.cfg.keys.down] then
            local r = math.rad( t.rotation - 90 )
            t:setLinearVelocity( -math.cos(r)*speed, -math.sin(r)*speed )
        else
            t:setLinearVelocity( 0, 0 )
        end
        
        if keys[t.cfg.keys.left] then
            t.angularVelocity = -turnSpeed * 40
        elseif keys[t.cfg.keys.right] then
            t.angularVelocity = turnSpeed * 40
        else
            t.angularVelocity = 0
        end
        
        pcall(function() udp:send(json.encode({type="pos", p=localPlayerId, x=t.x, y=t.y, rot=t.rotation})) end)
    end
end

Runtime:addEventListener( "enterFrame", moveTanks )