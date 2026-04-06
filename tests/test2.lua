--%%save:foo.fqa
local a = {c = [[A
B
C
D
E]]}
local b = json.encode(a)
print(b)
