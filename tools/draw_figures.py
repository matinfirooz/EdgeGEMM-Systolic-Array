#!/usr/bin/env python3
"""Generate editable, implementation-specific SVGs; optionally render PNGs."""
import argparse
import shutil
import subprocess
from bisect import bisect_right
from html import escape
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/figures'
NAVY='#142c45'; TEAL='#087f82'; BLUE='#3566a5'; AMBER='#ad6b15'; GRAY='#5f7184'


class SVG:
    def __init__(self,w,h):
        self.parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">',
                    f'<rect width="{w}" height="{h}" fill="#ffffff"/>',
                    '<defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" fill="#52677b"/></marker></defs>']
    def rect(self,x,y,w,h,fill='#f3f7fa',stroke='#cbd6df',r=12):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>')
    def text(self,x,y,text,size=20,color=NAVY,weight='normal',anchor='start'):
        self.parts.append(f'<text x="{x}" y="{y}" font-family="DejaVu Sans,Arial,sans-serif" font-size="{size}" font-weight="{weight}" text-anchor="{anchor}" fill="{color}">{escape(str(text))}</text>')
    def line(self,points,color='#52677b',width=2.3,arrow=True,dash=False):
        p=' '.join(f'{x},{y}' for x,y in points)
        self.parts.append(f'<polyline points="{p}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round"'+(' marker-end="url(#arrow)"' if arrow else '')+(' stroke-dasharray="7 5"' if dash else '')+'/>')
    def box(self,x,y,w,h,title,lines=(),color=TEAL):
        self.rect(x,y,w,h,fill='#f7fafc')
        self.parts.append(f'<rect x="{x}" y="{y+13}" width="5" height="{h-26}" rx="2" fill="{color}"/>')
        self.text(x+20,y+34,title,min(21,(w-40)/max(1,len(title)*0.60)),color,'bold')
        for i,line in enumerate(lines): self.text(x+20,y+65+i*25,line,min(17,(w-40)/max(1,len(line)*0.55)),GRAY)
    def header(self,title,sub,w):
        self.text(48,56,title,34,NAVY,'bold');self.text(48,89,sub,18,GRAY)
        self.line([(48,110),(w-48,110)],color='#d5dfe7',width=1,arrow=False)
    def save(self,name):
        path=OUT/name;path.write_text('\n'.join(self.parts+['</svg>'])+'\n');return path


# Hardware views use conventional RTL symbols rather than annotated flow boxes.
from hardware_figures import architecture, pe_diagram, bank_diagram, quant_diagram

def schedule():
    s=SVG(1480,1010)
    s.header('Wavefront schedule | 4 × 4 tile, K = 4','Cycle t = r + c + k: matching operands meet at PE(r,c); colored cells show useful MACs',1480)
    x0,cell=265,105
    colors=['#e2f0f6','#d9efea','#faedcc','#e8e3f4']
    for t in range(10):s.text(x0+t*cell+cell/2,158,t,21,NAVY,'bold',anchor='middle')
    s.text(50,158,'Compute cycle',19,GRAY)
    for r in range(4):
        y=190+r*41;s.text(50,y+24,f'A row {r} / B col {r}',18,GRAY)
        for t in range(10):
            s.rect(x0+t*cell,y,cell-4,32,fill='#f6f8fa',stroke='#e0e7ed',r=4)
            if r<=t<r+4:
                k=t-r;s.rect(x0+t*cell,y,cell-4,32,fill=colors[k],stroke='none',r=4)
                s.text(x0+t*cell+cell/2,y+23,f'k = {k}',17,NAVY,anchor='middle')
    s.text(50,397,'Local accumulator activity',22,TEAL,'bold')
    for r in range(4):
        for c in range(4):
            y=420+(r*4+c)*28
            s.text(110,y+19,f'PE({r},{c})',16,GRAY)
            for t in range(10):
                s.rect(x0+t*cell,y,cell-4,23,fill='#f6f8fa',stroke='#e4ebf0',r=3)
                k=t-r-c
                if 0<=k<4:
                    s.rect(x0+t*cell,y,cell-4,23,fill=colors[k],stroke='none',r=3)
                    s.text(x0+t*cell+cell/2,y+17,f'k{k}',14,NAVY,anchor='middle')
    s.box(48,910,1384,65,'64 useful MACs · 16 physical PEs · 10 active compute cycles · 40% average PE utilization',(),TEAL)
    s.text(48,892,'Launch clear, snapshot capture, output handshakes and host programming are outside these 10 compute cycles.',17,GRAY)
    return s.save('schedule.svg')


def read_vcd(path):
    scopes=[];names={};events={};time=0;header=True
    for line in path.read_text().splitlines():
        words=line.split()
        if not words:continue
        if header:
            if words[0]=='$scope':scopes.append(words[2])
            elif words[0]=='$upscope':scopes.pop()
            elif words[0]=='$var':
                key='.'.join(scopes+[words[4]]);names[key]=words[3];events.setdefault(words[3],[])
            elif words[0]=='$enddefinitions':header=False
        elif line[0]=='#':time=int(line[1:])
        elif line[0] in '01xXzZ':events.setdefault(line[1:],[]).append((time,line[0]))
        elif line[0] in 'bB':
            value,code=line[1:].split();events.setdefault(code,[]).append((time,value))
    return names,events


def waveform(path):
    names,events=read_vcd(path)
    def data(key):return events[names['tb_edgegemm_core.'+key]]
    window=data('trace_window');start=next(t for t,v in window if v=='1')
    end=next(t for t,v in window if t>start and v=='0')+10000
    start-=10000
    s=SVG(1640,930)
    s.header('Verified transaction | bank 0, 4 × 4 tile, K = 9','Actual Icarus VCD trace: compute pauses and downstream backpressure preserve the wavefront and output payload',1640)
    x0,x1=245,1590
    def x(t):return x0+(t-start)/(end-start)*(x1-x0)
    for t in range(start,end+1,10000):
        xx=x(t);s.line([(xx,150),(xx,825)],color='#e8edf2',width=1,arrow=False)
        cyc=(t-start)//10000
        if cyc%5==0:s.text(xx,140,cyc,15,GRAY,anchor='middle')
    signals=['cmd_valid','cmd_ready','run_enable','busy','out_valid','out_ready','out_last','done','out_row','out_col','out_acc','perf_compute_cycles']
    for i,name in enumerate(signals):
        y=178+i*52;s.text(46,y+19,name,18,NAVY)
        seq=data(name);times=[t for t,_ in seq]
        before=max(0,bisect_right(times,start)-1)
        points=[(start,seq[before][1])]+[(t,v) for t,v in seq if start<t<end]+[(end,seq[-1][1])]
        # End value must reflect the window, not later transactions.
        points[-1]=(end,seq[max(0,bisect_right(times,end)-1)][1])
        if name in signals[:8]:
            pp=[];previous=None
            for t,v in points:
                yy=y if v=='1' else y+27
                if previous is not None:pp.append((x(t),previous))
                pp.append((x(t),yy));previous=yy
            s.line(pp,color=TEAL if name.startswith('out_') else BLUE,width=2,arrow=False)
        else:
            for (ta,va),(tb,_) in zip(points,points[1:]):
                if tb<=ta:continue
                xx,ww=x(ta),x(tb)-x(ta)
                s.rect(xx,y-2,ww,31,fill='#f0f7f7',stroke='#b8d5d3',r=2)
                if ww>26:
                    try:
                        value=int(va,2)
                        if name=='out_acc' and value>=1<<31:value-=1<<32
                        if len(str(value))*7.6+8<ww:s.text(xx+ww/2,y+20,value,13,TEAL,anchor='middle')
                    except ValueError:pass
    s.rect(48,855,1542,45,fill='#f3f7fa',stroke='none')
    s.text(65,884,'Time axis: 10 ns testbench cycles • Trace values are simulation evidence; the clock period is not a timing-closure claim.',17,GRAY)
    return s.save('waveform.svg')


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--png',action='store_true')
    ap.add_argument('--pdf',action='store_true')
    ap.add_argument('--waveform',type=Path)
    args=ap.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    paths=[architecture(),pe_diagram(),bank_diagram(),quant_diagram(),schedule()]
    if args.waveform:paths.append(waveform(args.waveform))
    elif (OUT/'waveform.svg').exists():paths.append(OUT/'waveform.svg')
    if args.png or args.pdf:
        inkscape=shutil.which('inkscape')
        if inkscape:
            for p in paths:
                for ext in (['png'] if args.png else [])+(['pdf'] if args.pdf else []):
                    cmd=[inkscape,str(p),'--export-type='+ext,'--export-filename='+str(p.with_suffix('.'+ext))]
                    if ext=='png':cmd+=['--export-dpi=120']
                    subprocess.run(cmd,check=True,capture_output=True,text=True,timeout=60)
        else:
            import cairosvg
            for p in paths:
                if args.png:cairosvg.svg2png(url=str(p),write_to=str(p.with_suffix('.png')))
                if args.pdf:cairosvg.svg2pdf(url=str(p),write_to=str(p.with_suffix('.pdf')))
    for p in paths:print(p.relative_to(ROOT))


if __name__=='__main__':main()
