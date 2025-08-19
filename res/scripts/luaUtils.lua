-------------------------------------------------------------
---------------------- Util Functions ----------------------
-------------------------------------------------------------

local luaUtils = {}

-- Get the median of a table.
function luaUtils.median( t )
  local temp={}

  -- deep copy table so that when we sort it, the original is unchanged
  -- also weed out any non numbers
  for k,v in pairs(t) do
    if type(v) == 'number' then
      table.insert( temp, v )
    end
  end

  table.sort( temp )

  -- If we have an even number of table elements or odd.
  if math.fmod(#temp,2) == 0 then
    -- return mean value of middle two elements
    return ( temp[#temp/2] + temp[(#temp/2)+1] ) / 2
  else
    -- return middle element
    return temp[math.ceil(#temp/2)]
  end
end


---@param a table
---@param b table
-- returns Array, the intersect of a and b
function luaUtils.intersect(a,b)
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

    return luaUtils.distinctArr(intersectVals)
end

---@param arr table
-- Removes Duplicate elements https://stackoverflow.com/questions/20066835/lua-remove-duplicate-elements
function  luaUtils.distinctArr(arr)
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
function luaUtils.getKeysAsSortedTable(tab)
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
function luaUtils.sortByValues(tab)
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
function luaUtils.createOneBasedArray(count, defaultVal)
    local arr={}
    for i=1,count do
        arr[i]=defaultVal
    end
    return arr
end

---@param count number
-- returns a index one based array with empty tables
function luaUtils.createOneBasedArrayTable(count)
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
function luaUtils.createOneBasedArrayOfArrays(n,m, defaultVal)
    local matrix={}
    for i=1,n do
        matrix[i]={}
        for j=1,m do
            matrix[i][j] = defaultVal
        end
    end
    return matrix
end

---@param time number
-- returns Number, time in seconds
function luaUtils.getTimeInSecs(time)
    if time then
        time = math.floor(time/ 1000)
        return time
    else
        return 0
    end
end


---@param time number
-- returns Formated time string
function luaUtils.getTimeStr(time)
    if not(type(time) == "number") then return "ERROR" end

    local timeStr = os.date('%M:%S', time)
    if(time == 0) then
        timeStr = "--:--"
    elseif time > 60 * 60 then
        timeStr = "Long"
    end
    return timeStr
end


---@param num number
---@param denom number
---Returns 0 if denominator is 0, the num/denom otherwise
function luaUtils.safeDivide(num, denom)
    if denom == 0 then
        return 0
    else
        return num / denom
    end
end

---@param arr table
-- returns the avearge of non zero values
function luaUtils.avgNonZeroValuesInArray(arr)
    local total = 0
    local count = 0
    for k,_ in pairs(arr) do
        if (arr[k] > 0) then
            total = total + arr[k]
            count = count + 1
        end
    end
    return luaUtils.safeDivide(total, count)
end


---https://stackoverflow.com/questions/9168058/how-to-dump-a-table-to-console
---@param o any
---@return string
function luaUtils.dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. luaUtils.dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end

-- https://stackoverflow.com/questions/2705793/how-to-get-number-of-entries-in-a-lua-table
function luaUtils.tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function luaUtils.tableHasKey(table,key)
    return table[key] ~= nil
end

-- Returns the maximum element of the array. Taken from Timetables Mod
---@param arr table
-- returns a, the maximum element of the array. 0 otherwise
function luaUtils.maximumArray(arr)
    if not arr or not arr[1] then return 0 end

    local max = arr[1]
    for k,_ in pairs(arr) do
        if arr[k] then
            if max < arr[k] then
                max = arr[k]
            end
        end
    end
    return max
end

function luaUtils.shortenName(str, maxLength)
    local shortened = str
    if #shortened > maxLength then
        shortened = string.sub(shortened, 1, maxLength-3) .. "..."
    end
    return shortened
end

function luaUtils.shortenToPixels(str, pixels)
    local maxLength = math.floor(pixels/7) -2
    return luaUtils.shortenName(str, maxLength)
end

-- Orders For table:setOrder method. Inspired by Timetables Mod
---@param arr [table] an array to sort
---@param sortFn function sorting function
---@return [number] --an Array where the index it the source element and the number is the target position
function luaUtils.getOrderOfArray(arr, sortFn)
    local toSort = {}
    for k,v in pairs(arr) do
        toSort[k] = {key =  k, value = v}
    end

    table.sort(toSort, sortFn)

    local res = {}
    for k,v in pairs(toSort) do
        res[k-1] = v.key-1
    end

    return res
end

return luaUtils

