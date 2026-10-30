import struct, sys
for p in sys.argv[1:]:
    d = open(p, 'rb').read()
    ver = d[:4]
    if ver not in (b'\x00\x01\x00\x00', b'true', b'OTTO'):
        print('NOT A FONT', p, ver); continue
    n = struct.unpack('>H', d[4:6])[0]
    tags = [d[12+16*i:16+16*i].decode('latin1') for i in range(n)]
    # family name from name table
    name = ''
    if 'name' in tags:
        i = tags.index('name'); off = struct.unpack('>I', d[12+16*i+8:12+16*i+12])[0]
        fmt, cnt, so = struct.unpack('>HHH', d[off:off+6])
        for k in range(cnt):
            pid, eid, lid, nid, ln, o = struct.unpack('>HHHHHH', d[off+6+12*k:off+18+12*k])
            if nid == 4 and pid == 3:
                name = d[off+so+o:off+so+o+ln].decode('utf-16-be', 'replace'); break
    print(p.split('/')[-1], ver, 'glyf' in tags, 'fvar' in tags, repr(name))
