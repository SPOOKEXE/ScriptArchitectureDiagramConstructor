
local HttpService = game:GetService('HttpService')

local function setProperties(thisTable, toThis)
	for k,v in pairs(thisTable) do
		toThis[k] = v
	end
	return toThis
end

-- // BASE NODE // --
local BaseNode = {}
BaseNode.__index = BaseNode

function BaseNode.New()
	return setmetatable({
		x = 0,
		y = 0,
		layerZ = 0, -- what column they are in
		radius = 35,
		depends = {},
	}, BaseNode)
end

function BaseNode:SetPosition(nX : number, nY : number)
	self.x = nX
	self.y = nY
end

function BaseNode:SetLayer(nLayer : number)
	self.layerZ = nLayer
end

-- // NODE // --
local Node = BaseNode.New()
Node.__index = Node

function Node.New(nodeID)
	return setmetatable(setProperties({
		ID = nodeID or HttpService:GenerateGUID(false),
		depends = {},
		orderNumber = 0, -- set automatically to make room for lines
	}, BaseNode.New()), Node)
end

function Node:LoadDepends(dependsTable)
	for _, str in ipairs( dependsTable ) do
		table.insert(self.depends, str)
	end
end

-- // TREE CLASS // --
local TreeData = {}
TreeData.__index = TreeData

function TreeData.New()
	return setmetatable({
		visible = false,
		nodes = {},
		IDToNode = {},
		LayerZToNodeArray = {},

		widthSeparation = 100,
		windowHeight = 800
	}, TreeData)
end

--[[
	{
		{ ID = 'blah2', Depends = {}, Layer = 1 },
		{ ID = 'blah', Depends = {'blah2'}, Layer = 2 },
	}
]]

function TreeData:LoadNodes( nodesTable )
	-- add all nodes
	for _, nodeData in ipairs( nodesTable ) do
		local layerZArray = self.LayerZToNodeArray[nodeData.Layer]
		if not layerZArray then
			layerZArray = {}
			self.LayerZToNodeArray[nodeData.Layer] = layerZArray
		end

		local newNode = Node.New(nodeData.ID)
		newNode:SetLayer(nodeData.Layer)
		newNode:LoadDepends( nodeData.Depends )

		table.insert(self.nodes, newNode) -- array
		self.IDToNode[nodeData.ID] = newNode -- hashmap
		table.insert(layerZArray, newNode) -- layer array
	end

	-- check duplicate dependancies (recursive)
	for layerNumber, layerNodes in pairs(self.layerZArray) do
		local layerCount = #layerNodes
		local deltaCount = (1 / layerCount);
		local deltaStep = (self.windowHeight * 0.5) * deltaCount;
		local topHeight = ((self.windowHeight * 0.5) - ( (layerCount / 2) * deltaStep ));
		for nodeIndex, node in ipairs( layerNodes ) do
			local nodeY = topHeight + (deltaStep * nodeIndex)
			local nodeX = layerNumber * self.widthSeparation
			node.setPosition( nodeX, nodeY );
		end
	end
end

--[[
	function TreeData:ShowTree()
		public void draw() {
			// Show connection lines
			stroke(255);
			fill(255);
			for (int i = 0; i < nodes.length; i++) {
				Node baseNode = nodes[i];
				for (String dependID : baseNode.depends) {
				Node dependedNode = IDToNode.get(dependID);
				// If node is null, then the depended node is not within this tree.
				if (dependedNode == null) {
					printOnce("[WARN] Depended ID has no node in the tree! " + baseNode.ID + " depending on " + dependID);
					continue;
				}
				// Create line to link the dependant ones
				noFill();
				bezierLine( baseNode.x, baseNode.y, dependedNode.x, dependedNode.y, widthSeparation);
				fill(255);
				}
			}
			// Show nodes
			for (int i = 0; i < nodes.length; i++) {
				nodes[i].show();
			}
		}
	end
]]

return { BaseNode = BaseNode, Node = Node, TreeData = TreeData }
