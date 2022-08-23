
local BASE_UI_SCALE = Instance.new('UIScale')
BASE_UI_SCALE.Name = '_UI_SCALE'
BASE_UI_SCALE.Scale = 1

local BASE_CIRCLE_UI_CORNER = Instance.new('UICorner')
BASE_CIRCLE_UI_CORNER.Name = '_UI_CORNER'
BASE_CIRCLE_UI_CORNER.CornerRadius = UDim.new(0.5, 0)

local BASE_INV_IMAGE_BUTTON = Instance.new('ImageButton')
BASE_INV_IMAGE_BUTTON.Name = 'Button'
BASE_INV_IMAGE_BUTTON.Position = UDim2.fromScale(0.5, 0.5)
BASE_INV_IMAGE_BUTTON.AnchorPoint = Vector2.new(0.5, 0.5)
BASE_INV_IMAGE_BUTTON.Size = UDim2.fromScale(1, 1)
BASE_INV_IMAGE_BUTTON.BackgroundTransparency = 1
BASE_INV_IMAGE_BUTTON.ImageTransparency = 1
BASE_INV_IMAGE_BUTTON.ZIndex = 25

local BASE_UI_PADDING = Instance.new('UIPadding')
BASE_UI_PADDING.Name = '_UI_PADDING'

local BASE_UI_ASPECT_RATIO = Instance.new('UIAspectRatioConstraint')
BASE_UI_ASPECT_RATIO.AspectType = Enum.AspectType.ScaleWithParentSize

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

Module.BASE_UI_PADDING = BASE_UI_PADDING
Module.BASE_UI_SCALE = BASE_UI_SCALE
Module.BASE_INV_IMAGE_BUTTON = BASE_INV_IMAGE_BUTTON
Module.BASE_CIRCLE_UI_CORNER = BASE_CIRCLE_UI_CORNER
Module.BASE_UI_ASPECT_RATIO = BASE_UI_ASPECT_RATIO

local baseTreeSelectButton = Instance.new('TextButton') do
	baseTreeSelectButton.Name = 'TreeDataSelectButton'
	baseTreeSelectButton.TextColor3 = Color3.new(0.4, 0.4, 0.4)
	baseTreeSelectButton.BackgroundColor3 = Color3.fromRGB(93, 93, 93)
	baseTreeSelectButton.BackgroundTransparency = 0.8
	baseTreeSelectButton.BorderSizePixel = 0
	BASE_UI_SCALE:Clone().Parent = baseTreeSelectButton
end
Module.baseTreeSelectButton = baseTreeSelectButton

local baseFlowChartContainerFrame = Instance.new('Frame') do
	baseFlowChartContainerFrame.BackgroundTransparency = 1
	baseFlowChartContainerFrame.Size = UDim2.fromScale(0.975, 0.975)
	baseFlowChartContainerFrame.Position = UDim2.fromScale(0.5, 0.5)
	baseFlowChartContainerFrame.BorderSizePixel = 0
	baseFlowChartContainerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
end
Module.baseFlowChartContainerFrame = baseFlowChartContainerFrame

local baseFlowChartNodeFrame = Instance.new('Frame') do
	baseFlowChartNodeFrame.BackgroundColor3 = Color3.fromRGB(111, 130, 165)
	baseFlowChartNodeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	baseFlowChartNodeFrame.BackgroundTransparency = 0.05
	baseFlowChartNodeFrame.Size = UDim2.fromOffset(40, 40)
	baseFlowChartNodeFrame.BorderSizePixel = 0
	BASE_CIRCLE_UI_CORNER:Clone().Parent = baseFlowChartNodeFrame
	BASE_INV_IMAGE_BUTTON:Clone().Parent = baseFlowChartNodeFrame
end
Module.baseFlowChartNodeFrame = baseFlowChartNodeFrame

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

local BEZIER_RESOLUTION = 2 -- frame/pixels
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
