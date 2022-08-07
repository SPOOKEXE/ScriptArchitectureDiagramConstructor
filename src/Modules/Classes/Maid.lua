
local cleanupMethods = {
	['Instance'] = function(Task)
		Task:Destroy()
	end,
	['RBXConnection'] = function(Task)
		Task:Disconnect()
	end,
	['table'] = function(Task)
		if typeof(Task.Destroy) == 'function' then
			Task:Destroy()
		end
	end
}

-- // Class // --
local Class = {}
Class.__index = Class

function Class.New()
	return setmetatable({ _tasks = {} }, Class)
end

function Class:Give(...)
	for _, Task in ipairs( {...} ) do
		if cleanupMethods[typeof(Task)] and (not table.find(self._tasks, Task)) then
			table.insert(self._tasks, Task)
		end
	end
end

function Class:Cleanup()
	for _, Task in ipairs( self._tasks ) do
		local taskType = typeof(Task)
		local func = cleanupMethods[taskType]
		if func then
			task.defer(func, Task)
		else
			warn('Could not find cleanup function for type; ', taskType)
		end
	end
end

return Class