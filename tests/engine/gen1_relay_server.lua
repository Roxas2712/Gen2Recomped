local ok,why,code=os.execute('python3 tests/gen1_session_relay_test.py')
assert(ok==true and(code==nil or code==0)or ok==0,'serial relay socket/SQLite test failed: '..tostring(why)..' '..tostring(code))
print('Gen1 session relay socket and crash recovery tests passed')
