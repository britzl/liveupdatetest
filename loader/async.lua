local M = {}

local NOT_STARTED = "not_started"
local YIELDED = "yielded"
local RESUMED = "resumed"
local RUNNING = "running"

function M.async(fn)
	local co = coroutine.create(fn)

	local state = NOT_STARTED

	local result = nil

	local function await(fn, ...)
		state = RUNNING
		result = nil
		fn(...)
		if state ~= RESUMED then
			state = YIELDED
			result = { coroutine.yield() }
		end
		return unpack(result)
	end
	
	local function resume(...)
		if state == YIELDED or state == NOT_STARTED then
			state = (state == YIELDED) and RESUMED or RUNNING
			local ok, err = coroutine.resume(co, ...)
			if not ok then
				print(err)
				print(debug.traceback())
			end
		else
			state = RESUMED
			result = {...}
		end
	end

	return resume(await, resume)
end


return setmetatable(M, {
	__call = function(t, ...)
		return M.async(...)
	end
})