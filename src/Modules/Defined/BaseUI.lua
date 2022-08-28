
-- https://javascript.info/bezier-curve
local function getCubicBezier(p1, p2, p3, p4, alpha)
	return
		math.pow( 1 - alpha, 3 ) * p1 +
		3 * math.pow(1 - alpha, 2) * alpha * p2 +
		3 * (1 - alpha) * math.pow(alpha, 2) * p3 +
		math.pow(alpha, 3) * p4
end

-- // Module // --
local Module = {}

local BASE_INV_IMAGE_BUTTON = Instance.new('ImageButton')
BASE_INV_IMAGE_BUTTON.Name = 'Button'
BASE_INV_IMAGE_BUTTON.Position = UDim2.fromScale(0.5, 0.5)
BASE_INV_IMAGE_BUTTON.AnchorPoint = Vector2.new(0.5, 0.5)
BASE_INV_IMAGE_BUTTON.Size = UDim2.fromScale(1, 1)
BASE_INV_IMAGE_BUTTON.BackgroundTransparency = 1
BASE_INV_IMAGE_BUTTON.ImageTransparency = 1
BASE_INV_IMAGE_BUTTON.ZIndex = 25
Module.INV_IMAGE_BUTTON = BASE_INV_IMAGE_BUTTON

local BASE_CIRCLE_UI_CORNER = Instance.new('UICorner')
BASE_CIRCLE_UI_CORNER.Name = '_UI_CORNER'
BASE_CIRCLE_UI_CORNER.CornerRadius = UDim.new(0.5, 0)
Module.CIRCLE_UI_CORNER = BASE_CIRCLE_UI_CORNER

local baseLineFrame = Instance.new('Frame')
baseLineFrame.BackgroundTransparency = 0
baseLineFrame.BackgroundColor3 = Color3.new(1, 1, 1)
baseLineFrame.BorderSizePixel = 0
baseLineFrame.ZIndex = -1
function Module:Line(p1, p2)
	local dir = (p2 - p1)
	local length = dir.Magnitude
	local newFrame = baseLineFrame:Clone()
	newFrame.Rotation = math.deg( math.atan2(dir.y, dir.x) )
	newFrame.Size = UDim2.fromOffset(length, 2)
	newFrame.Position = UDim2.fromOffset(p1.x - length, p1.y)
	return newFrame
end

local BEZIER_RESOLUTION = 1 -- frame/pixels
function Module:CubicBezierLine(p1, p2, p3, p4)
	local bezierFrames = {}
	local totalSteps = math.floor((p4 - p1).Magnitude / BEZIER_RESOLUTION)
	local delta = (1 / totalSteps)
	for step = 1, totalSteps do
		local v = (step * delta)
		local vectorA = getCubicBezier(p1, p2, p3, p4, v - delta)
		local vectorB = getCubicBezier(p1, p2, p3, p4, v + delta)
		table.insert(bezierFrames, Module:Line(vectorA, vectorB))
	end
	return bezierFrames
end

return Module
