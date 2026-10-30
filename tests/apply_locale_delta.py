import subprocess, re, sys
REPO="/home/user/Clara-Combo-Points"
def show(repo, rev, path="ClaraComboPoints/Locales.lua"):
    return subprocess.run(["git","-C",repo,"show",f"{rev}:{path}"],capture_output=True,text=True,check=True).stdout.split("\n")
KEY=re.compile(r"^\s+([A-Z][A-Z0-9_]*)\s*=")
def index(lines):
    occ={}; idx={}
    for i,l in enumerate(lines):
        m=KEY.match(l)
        if m:
            k=m.group(1); n=occ.get(k,0); occ[k]=n+1; idx[(k,n)]=i
    return idx
old=show(REPO, sys.argv[1]); new=show(REPO, sys.argv[2])
target_path=sys.argv[3]; base=open(target_path).read().split("\n") if len(sys.argv)<5 else show(sys.argv[4], "HEAD")
oi, ni = index(old), index(new)
mod={k:new[i] for k,i in ni.items() if k in oi and old[oi[k]]!=new[i]}
rem=[k for k in oi if k not in ni]
add=[k for k in ni if k not in oi]
# non-key line changes: report
okeys=set(oi.values()); nkeys=set(ni.values())
print("modified",len(mod),"removed",len(rem),"added",len(add))
bi=index(base)
out=list(base)
for k,l in mod.items():
    if k in bi: out[bi[k]]=l
dele=set(bi[k] for k in rem if k in bi)
# additions: after the previous key (in new) present in base
ins={}
for k in add:
    i=ni[k]; j=i-1
    while j>=0 and not KEY.match(new[j]): j-=1
    prev=None
    while j>=0:
        m=KEY.match(new[j])
        if m:
            # find occurrence index of new[j]
            pk=[kk for kk,ii in ni.items() if ii==j][0]
            if pk in bi: prev=pk; break
        j-=1
    if prev is None: print("NO ANCHOR for",k); continue
    ins.setdefault(bi[prev],[]).append(new[i])
res=[]
for i,l in enumerate(out):
    if i in dele: continue
    res.append(l)
    for x in ins.get(i,[]): res.append(x)
open(target_path,"w").write("\n".join(res))
print("applied: mod",sum(1 for k in mod if k in bi),"del",len(dele),"add",sum(len(v) for v in ins.values()))
