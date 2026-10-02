-- sql_lib_test.lua: real SQLite-backed sql library contract (both realms).
-- Server opens <gamedir>/sv.db, client opens <gamedir>/cl.db.
-- Run: lua_dofile sql_lib_test.lua  /  lua_dofile_cl sql_lib_test.lua
-- Idempotent: IF NOT EXISTS / INSERT OR REPLACE everywhere.

local nTests, nFailed = 0, 0
local function Check( bCond, sName )
	nTests = nTests + 1
	if ( !bCond ) then
		nFailed = nFailed + 1
		print( "[sql_lib_test] FAIL: " .. sName )
	end
end

-- shape: C core + GMod's Lua shell (includes/util/sql.lua)
Check( type( sql ) == "table", "sql table" )
Check( type( sql.Query ) == "function", "sql.Query (C)" )
Check( type( sql.QueryTyped ) == "function", "sql.QueryTyped (C)" )
Check( type( sql.SQLStr ) == "function", "sql.SQLStr (lua shell)" )
Check( type( SQLStr ) == "function", "global SQLStr alias" )
Check( type( sql.LastError ) == "function", "sql.LastError" )
Check( sql.IsStub == nil, "stub marker gone" )

-- empty query -> false + LastError "No Query"
Check( sql.Query( "" ) == false, "empty query -> false" )
Check( sql.LastError() == "No Query", "LastError == No Query" )

-- create / TableExists
Check( sql.Query( "CREATE TABLE IF NOT EXISTS sql_test_t (id INTEGER PRIMARY KEY, name TEXT, score INTEGER)" ) == nil, "create ok -> nil (no rows)" )
Check( sql.TableExists( "sql_test_t" ) == true, "TableExists true" )
Check( sql.TableExists( "sql_test_missing" ) == false, "TableExists false" )

-- insert + quote escaping + all-string values
sql.Query( "INSERT OR REPLACE INTO sql_test_t VALUES (1, " .. SQLStr( "it's" ) .. ", 95)" )
sql.Query( "INSERT OR REPLACE INTO sql_test_t VALUES (2, NULL, 3)" )
local r = sql.Query( "SELECT * FROM sql_test_t WHERE id = 1" )
Check( type( r ) == "table" and #r == 1, "select one row" )
Check( r[1].name == "it's", "quote escape roundtrip" )
Check( r[1].score == "95", "Query values are strings" )
Check( r[1].id == "1", "even the rowid comes back as a string" )

-- NULL -> literal "NULL" string in Query
local r2 = sql.Query( "SELECT name FROM sql_test_t WHERE id = 2" )
Check( r2[1].name == "NULL", "NULL becomes 'NULL' string" )

-- error path
Check( sql.Query( "SELEC nonsense" ) == false, "bad SQL -> false" )
Check( type( sql.LastError() ) == "string" and sql.LastError() != "No Query", "LastError populated" )

-- no rows -> nil (GMod three-state contract)
Check( sql.Query( "SELECT * FROM sql_test_t WHERE id = 999" ) == nil, "no rows -> nil" )

-- multi-statement: rows of all statements land in one table
local rm = sql.Query( "SELECT score FROM sql_test_t WHERE id = 1; SELECT score FROM sql_test_t WHERE id = 2" )
Check( type( rm ) == "table" and #rm == 2, "multi-statement rows concatenated" )

-- DEFENSIVE mode: schema tables are not writable
Check( sql.Query( "DELETE FROM sqlite_master" ) == false, "DEFENSIVE blocks sqlite_master writes" )

-- QueryTyped: binding + typed values
local rt = sql.QueryTyped( "SELECT id, name, score FROM sql_test_t WHERE id = ?", 1 )
Check( type( rt ) == "table" and #rt == 1, "QueryTyped binding row" )
Check( rt[1].id == 1, "INTEGER typed as number" )
Check( rt[1].score == 95, "score typed as number" )
Check( rt[1].name == "it's", "TEXT typed as string" )
local rt2 = sql.QueryTyped( "SELECT name FROM sql_test_t WHERE id = ?", 2 )
Check( rt2[1].name == nil, "NULL absent in QueryTyped row" )
local rt0 = sql.QueryTyped( "SELECT id FROM sql_test_t WHERE id = ?", 999 )
Check( type( rt0 ) == "table" and #rt0 == 0, "QueryTyped no rows -> EMPTY table" )
Check( sql.QueryTyped( "SELECT * FROM sql_test_t WHERE id = ?" ) == false, "wrong param count -> false" )
Check( sql.LastError() == "incorrect number of parameters provided", "param count message" )
Check( sql.QueryTyped( "SELECT * FROM sql_test_t WHERE id = ?", {} ) == false, "unsupported param -> false" )
local rtn = sql.QueryTyped( "SELECT id FROM sql_test_t WHERE name = ?", nil )
Check( type( rtn ) == "table", "nil binds as NULL without error" )

-- bool/boolean column quirk + big integer beyond double precision
sql.Query( "CREATE TABLE IF NOT EXISTS sql_test_b (flag BOOLEAN, val INTEGER)" )
sql.Query( "INSERT OR REPLACE INTO sql_test_b VALUES (1, 9007199254740993)" )
local rb = sql.QueryTyped( "SELECT flag, val FROM sql_test_b" )
Check( rb[1].flag == true, "bool/boolean column -> boolean" )
Check( rb[1].val == "9007199254740993", "big int beyond double -> string" )

-- QueryRow / QueryValue / IndexExists / Begin-Commit
Check( sql.QueryRow( "SELECT * FROM sql_test_t WHERE id = 1" ).name == "it's", "QueryRow" )
Check( sql.QueryRow( "SELECT * FROM sql_test_t WHERE id = 999" ) == nil, "QueryRow empty -> nil" )
Check( sql.QueryValue( "SELECT COUNT(*) FROM sql_test_t" ) == "3", "QueryValue returns string" )
sql.Query( "DROP INDEX IF EXISTS idx_sql_test" )
sql.Query( "CREATE INDEX idx_sql_test ON sql_test_t(score)" )
Check( sql.IndexExists( "idx_sql_test" ) == true, "IndexExists" )
sql.Begin()
sql.Query( "INSERT OR REPLACE INTO sql_test_t VALUES (3, 'batch', 1)" )
sql.Commit()
Check( sql.QueryValue( "SELECT COUNT(*) FROM sql_test_t" ) == "3", "Begin/Commit batch" )

print( string.format( "[sql_lib_test] %d checks, %d failed", nTests, nFailed ) )
if ( nFailed == 0 ) then
	print( "[sql_lib_test] PASSED" )
end
