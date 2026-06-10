local Cam = workspace.CurrentCamera
local LocalPlr = player or game:GetService("Players").LocalPlayer 

-- 确保 _G.SA_Config 存在，如果不存在则初始化
_G.SA_Config = _G.SA_Config or {
    on = false,      
    fov = 150,       
    sFov = false,     
    team = false,    
    vis = false,     
    wall = false     
}

-- 确保 C 和 F 存在，提供默认值以增强兼容性
local C = _G.C or {RED = Color3.fromRGB(255, 0, 0), GRN = Color3.fromRGB(0, 255, 0), BG_CARD = Color3.fromRGB(30, 30, 30)}
local F = _G.F or Enum.Font.SourceSans

local tarPart = nil 
local wallPart = nil -- 用于存放墙后最近目标的变量

-- 射线参数
local SharedWallParams = RaycastParams.new()
SharedWallParams.FilterType = Enum.RaycastFilterType.Include

local SharedVisParams = RaycastParams.new()
SharedVisParams.FilterType = Enum.RaycastFilterType.Exclude

-- FOV 范围圈
_G.fovC = Drawing.new("Circle")
local fovC = _G.fovC
fovC.Visible = false
fovC.Color = C.RED
fovC.Thickness = 1
fovC.Filled = false
fovC.NumSides = 60

-- 目标标记圈（原本的自瞄锁定圈）
_G.tarC = Drawing.new("Circle")
local tarC = _G.tarC
tarC.Visible = false
tarC.Color = Color3.fromRGB(255, 255, 255)
tarC.Thickness = 1.5
tarC.Filled = false
tarC.Radius = 6
tarC.NumSides = 16

-- 墙后目标标记圈（样式与 tarC 一致，固定为红色）
_G.wallC = Drawing.new("Circle")
local wallC = _G.wallC
wallC.Visible = false
wallC.Color = Color3.fromRGB(255, 0, 0)
wallC.Thickness = 1.5
wallC.Filled = false
wallC.Radius = 6
wallC.NumSides = 16

-- 不依赖开关的纯视线检测（供圆圈显示用）
local function rawVisibility(part)
    if not LocalPlr.Character then return false end
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {LocalPlr.Character, part.Parent}
    local result = workspace:Raycast(Cam.CFrame.Position, part.Position - Cam.CFrame.Position, rayParams)
    return not result
end

-- 自瞄目标筛选时使用的可见性检测（受 wall/vis 开关影响）
local function isTargetVisible(part)
    if _G.SA_Config.wall then return true end           -- 墙体穿透：无视遮挡
    if not _G.SA_Config.vis then return true end         -- 未开启可见性检查：默认全部可见
    if not LocalPlr.Character then return false end

    SharedVisParams.FilterDescendantsInstances = {LocalPlr.Character, part.Parent}
    local res = workspace:Raycast(Cam.CFrame.Position, part.Position - Cam.CFrame.Position, SharedVisParams)
    return not res
end

-- 获取最佳自瞄目标（支持双目标返回）
local function getSilentAimTarget()
    if not _G.SA_Config.on then return nil, nil end
    local center = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
    
    local bDist = _G.SA_Config.fov
    local bTar = nil

    local wDist = _G.SA_Config.fov
    local wTar = nil

    for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
        if p ~= LocalPlr and p.Character and p.Character:FindFirstChild("Head") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            if _G.SA_Config.team and p.Team == LocalPlr.Team then continue end
            
            local head = p.Character.Head
            local sPos, onScr = Cam:WorldToViewportPoint(head.Position)
            
            if onScr then
                local dist = (Vector2.new(sPos.X, sPos.Y) - center).Magnitude
                
                -- 1. 原本的实际自瞄锁定筛选
                if dist < bDist then
                    local canAim = _G.SA_Config.wall or rawVisibility(head)
                    if canAim then
                        bDist = dist
                        bTar = head 
                    end
                end

                -- 2. 当默认未开启穿墙和可见性检查时，筛选距离最近的潜在玩家
                if not _G.SA_Config.wall and not _G.SA_Config.vis then
                    if dist < wDist then
                        wDist = dist
                        wTar = head
                    end
                end
            end
        end
    end
    
    -- 如果这个最近的潜在目标其实是“可见”的，则交由正常的自瞄圈处理（实现可见后隐藏红圈）
    if wTar and rawVisibility(wTar) then
        wTar = nil
    end

    return bTar, wTar
end

-- 异步循环更新目标
task.spawn(function()
    while true do
        if _G.SA_Config.on then
            tarPart, wallPart = getSilentAimTarget() 
        else
            tarPart = nil
            wallPart = nil
        end
        task.wait(0.03) 
    end
end)

-- 每帧渲染绘图
game:GetService("RunService").RenderStepped:Connect(function()
    local center = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
    fovC.Position = center
    fovC.Radius = _G.SA_Config.fov
    fovC.Visible = (_G.SA_Config.on and _G.SA_Config.sFov)

    -- 原本的自瞄锁定圈渲染逻辑
    if tarPart and tarPart.Parent then
        local pos, onScr = Cam:WorldToViewportPoint(tarPart.Position)
        if onScr then
            tarC.Position = Vector2.new(pos.X, pos.Y)
            local realVisible = rawVisibility(tarPart)

            if _G.SA_Config.wall then
                tarC.Color = C.GRN or Color3.fromRGB(0, 255, 0) -- Fallback if C.GRN is not defined
                tarC.Visible = true
            elseif _G.SA_Config.vis then
                if realVisible then
                    tarC.Color = C.GRN or Color3.fromRGB(0, 255, 0)
                    tarC.Visible = true
                else
                    tarC.Visible = false
                end
            else
                tarC.Color = (realVisible and (C.GRN or Color3.fromRGB(0, 255, 0))) or (C.RED or Color3.fromRGB(255, 0, 0))
                tarC.Visible = true
            end
        else
            tarC.Visible = false
        end
    else
        tarC.Visible = false
    end

    -- 墙后目标红色圆圈的渲染逻辑
    if not _G.SA_Config.wall and not _G.SA_Config.vis and wallPart and wallPart.Parent then
        local pos, onScr = Cam:WorldToViewportPoint(wallPart.Position)
        if onScr then
            wallC.Position = Vector2.new(pos.X, pos.Y)
            wallC.Visible = true
        else
            wallC.Visible = false
        end
    else
        wallC.Visible = false
    end
end)

-- 【核心修改】全底层物理射线检测劫持 (Raycast)
local oldNC
oldNC = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    
    if _G.SA_Config.on and tarPart and tarPart.Parent and not checkcaller() then
        if method == "Raycast" then
            local args = {...}
            local origin = args[1]
            local dir = args[2]
            
            if typeof(origin) == "Vector3" and typeof(dir) == "Vector3" then
                local mag = dir.Magnitude
                if mag < 1 then mag = 1000 end
                
                -- 【修改】直接将射线方向重定向至目标零件
                args[2] = (tarPart.Position - origin).Unit * mag

                if _G.SA_Config.wall then
                    -- 穿墙模式：强制覆盖参数，只对目标模型生效，无视一切地图障碍物
                    SharedWallParams.FilterDescendantsInstances = {tarPart.Parent}
                    args[3] = SharedWallParams
                -- 不开穿墙模式时：不更改原游戏的 args[3] (RaycastParams)，让原游戏的物理阻挡规则（如墙壁）自然拦截射线
                end
                
                return oldNC(self, unpack(args, 1, 3))
            end
        end
    end
    return oldNC(self, ...)
end))
