local scheduler = require("framework.scheduler")

local MainScene = class("MainScene", function()
	return display.newScene("MainScene")
end)

local totalScore = 0
local bestScore = 0
local configFile = device.writablePath.."game.config"

local GRAVITY         = 0
local TANK_MASS = 10000
local TANK_WIDTH = 48
local TANK_HEIGHT = 62
local TANK_FRICTION = 0.3
local TANK_ELASTICITY = 0.3
local SHELL_MASS       = 50
local SHELL_WIDTH     = 4
local SHELL_HEIGHT     = 8
local SHELL_FRICTION   = 0.5
local SHELL_ELASTICITY = 0.1
local BLOCK_MASS = 0
local BLOCK_WIDTH = 40
local BLOCK_HEIGHT = 40
local BLOCK_FRICTION = 0.3
local BLOCK_ELASTICITY = 0.3
local WALL_MASS = 0
local WALL_THICKNESS  = 100
local WALL_FRICTION   = 0.3
local WALL_ELASTICITY = 0.3

math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )
local random = math.random

local matrix = {}
for i=1,3 do
    matrix[i] = {}
    for j=1,4 do
        matrix[i][j] = nil
    end
end

local tanks = {}
local shells = {}
local blocks = {}
local angels = {0, 90, 180, 270}
--local square = nil
local battleField = nil
local world = nil
local myTank = nil

local tankMoves = {
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"turn",
	"turn",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
	"forward",
	"forward",
	"forward",
	"fire",
	"fire",
}

function saveStatus()
	local gridstr = serialize(grid)
	local isOverstr = "false"
	if isOver then isOverstr = "true" end
	local str = string.format("do local grid,bestScore,totalScore,WINSTR,isOver \
		=%s,%d,%d,\'%s\',%s return grid,bestScore,totalScore,WINSTR,isOver end",
		gridstr,bestScore,totalScore,WINSTR,isOverstr)
	io.writefile(configFile,str)
end

function MainScene:loadStatus()
	if io.exists(configFile) then
		local str = io.readfile(configFile)
		if str then
			local f = loadstring(str)
			local _grid,_bestScore,_totalScore,_WINSTR,_isOver = f()
			if _grid and _bestScore and _totalScore and _WINSTR then
				grid,bestScore,totalScore,WINSTR,isOver = _grid,_bestScore,_totalScore,_WINSTR,_isOver
			end
		end
	end
	self:reLoadGame()
end



--方块的构造函数
Block = {}
function Block:new(p)
	local obj = p
	if (obj == nil) then
		obj = { blockType=1, x=0, y=0 }
	end
	obj.blockSprite = display.newSprite("block_"..obj.blockType..".png", obj.x, obj.y)
	battleField:addChild(obj.blockSprite)
	obj.box = obj.blockSprite:getBoundingBox()
	obj.blockRect = CCRect(obj.x-20, obj.y-20, 40, 40)

	-- obj.blockBody = world:createBoxBody(BLOCK_MASS, BLOCK_WIDTH, BLOCK_HEIGHT)
	-- obj.blockBody:setFriction(BLOCK_FRICTION)
	-- obj.blockBody:setElasticity(BLOCK_ELASTICITY)
	-- obj.blockBody:bind(obj.blockSprite)
	-- obj.blockBody:setPosition(obj.x, obj.y)

	self.__index = self
	return setmetatable(obj, self)
end

function Block:disappear()
	self.blockSprite:removeSelf()
	self.blockSprite = nil
end

Tank = {}
function Tank:new(p)
	local obj = p
	if (obj == nil) then
		obj = { angle=90, x=0, y=0, speed=10}
	end
	obj.tankSprite = display.newSprite("tank.png", obj.x, obj.y)
	obj.tankSprite:setRotation(90-obj.angle)
	--obj.shellSprite = display.newSprite("shell.png", 24, 62)
	--obj.tankSprite:addChild(obj.shellSprite)
	battleField:addChild(obj.tankSprite)
	obj.box = obj.tankSprite:getBoundingBox()

	-- obj.tankBody = world:createBoxBody(TANK_MASS, TANK_WIDTH, TANK_HEIGHT)
	-- obj.tankBody:setFriction(TANK_FRICTION)
	-- obj.tankBody:setElasticity(TANK_ELASTICITY)
	-- obj.tankBody:bind(obj.tankSprite)
	-- obj.tankBody:setPosition(obj.x, obj.y)
	-- obj.tankBody:setRotation(obj.angle-90)


	self.__index = self
	return setmetatable(obj, self)
end

function Tank:turn(dir)
	local dir = dir or 1
	self.angle = (self.angle - 90*dir)%360
	local action = CCRotateTo:create(0.35, self.angle-90)
	--self.tankBody:setRotation(self.angle-90)
	self.tankSprite:runAction(action)
end

function Tank:move(dir)
	local dir = dir or 1
	local speed = self.speed
	local disx=nil
	local disy=nil
	if (self.angle==90) then
		disx=0
		disy=speed*dir
	elseif (self.angle==180) then
		disx=speed*dir
		disy=0
	elseif (self.angle==270) then
		disx=0
		disy=-1*speed*dir
	elseif self.angle==0 then
		disx=-1*speed*dir
		disy=0
	end
	local action = CCMoveBy:create(0.5, CCPoint(disx, disy))
	self.tankSprite:runAction(action)
	self.x = self.x+disx
	self.y = self.y+disy
end

function Tank:fire()
	local shell = Shell:new({angle=self.angle})
	local sp = shell.shellSprite
	table.insert(shells, shell)

	if (self.angle==0) then
		sp:setRotation(-90)
		sp:setPosition(self.x-31-5, self.y)
		dx = -200
		dy = 0
	elseif self.angle==90 then
		--sp:setRotation(-90)
		sp:setPosition(self.x, self.y+31+5)
		dx = 0
		dy = 200
	elseif self.angle==180 then
		sp:setRotation(90)
		sp:setPosition(self.x+31+5, self.y)
		dx = 200
		dy = 0
	else
		sp:setRotation(180)
		sp:setPosition(self.x, self.y-31-5)
		dx = 0
		dy = -200
	end

	transition.execute(sp, CCMoveBy:create(0.2, CCPoint(dx, dy)), {
		onComplete = function()
			shell:explode()
		end,
	})


	


	-- if self.loaded==false then
	-- 	transition.execute(self.tankSprite, CCMoveBy:create(0.5, CCPoint(0, 0)), {
	-- 		onComplete = function()
	-- 			self.loaded = true
	-- 		end,
	-- 	})
	-- else
	-- 	local shellSprite = display.newSprite("shell.png")
	-- 	battleField:addChild(shellSprite)
	-- 	local shellBox = shellSprite:getBoundingBox()

	-- 	-- create body
	-- 	local shellBody = world:createBoxBody(SHELL_MASS, SHELL_WIDTH, SHELL_HEIGHT)
	-- 	shellBody:setFriction(SHELL_FRICTION)
	-- 	shellBody:setElasticity(SHELL_ELASTICITY)
	-- 	shellBody:bind(shellSprite)
	-- 	if (self.angle==0) then
	-- 		shellBody:setRotation(-90)
	-- 		shellBody:setPosition(self.x-31, self.y)
	-- 		vx = -200
	-- 		vy = 0
	-- 	elseif (self.angle==90) then
	-- 		shellBody:setPosition(self.x,self.y+31)
	-- 		vx = 0
	-- 		vy = 200
	-- 	elseif (self.angle==180) then
	-- 		shellBody:setRotation(90)
	-- 		shellBody:setPosition(self.x+31, self.y)
	-- 		vx = 200
	-- 		vy = 0
	-- 	elseif (self.angle==270) then
	-- 		shellBody:setRotation(180)
	-- 		shellBody:setPosition(self.x,self.y-31)
	-- 		vx = 0
	-- 		vy = -200
	-- 	end	
	-- 		shellBody:setVelocity(vx, vy)
	-- 		self.loaded = false
	-- end

	
end

function Tank:die()
	self.tankSprite:removeSelf()
	self.tankSprite = nil
end

function Tank:patrol()
	local step = tankMoves[self.step]
	if step=="forward" then
	 	self:move()
	elseif step=="fire" then
	 	self:fire()
	else
		self:turn()
	end

	if self.step<122 then
		self.step = self.step+1
	else
		self.step = 1
	end
end

Shell = {}
function Shell:new(p)
	local obj = p
	if (obj == nil) then
		obj = { angle=90, x=0, y=0 }
	end
	obj.shellSprite = display.newSprite("shell.png", obj.x, obj.y)
	obj.shellSprite:setRotation(90-obj.angle)
	battleField:addChild(obj.shellSprite)
	obj.box = obj.shellSprite:getBoundingBox()

	-- obj.shellBody = world:createBoxBody(SHELL_MASS, SHELL_WIDTH, SHELL_HEIGHT)
	-- obj.shellBody:setFriction(SHELL_FRICTION)
	-- obj.shellBody:setElasticity(SHELL_ELASTICITY)
	-- obj.shellBody:bind(obj.shellSprite)
	-- obj.shellBody:setPosition(obj.x, obj.y)
	-- obj.shellBody:setRotation(obj.angle-90)


	self.__index = self
	return setmetatable(obj, self)
end

function Shell:explode()
	self.shellSprite:removeSelf()
	self.shellSprite = nil
end

function MainScene:restartGame()
	grid = initGrid(4,4)
	totalScore = 0
	WINSTR = ""
	isOver = false
	self:reLoadGame()
	saveStatus()
end

function MainScene:createButtons(t, x, y)
	local btnText = t
	local btnX = x
	local btnY = y

	local images = {
		normal = "btn_normal.png",
		pressed = "btn_pressed.png",
		disabled = "bt_bg.png",
	}
	return cc.ui.UIPushButton.new(images, {scale9 = false})
		:setButtonLabel("normal", ui.newTTFLabel({
			text = btnText,
			size = 32
		}))
		:align(display.CENTER, x, y)
		:addTo(self)
end

function MainScene:ctor()

	local square = display.newTilesSprite("background.png", cc.rect(20, 140, 600, 800))
	square:setPosition(20, 140)
	self:addChild(square)

	battleField = CCLayerColor:create(ccc4(255, 0, 0, 50), 600, 800)
	battleField:setPosition(20, 140)
	self:addChild(battleField)
	-- create physics world
	-- world = CCPhysicsWorld:create(0, GRAVITY)
	-- self.world = world
	-- battleField:addChild(self.world)

	self:createPlayground()

	-- add debug node
	-- self.worldDebug = self.world:createDebugNode()
	-- battleField:addChild(self.worldDebug)

	
	local btn1 = self:createButtons("New Game", display.left+120, display.bottom+50):onButtonClicked(function(event)
		myTank:fire()
	end)


	local btn2 = self:createButtons("EXIT", display.right-120, display.bottom+50):onButtonClicked(function (event)
		--print("X: "..tank5.tankSprite:getPositionX().." Y: "..tank5.tankSprite:getPositionY().." WIDTH: "..tank5.tankSprite:getContentSize().width.." HEIGHT: "..tank5.tankSprite:getContentSize().height.." ANGLE:"..tank5.angle)
		dump(shells)
	end)

	local btnUp = cc.ui.UIPushButton.new("block_6.png")
		:align(display.CENTER,320,100)
		:addTo(self)
		:onButtonClicked(function()
			--self:unscheduleUpdate()
			myTank:move()
		end)

	local btnDown = cc.ui.UIPushButton.new("block_6.png")
		:align(display.CENTER,320,60)
		:addTo(self)
		:onButtonClicked(function()
			self:unscheduleUpdate()
			myTank:move(-1)
		end)

	local btnLeft = cc.ui.UIPushButton.new("block_6.png")
		:align(display.CENTER,280,80)
		:addTo(self)
		:onButtonClicked(function()
			myTank:turn()
		end)

	local btnRIght = cc.ui.UIPushButton.new("block_6.png")
		:align(display.CENTER,360,80)
		:addTo(self)
		:onButtonClicked(function()
			myTank:turn(-1)
		end)

	self:scheduleUpdate(function(dt)
		self:update(dt)
	end)

    scheduler.scheduleGlobal(function()
            tanks[1]:patrol()
            tanks[2]:patrol()
            tanks[3]:patrol()
            tanks[4]:patrol()
    end, 1.0)
end


function MainScene:createPlayground()

	local frame = display.newSprite("frame.png", display.cx, display.cy)
	frame:setOpacity(100)
	self:addChild(frame)

	-- self.gameTItle = cc.ui.UILabel.new({text = "TANK", size = 24, color = display.COLOR_BLACK})
	-- 	:align(display.CENTER, display.cx, display.top - 40)
	-- 	:addTo(self)
	self.scoreLabel = cc.ui.UILabel.new({
		text = "SCORE:200",
		size = 16,
		color = display.COLOR_WHITE,
	})
	self.scoreLabel:align(display.CENTER,display.cx,display.bottom + 920):addTo(self)

	-- -- add static body
	-- local leftWallSprite = display.newSprite("rec.png", -32, 400)
	-- leftWallSprite:setScaleY(12)
	-- battleField:addChild(leftWallSprite)
	-- local leftWallBody = self.world:createBoxBody(WALL_MASS, WALL_THICKNESS, WALL_THICKNESS*8)
	-- leftWallBody:setFriction(WALL_FRICTION)
	-- leftWallBody:setElasticity(WALL_ELASTICITY)
	-- leftWallBody:bind(leftWallSprite)
	-- leftWallBody:setPosition(-50, 400)

	-- local rightWallSprite = display.newSprite("rec.png", 600+32, 400)
	-- rightWallSprite:setScaleY(12)
	-- battleField:addChild(rightWallSprite)
	-- local rightWallBody = self.world:createBoxBody(WALL_MASS, WALL_THICKNESS, WALL_THICKNESS*8)
	-- rightWallBody:setFriction(WALL_FRICTION)
	-- rightWallBody:setElasticity(WALL_ELASTICITY)
	-- rightWallBody:bind(rightWallSprite)
	-- rightWallBody:setPosition(600+50, 400)

	-- local bottomWallSprite = display.newSprite("rec.png", 300, -32)
	-- bottomWallSprite:setScaleX(8)
	-- battleField:addChild(bottomWallSprite)
	-- local bottomWallBody = self.world:createBoxBody(WALL_MASS, WALL_THICKNESS*6, WALL_THICKNESS)
	-- bottomWallBody:setFriction(WALL_FRICTION)
	-- bottomWallBody:setElasticity(WALL_ELASTICITY)
	-- bottomWallBody:bind(bottomWallSprite)
	-- bottomWallBody:setPosition(300, -50)

	-- local topWallSprite = display.newSprite("rec.png", 300, 800+32)
	-- topWallSprite:setScaleX(8)
	-- battleField:addChild(topWallSprite)
	-- local topWallBody = self.world:createBoxBody(WALL_MASS, WALL_THICKNESS*6, WALL_THICKNESS)
	-- topWallBody:setFriction(WALL_FRICTION)
	-- topWallBody:setElasticity(WALL_ELASTICITY)
	-- topWallBody:bind(topWallSprite)
	-- topWallBody:setPosition(300, 850)

	-- local wall1 = display.newSprite("wall.png", 45, 440)
	-- battleField:addChild(wall1)

	-- local wall2 = display.newSprite("wall.png", 555, 440)
	-- battleField:addChild(wall2)

	-- local wall1Body = self.world:createBoxBody(WALL_MASS, 90, 20)
	-- wall1Body:setFriction(WALL_FRICTION)
	-- wall1Body:setElasticity(WALL_ELASTICITY)
	-- wall1Body:bind(wall1)
	-- wall1Body:setPosition(45, 440)

	-- local wall2Body = self.world:createBoxBody(WALL_MASS, 90, 20)
	-- wall2Body:setFriction(WALL_FRICTION)
	-- wall2Body:setElasticity(WALL_ELASTICITY)
	-- wall2Body:bind(wall2)
	-- wall2Body:setPosition(555, 440)

	local offsetX = 130
	local offsetY = 200

	for i=1,3 do
		for j=1,4 do
			local t = random(6)
			local b1 = Block:new({blockType=t, x=(i-1)*170-20+offsetX, y=(j-1)*160-20+offsetY})
			local b2 = Block:new({blockType=t, x=(i-1)*170-20+offsetX, y=(j-1)*160+20+offsetY})
			local b3 = Block:new({blockType=t, x=(i-1)*170+20+offsetX, y=(j-1)*160+20+offsetY})
			local b4 = Block:new({blockType=t, x=(i-1)*170+20+offsetX, y=(j-1)*160-20+offsetY})
			--matrix[i][j] = {b1, b2, b3, b4}
			table.insert(blocks, b1)
			table.insert(blocks, b2)
			table.insert(blocks, b3)
			table.insert(blocks, b4)
		end
	end

	tank1 = Tank:new({angle=270, x=44, y=750, speed=10, step=1})
	tank2 = Tank:new({angle=270, x=214, y=750, speed=14, step=2})
	tank3 = Tank:new({angle=270, x=384, y=750, speed=18, step=3})
	tank4 = Tank:new({angle=270, x=554, y=750, speed=22, step=4})
	--tank5 = Tank:new({angle=90, x=300, y=70})
	tank5 = Tank:new({angle=90, x=280, y=600, speed=12})

	myTank = tank5

	table.insert(tanks, tank1)
	table.insert(tanks, tank2)
	table.insert(tanks, tank3)
	table.insert(tanks, tank4)


	--self.world:addCollisionScriptListener(handler(self, self.onCollisionListener), 0, 2)

end

-- function MainScene:onCollisionListener(eventType, event)
-- 	print("eventType: "..eventType)
-- 	return true
-- end

function MainScene:onEnter()
	-- local layer = CCLayerColor:create(ccc4(255, 200, 0, 0), 600, 800)
	-- layer:addNodeEventListener(cc.NODE_TOUCH_EVENT, function(event)
	-- 	return self:onTouch(event.name, event.x, event.y)
	-- end)
	-- layer:setTouchEnabled(true)
	-- layer:setTouchSwallowEnabled(false)
	-- layer:setPosition(20, 140)
	-- self:addChild(layer)

	--self.world:start()

end

function MainScene:update()
	for i, shell in pairs (shells) do
		local s = shell
		if s.shellSprite==nil then
			table.remove(shells, i)
		else
			local sw = nil
			local sh = nil
			if s.angle==0 or s.angle==180 then
				sh = s.shellSprite:getContentSize().width
				sw = s.shellSprite:getContentSize().height
			elseif s.angle==90 or s.angle==270 then
				sw = s.shellSprite:getContentSize().width
				sh = s.shellSprite:getContentSize().height
			end
			local sx = s.shellSprite:getPositionX()-sw/2
			local sy = s.shellSprite:getPositionY()-sh/2
			local sRect = CCRect(sx, sy, sw, sh)

			for j, tank in pairs (tanks) do
				local t = tank
				if t.tankSprite==nil then
					table.remove(tanks, j)
					table.remove(shells, i)
				else
					local tw = nil
					local th = nil
					if t.angle==0 or t.angle==180 then
						th = t.tankSprite:getContentSize().width
						tw = t.tankSprite:getContentSize().height
					elseif t.angle==90 or t.angle==270 then
						tw = t.tankSprite:getContentSize().width
						th = t.tankSprite:getContentSize().height
					end
					local tx = t.tankSprite:getPositionX()-tw/2
					local ty = t.tankSprite:getPositionY()-th/2
					local tRect = CCRect(tx, ty, tw, th)

					if sRect:intersectsRect(tRect) then
						s:explode()
						t:die()
					end

				end
				
			end

			for m=1,48 do
				local b = blocks[m]
				local bx = b.x-20
				local by = b.y-20
				local bRect = CCRect(bx, by, 40, 40)
				if sRect:intersectsRect(bRect) then
					s:explode()
					if b.blockType~=6 then
						b:disappear()
					end
				end
				if b.blockSprite==nil then
					table.remove(shells, i)
					table.remove(blocks, m)
				end
			end

		end
		


		-- for m, block in pairs (blocks) do
		-- 	local b = block
		-- 	local bx = b.x-20
		-- 	local by = b.y-20
		-- 	local bRect = CCRect(bx, by, 40, 40)
		-- 	if sRect:intersectsRect(bRect) then
		-- 		s:explode()
		-- 		b:disappear()
		-- 	end
		-- 	if b.blockSprite==nil then
		-- 		table.remove(blocks, m)
		-- 	end
		-- end

	end
	
end


return MainScene
