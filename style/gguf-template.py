import struct, sys
f = open(sys.argv[1], 'rb')
def rd(n):
    b = f.read(n)
    if len(b) != n: raise SystemExit('eof')
    return b
def u(fmt):
    return struct.unpack(fmt, rd(struct.calcsize(fmt)))[0]
def s():
    return rd(u('<Q')).decode('utf-8', 'replace')
T = {0:'B',1:'b',2:'H',3:'h',4:'I',5:'i',6:'f',7:'?',10:'Q',11:'q',12:'d'}
def kv(t):
    if t in T: return u('<'+T[t])
    if t == 8: return s()
    if t == 9:
        et, n = u('<I'), u('<Q')
        return [kv(et) for _ in range(n)]
    raise SystemExit(f'bad type {t}')
assert rd(4) == b'GGUF'
ver, ntensor, nkv = u('<I'), u('<Q'), u('<Q')
for _ in range(nkv):
    k = s(); t = u('<I'); v = kv(t)
    if k == 'tokenizer.chat_template':
        print(v)
