-------------------------------------------------------------
---------------------- Util Functions ----------------------
-------------------------------------------------------------

local lineStatsUtils = {}


---@param a table
---@param b table
-- returns Array, the intersect of a and b
function lineStatsUtils.intersect(a,b)
    local intersectVals = {}

    if a == nil then return {} end
    if b == nil then return {} end

    for _, av in pairs(a) do 
        for _, bv in pairs(b) do 
            if av == bv then
                table.insert(intersectVals, av)
            end
        end
	end

    return lineStatsUtils.distinctArr(intersectVals)
end

---@param arr table
-- Removes Duplicate elements https://stackoverflow.com/questions/20066835/lua-remove-duplicate-elements
function  lineStatsUtils.distinctArr(arr)
    
    if arr == nil then return {} end

    local hash = {}
    local res = {}

    for _,v in ipairs(arr) do
        if (not hash[v]) then
            res[#res+1] = v
            hash[v] = true
        end
    end

    return res
end

---@param tab table
-- returns the sorted keys of the table
-- https://www.lua.org/pil/19.3.html
function lineStatsUtils.getKeysAsSortedTable(tab)
	local keys = {} 
	for k, v in pairs(tab) do 
		table.insert(keys,k)
	end
	table.sort(keys)
	return keys
end

---@param tab table
-- returns the table sorted by values
-- https://www.lua.org/pil/19.3.html
function lineStatsUtils.sortByValues(tab)
    local entities = {}
 
    for key, value in pairs(tab) do
        table.insert(entities, {key = key, value = value})
    end
     
    table.sort(entities, function(a, b) return a.value < b.value end)

    return entities
end


---@param count number
---@param defaultVal number | string | any
-- returns a index one based array with all values set to defaultVal
function lineStatsUtils.createOneBasedArray(count, defaultVal)
    local arr={}
    for i=1,count do
        arr[i]=defaultVal
    end
    return arr
end

---@param count number
-- returns a index one based array with empty tables
function lineStatsUtils.createOneBasedArrayTable(count)
    local arr={}
    for i=1,count do
        arr[i]={}
    end
    return arr
end

---@param n number
---@param m number
---@param defaultVal number | string | any
-- returns a Matrices/Multi-Dimensional Array. See https://www.lua.org/pil/11.2.html
function lineStatsUtils.createOneBasedArrayOfArrays(n,m, defaultVal)
    local matrix={}
    for i=1,n do
        matrix[i]={}
        for j=1,m do
            matrix[i][j] = defaultVal
        end
    end
    return matrix
end

-- returns Number, current GameTime in seconds
function lineStatsUtils.getTime()
    local gameTimeComp = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
    local time = gameTimeComp.gameTime
    return lineStatsUtils.getTimeInSecs(time)
end

---@param time number
-- returns Number, time in seconds
function lineStatsUtils.getTimeInSecs(time)
    if time then
        time = math.floor(time/ 1000)
        return time
    else
        return 0
    end
end


---@param time number
-- returns Formated time string
function lineStatsUtils.getTimeStr(time)
    if not(type(time) == "number") then return "ERROR" end 

    local timeStr = os.date('%M:%S', time)
    if(time == 0) then
        timeStr = "--:--"
    end
    return timeStr
end


---@param num number
---@param denom number
---Returns 0 if denominator is 0, the num/denom otherwise
function lineStatsUtils.safeDivide(num, denom)
    if denom == 0 then
        return 0
    else
        return num / denom
    end
end

---@param arr table
-- returns the avearge of non zero values
function lineStatsUtils.avgNonZeroValuesInArray(arr)
    local total = 0
    local count = 0
    for k,_ in pairs(arr) do
        if (arr[k] > 0) then
            total = total + arr[k]
            count = count + 1
        end
    end
    return lineStatsUtils.safeDivide(total, count)
end


---https://stackoverflow.com/questions/9168058/how-to-dump-a-table-to-console
---@param o any
---@return string
function lineStatsUtils.dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. lineStatsUtils.dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end

-- https://stackoverflow.com/questions/2705793/how-to-get-number-of-entries-in-a-lua-table
function lineStatsUtils.tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function lineStatsUtils.tableHasKey(table,key)
    return table[key] ~= nil
end

return lineStatsUtils