-- HL2SB string.lua 验证脚本 (game/client)
-- 用法: lua_dofile_cl game/client/hl2sb_strtest.lua
print("[strtest] -- string.lua 验证开始 --")

-- 1. continue 关键字(引擎级)
do
	local s = {}
	for i = 1,10 do
		if i % 3 == 0 then continue end
		s[#s+1] = i
	end
	print("[strtest] continue 跳过3的倍数: " .. table.concat(s, ","))
end

-- 2. string.Explode
print("[strtest] Explode 'a b c'[2] = " .. tostring(string.Explode(" ", "a b c")[2]))

-- 3. string.NiceName (内含 continue)
print("[strtest] NiceName('my_model_name') = " .. string.NiceName("my_model_name"))
print("[strtest] NiceName('army_general_elite') = " .. string.NiceName("army_general_elite"))

-- 4. string.Split / Replace / Trim / StartsWith / EndsWith
print("[strtest] Split('a-b-c','-')[2] = " .. tostring(string.Split("a-b-c","-")[2]))
print("[strtest] Replace('aXbXc','X','-') = " .. string.Replace("aXbXc","X","-"))
print("[strtest] Trim('  hi  ') = '" .. string.Trim("  hi  ") .. "'")
print("[strtest] StartsWith('hello','he') = " .. tostring(string.StartsWith("hello","he")))
print("[strtest] EndsWith('hello','lo') = " .. tostring(string.EndsWith("hello","lo")))

-- 5. ! 运算符 (引擎级)
local x = 5
print("[strtest] !(x==5) = " .. tostring(!(x == 5)))
print("[strtest] !false = " .. tostring(!false))

-- 6. str[i] 数字索引 (string metatable __index)
print("[strtest] ('hello')[2] = " .. tostring(("hello")[2]))

print("[strtest] -- string.lua 验证结束 --")
