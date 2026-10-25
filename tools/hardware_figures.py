#!/usr/bin/env python3
"""Editable hardware schematics, drawn from EdgeGEMM's actual RTL boundaries."""
from html import escape
from pathlib import Path

OUT=Path(__file__).resolve().parents[1]/'docs/figures'
INK='#162b3b'; DATA='#087c77'; BDATA='#285d9f'; CTRL='#9b641b'
GRAY='#61717d'; PALE='#f0f6f8'; LIGHT='#c9d4db'; PURPLE='#74519b'


class Schematic:
    def __init__(self,w,h,title,subtitle):
        self.w,self.h=w,h
        self._text_id=0
        self.p=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">',
                f'<rect width="{w}" height="{h}" fill="white"/>']
        self.text(44,49,title,31,bold=True)
        self.text(44,82,subtitle,18,color=GRAY)
        self.wire([(44,104),(w-44,104)],color=LIGHT,width=1,arrow=False)
    def text(self,x,y,t,size=18,color=INK,bold=False,anchor='start',mono=False):
        family='DejaVu Sans Mono,monospace' if mono else 'DejaVu Sans,Arial,sans-serif'
        self._text_id+=1
        self.p.append(f'<text id="t{self._text_id}" x="{x}" y="{y}" font-family="{family}" font-size="{size}" font-weight="{"bold" if bold else "normal"}" fill="{color}" text-anchor="{anchor}">{escape(str(t))}</text>')
    def rect(self,x,y,w,h,fill='white',stroke=INK,width=1.8,dash=False):
        self.p.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"'+(' stroke-dasharray="8 6"' if dash else '')+'/>')
    def polygon(self,pts,fill='white',stroke=INK,width=1.8):
        p=' '.join(f'{x},{y}' for x,y in pts)
        self.p.append(f'<polygon points="{p}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>')
    def wire(self,pts,color=DATA,width=2.6,arrow=True,dash=False):
        p=' '.join(f'{x},{y}' for x,y in pts)
        self.p.append(f'<polyline points="{p}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="miter"'+(' stroke-dasharray="6 5"' if dash else '')+'/>')
        if arrow and len(pts)>1:
            x,y=pts[-1];a,b=pts[-2];dx,dy=x-a,y-b
            if abs(dx)>=abs(dy):
                sign=1 if dx>=0 else -1;tri=[(x,y),(x-9*sign,y-4),(x-9*sign,y+4)]
            else:
                sign=1 if dy>=0 else -1;tri=[(x,y),(x-4,y-9*sign),(x+4,y-9*sign)]
            self.polygon(tri,fill=color,stroke=color,width=.5)
    def ctrl(self,pts,arrow=True):self.wire(pts,color=CTRL,width=1.6,arrow=arrow,dash=True)
    def dot(self,x,y,color=DATA):self.p.append(f'<circle cx="{x}" cy="{y}" r="3.8" fill="{color}"/>')
    def bus(self,x,y,label,color=DATA,side='top'):
        self.wire([(x-5,y+7),(x+5,y-7)],color=color,width=1.5,arrow=False)
        self.text(x,y-13 if side=='top' else y+26,label,15,color=color,anchor='middle')
    def op(self,x,y,symbol,r=35,color=DATA):
        self.p.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="white" stroke="{color}" stroke-width="2.2"/>')
        fs=min(34,r*1.3)
        self.text(x,y+fs*.34,symbol,fs,color=color,anchor='middle')
    def comb(self,x,y,w,h,label,sub=None,color=DATA):
        self.rect(x,y,w,h,fill='#f7fbfc',stroke=color)
        self.text(x+w/2,y+h/2+(4 if sub else 7),label,min(23,(w-18)/max(1,len(label)*.60)),color=color,bold=True,anchor='middle')
        if sub:self.text(x+w/2,y+h-13,sub,15,color=GRAY,anchor='middle')
    def ff(self,x,y,w,h,label,bits=None,color=DATA):
        self.rect(x,y,w,h,fill='#f1f7f8',stroke=color)
        self.text(x+13,y+h/2+6,'D',15,color=GRAY)
        self.text(x+w-13,y+h/2+6,'Q',15,color=GRAY,anchor='end')
        self.text(x+w/2,y+h/2-7,label,min(20,(w-50)/max(1,len(label)*.57)),color=color,bold=True,anchor='middle')
        if bits:self.text(x+w/2,y+h/2+16,bits,14,color=GRAY,anchor='middle')
        self.polygon([(x+18,y+h),(x+18,y+h-13),(x+31,y+h-6.5)],stroke=color,width=1.4)
    def mux_right(self,x,y,w=55,h=110,label='MUX',color=DATA):
        self.polygon([(x,y),(x+w,y+18),(x+w,y+h-18),(x,y+h)],fill='#f1f7f8',stroke=color)
        self.text(x+w/2,y+h/2+5,label,13,color=color,anchor='middle')
        return (x,y+h*.25),(x,y+h*.75),(x+w,y+h*.5),(x+w*.5,y+h-9)
    def mux_down(self,x,y,w=110,h=60,color=DATA):
        self.polygon([(x,y),(x+w,y),(x+w-20,y+h),(x+20,y+h)],fill='#f1f7f8',stroke=color)
        self.text(x+w/2,y+h/2+6,'MUX',14,color=color,anchor='middle')
        return (x+w*.25,y),(x+w*.75,y),(x+w*.5,y+h)
    def net(self,x,y,label,color=CTRL,anchor='start'):
        self.text(x,y,label,16,color=color,anchor=anchor)
    def footer(self,lines):
        y=self.h-63 if len(lines)==1 else self.h-81
        self.wire([(44,y-18),(self.w-44,y-18)],color=LIGHT,width=1,arrow=False)
        for i,line in enumerate(lines):self.text(44,y+9+i*25,line,17,color=GRAY)
    def save(self,name):
        OUT.mkdir(parents=True,exist_ok=True);p=OUT/name
        p.write_text('\n'.join(self.p+['</svg>'])+'\n');return p


def memory(s,x,y,w,h,name,dim,color=DATA):
    s.rect(x,y,w,h,fill='white',stroke=color)
    s.text(x+w/2,y+28,name,20,color=color,bold=True,anchor='middle')
    gy=y+42;gh=h-73
    for r in range(4):
        for c in range(5):
            s.rect(x+12+c*(w-24)/5,gy+r*gh/4,(w-24)/5,gh/4,fill='#f1f7f8',stroke='#b4c6cd',width=.7)
    s.text(x+w/2,y+h-11,dim,15,color=GRAY,anchor='middle')


def tiny_pe(s,x,y,r,c):
    s.rect(x,y,108,88,fill='white',stroke=INK)
    s.text(x+54,y+20,f'PE{r}{c}',15,bold=True,anchor='middle')
    s.op(x+34,y+43,'×',r=13,color=DATA)
    s.op(x+76,y+43,'+',r=13,color=DATA)
    s.wire([(x+47,y+43),(x+63,y+43)],width=1.3)
    s.rect(x+24,y+63,62,17,fill=PALE,stroke=DATA,width=1)
    s.text(x+55,y+76,'ACC',11,color=DATA,anchor='middle')
    s.wire([(x+76,y+56),(x+76,y+63)],width=1,arrow=False)


def architecture():
    s=Schematic(1800,1400,'EdgeGEMM — hardware architecture','4 × 4 instance shown · D = DATA_W (4 or 8) · W = ACC_W (32 default) · clock/reset distributed to all registers')
    # Controller contains state registers; the skew unit drives addresses, not stored data.
    s.text(510,133,'u_control + bank ownership',19,bold=True)
    s.rect(485,150,635,110,stroke=CTRL)
    s.ff(505,173,145,64,'M,N,K','shape',CTRL)
    s.ff(670,173,200,64,'step','32',CTRL)
    s.ff(890,173,210,64,'active_bank','1',CTRL)
    s.wire([(1035,135),(1035,150)],color=CTRL,width=1.8);s.text(985,133,'cmd_*',17,color=CTRL)
    s.net(970,284,'clear, compute_en');s.ctrl([(994,260),(994,302)])
    s.text(60,133,'Host operand writes',18,bold=True)
    s.comb(60,150,190,85,'Write decode','bank · A/B · lane · k',CTRL)
    s.ctrl([(250,175),(340,175)]);s.net(263,163,'wr_A')
    s.ctrl([(250,215),(340,215)]);s.net(263,243,'wr_B')
    s.comb(60,310,360,125,'skew_injector','k_r = step − r;  k_c = step − c',CTRL)
    s.ctrl([(770,260),(770,286),(240,286),(240,310)])
    s.net(444,278,'step[31:0], M,N,K')
    s.net(80,460,'rd_index + lane valid')
    # A banks and the selected 4-lane bus.
    memory(s,60,545,185,140,'A bank 0','4 × K_MAX × D')
    memory(s,60,830,185,140,'A bank 1','4 × K_MAX × D')
    s.net(60,530,'wr_A',anchor='start');s.net(60,815,'wr_A',anchor='start')
    s.ctrl([(150,435),(150,490),(30,490),(30,900),(60,900)])
    s.ctrl([(30,615),(60,615)]);s.dot(30,615,CTRL)
    a0,a1,ao,asel=s.mux_right(315,680,58,130)
    s.wire([(245,615),(280,615),(280,a0[1]),a0])
    s.wire([(245,900),(280,900),(280,a1[1]),a1])
    s.ctrl([(344,830),asel]);s.net(344,855,'active_bank',anchor='middle')
    s.wire([ao,(450,745)],width=4);s.bus(410,745,'4D')
    s.rect(450,555,30,600,fill='#e9f2f3',stroke=DATA)
    s.text(459,590,'A',17,color=DATA)
    # B banks. Both banks are read asynchronously before bank selection.
    memory(s,585,335,210,130,'B bank 0','4 × K_MAX × D',BDATA)
    memory(s,955,335,210,130,'B bank 1','4 × K_MAX × D',BDATA)
    s.net(585,324,'wr_B');s.net(955,324,'wr_B')
    s.ctrl([(420,370),(500,370),(500,308),(1060,308),(1060,335)])
    s.ctrl([(690,308),(690,335)]);s.dot(690,308,CTRL)
    b0,b1,bo=s.mux_down(815,490,120,60,BDATA)
    s.wire([(690,465),(690,480),(b0[0],480),b0],color=BDATA,width=3)
    s.wire([(1060,465),(1060,480),(b1[0],480),b1],color=BDATA,width=3)
    s.ctrl([(1000,520),(930,520)]);s.net(1000,509,'active_bank')
    s.wire([bo,(875,575)],color=BDATA,width=4);s.bus(875,560,'',BDATA);s.text(909,571,'4D',15,color=BDATA)
    s.rect(575,575,625,25,fill='#edf2f9',stroke=BDATA)
    s.text(600,567,'B lane unpack + valid',16,color=BDATA)
    s.text(428,1040,'A lane',14,color=DATA,anchor='end');s.text(428,1061,'unpack',14,color=DATA,anchor='end')
    # Physical PE mesh: horizontal A tokens, vertical B tokens, local ACC in each PE.
    s.rect(550,615,650,565,fill='none',stroke='#8b9ca5',dash=True)
    s.text(580,641,'u_mesh · N × N output-stationary array',18,bold=True)
    for r in range(4):
        for c in range(4):
            xx,yy=580+c*155,670+r*130
            tiny_pe(s,xx,yy,r,c)
            if c<3:s.wire([(xx+108,yy+44),(xx+155,yy+44)],width=2)
            if r<3:s.wire([(xx+54,yy+88),(xx+54,yy+130)],color=BDATA,width=2)
        yy=670+r*130+44
        s.wire([(480,yy),(580,yy)],width=2.5);s.text(500,yy-10,f'A{r},v{r}',14,color=DATA)
    for c in range(4):
        xx=634+c*155
        s.wire([(xx,600),(xx,670)],color=BDATA,width=2.5)
        s.text(xx+9,660,f'B{c}',14,color=BDATA)
    s.net(60,1009,'valid[r/c] comes from skew masks')
    # C capture is a parallel register snapshot, not a serial row drain from each PE.
    s.ff(1300,595,360,120,'Result snapshot','N² × W',PURPLE)
    s.wire([(1200,860),(1250,860),(1250,655),(1300,655)],color=PURPLE,width=4)
    s.bus(1250,780,'N²W',PURPLE)
    s.net(1350,575,'capture = compute_done')
    s.ctrl([(1480,558),(1480,595)])
    s.wire([(1480,715),(1480,790)],color=PURPLE,width=4);s.bus(1480,759,'N²W',PURPLE)
    s.mux_down(1425,790,110,65,PURPLE)
    s.wire([(1480,855),(1480,894),(1750,894)],color=PURPLE,width=3)
    s.bus(1600,894,'W',PURPLE);s.text(1748,881,'out_acc',18,color=PURPLE,anchor='end')
    s.dot(1480,894,PURPLE)
    s.wire([(1480,894),(1480,965)],color=PURPLE,width=3)
    s.text(1300,950,'affine_requantize',18,bold=True)
    s.rect(1300,965,360,83,stroke=DATA)
    for xx,label in [(1345,'×'),(1470,'≫'),(1595,'SAT')]:
        s.text(xx,1015,label,27,color=DATA,bold=True,anchor='middle')
    s.wire([(1370,1004),(1430,1004)],width=1.6)
    s.wire([(1500,1004),(1550,1004)],width=1.6)
    s.wire([(1660,1006),(1750,1006)],width=3);s.bus(1700,1006,'OUT_W')
    s.text(1748,975,'out_quant',16,color=DATA,anchor='end')
    # Quantization storage and output selection/handshake controls.
    memory(s,1370,155,300,125,'Q-config banks','2 × N × (W+16+6+OUT_W+2)',CTRL)
    s.ctrl([(1670,220),(1780,220),(1780,920),(1610,920),(1610,965)])
    s.net(1685,330,'qparams',anchor='start')
    s.ff(1300,1110,360,85,'r, c, valid','result_streamer',CTRL)
    s.ctrl([(1300,1152),(1265,1152),(1265,825),(1436,825)])
    s.net(1360,808,'row/col',anchor='middle')
    s.ctrl([(1750,1180),(1660,1180)]);s.text(1750,1210,'out_ready',17,color=CTRL,anchor='end')
    s.ctrl([(1660,1125),(1750,1125)]);s.text(1750,1103,'valid · last · row/col',16,color=CTRL,anchor='end')
    s.text(1300,1092,'advance = out_valid & out_ready',16,color=CTRL)
    # Register counters and shared enable net references.
    s.ff(60,1095,350,95,'Performance counters','4 × 32 bits',CTRL)
    s.ctrl([(550,1155),(445,1155),(410,1155)])
    s.net(440,1138,'MAC / zero events')
    s.footer(['Thick wires: data buses  ·  dashed amber: selected control nets  ·  triangles: register clock pins',
              'Read address generation, bank selects and token masks follow the RTL; operand banks use register/distributed storage.'])
    return s.save('architecture.svg')


def pe_diagram():
    s=Schematic(1820,1260,'Processing element — register-transfer datapath','systolic_pe + signed_mac · D-bit signed operands · W-bit wrapping accumulator · one registered operand hop per enabled edge')
    # Unregistered incoming operands branch into the arithmetic and forwarding paths.
    s.text(52,300,'a_in[D−1:0]',20,color=DATA)
    s.text(52,499,'b_in[D−1:0]',20,color=BDATA)
    a_y,b_y=325,525
    s.wire([(55,a_y),(460,a_y)],width=3)
    s.wire([(55,b_y),(460,b_y)],color=BDATA,width=3)
    s.dot(240,a_y);s.dot(300,b_y,BDATA)
    # Isolation is combinational; zero is the other MUX input.
    a0,a1,ao,asel=s.mux_right(460,300,60,100)
    b0,b1,bo,bsel=s.mux_right(460,500,60,100,color=BDATA)
    s.text(424,370,'0',20,color=GRAY);s.wire([(435,375),a1],color=GRAY,width=2)
    s.text(424,570,'0',20,color=GRAY);s.wire([(435,575),b1],color=GRAY,width=2)
    s.text(465,285,'isolation',16,color=GRAY)
    s.wire([ao,(660,350),(660,420),(745,420)],width=3)
    s.wire([bo,(660,550),(660,480),(745,480)],color=BDATA,width=3)
    s.op(795,450,'×',55)
    s.wire([(850,450),(960,450)],width=3);s.bus(905,450,'2D')
    s.comb(960,414,185,72,'Sign extend','2D → W')
    s.wire([(1145,450),(1240,450)],width=3);s.bus(1190,450,'W')
    s.op(1285,450,'+',45)
    s.wire([(1330,450),(1450,450)],width=3)
    s.ff(1450,403,160,94,'ACC','W',DATA)
    s.wire([(1610,450),(1765,450)],width=3);s.dot(1670,450)
    s.text(1765,425,'acc_out',20,color=DATA,anchor='end')
    s.wire([(1670,450),(1670,635),(1285,635),(1285,495)],width=3)
    s.text(1480,663,'Local partial-sum feedback',18,color=DATA,anchor='middle')
    s.net(1530,360,'execute_mac',anchor='middle');s.ctrl([(1530,367),(1530,403)])
    s.net(1466,535,'clk');s.wire([(1474,513),(1474,497)],color=GRAY,width=1.4,arrow=False)
    s.net(1612,552,'clear / rst_n',anchor='end')
    # A/B forwarding registers use the original global enable, independent of MAC issue.
    s.wire([(240,325),(240,181),(1000,181)],width=3)
    am0,am1,amout,amsel=s.mux_right(1000,156,55,100)
    s.wire([(950,231),am1],color=GRAY,width=2);s.text(932,237,'0',20,color=GRAY)
    s.wire([amout,(1220,206)],width=3)
    s.ff(1220,161,195,90,'A + vA','D + 1',DATA)
    s.wire([(1415,206),(1765,206)],width=3);s.bus(1510,206,'D+1')
    s.text(1765,182,'a_out, a_valid_out → east',18,color=DATA,anchor='end')
    s.net(1050,280,'a_valid_in',anchor='middle');s.ctrl([(1027,271),amsel])
    s.net(1318,142,'enable / clear / rst_n',anchor='middle')
    s.ctrl([(1160,148),(1160,181),(1220,181)]);s.net(1155,142,'vA',anchor='end')
    s.wire([(300,525),(300,976),(1000,976)],color=BDATA,width=3)
    bm0,bm1,bmout,bmsel=s.mux_right(1000,951,55,100,color=BDATA)
    s.wire([(950,1026),bm1],color=GRAY,width=2);s.text(932,1032,'0',20,color=GRAY)
    s.wire([bmout,(1220,1001)],color=BDATA,width=3)
    s.ff(1220,956,195,90,'B + vB','D + 1',BDATA)
    s.wire([(1415,1001),(1765,1001)],color=BDATA,width=3);s.bus(1510,1001,'D+1',BDATA)
    s.text(1765,977,'b_out, b_valid_out → south',18,color=BDATA,anchor='end')
    s.net(1065,1073,'b_valid_in',anchor='middle');s.ctrl([(1027,1060),bmsel])
    s.net(1318,938,'enable / clear / rst_n',anchor='middle')
    s.ctrl([(1160,943),(1160,976),(1220,976)]);s.net(1155,937,'vB',anchor='end')
    # Symbolic issue logic plus the optional zero comparator/control path.
    s.text(65,733,'a_valid_in',18,color=CTRL);s.text(65,773,'b_valid_in',18,color=CTRL)
    s.text(65,813,'enable',18,color=CTRL);s.text(65,853,'!clear',18,color=CTRL)
    s.rect(370,702,225,165,fill='#fbf7ee',stroke=CTRL)
    s.text(483,775,'&',42,color=CTRL,anchor='middle')
    s.text(483,837,'issue',18,color=CTRL,anchor='middle')
    for yy in (728,768,808,848):s.ctrl([(235,yy),(370,yy)])
    s.ctrl([(595,787),(780,787)]);s.net(688,775,'issue',anchor='middle')
    s.comb(780,735,300,105,'& !zero_hold','zero_hold = ZERO_GATE & is_zero',CTRL)
    s.ctrl([(1080,787),(1210,787)]);s.net(1210,774,'execute_mac',anchor='end')
    s.comb(780,886,300,65,'a==0 OR b==0',None,CTRL)
    s.ctrl([(930,886),(930,840)]);s.net(953,865,'is_zero')
    s.net(735,900,'a_in, b_in',anchor='end');s.wire([(690,918),(780,918)],color=CTRL,width=1.6)
    s.net(477,446,'execute_mac',anchor='middle');s.ctrl([(490,426),asel])
    s.net(477,659,'execute_mac',anchor='middle');s.ctrl([(490,639),bsel])
    s.footer(['Matching net labels denote the same control signal. Forwarding uses enable; ACC uses execute_mac. Clear/reset take priority.',
              'No register exists between the multiplier and adder. Zero isolation holds the accumulator and does not shorten the schedule.'])
    return s.save('processing_element.svg')


def bank_diagram():
    s=Schematic(1800,1250,'Operand buffering — write decode and banked read mux','One operand_buffer shown; the core instantiates one for A and one for B. All read logic below is repeated per lane.')
    s.text(65,170,'WR: bank, lane, index, data',20,bold=True)
    s.comb(65,240,285,105,'Write decode','valid & lane_ok & index_ok',CTRL)
    s.ctrl([(180,185),(180,240)]);s.net(195,214,'wr_valid')
    memory(s,490,230,390,265,'Bank 0','LANES × DEPTH × DATA_W')
    memory(s,490,690,390,265,'Bank 1','LANES × DEPTH × DATA_W')
    s.ctrl([(350,270),(430,270),(490,270)])
    s.ctrl([(350,315),(400,315),(400,730),(490,730)])
    s.net(385,253,'we0');s.net(415,714,'we1')
    s.text(65,397,'we0 = valid & !wr_bank',17,color=CTRL)
    s.text(65,428,'we1 = valid &  wr_bank',17,color=CTRL)
    s.text(65,466,'Both also require legal lane/index.',16,color=GRAY)
    # Separate initialized flags accompany selected payload data.
    for yy in (520,980):
        s.ff(490,yy,390,62,'Initialized bits','1 per operand',CTRL)
    s.net(70,585,'rd_index[lane]',anchor='start')
    s.ctrl([(240,580),(330,580),(330,450),(490,450)])
    s.ctrl([(330,580),(330,910),(490,910)]);s.dot(330,580,CTRL)
    s.text(63,628,'Asynchronous read',18,color=GRAY)
    s.text(63,655,'Address differs by lane.',17,color=GRAY)
    s.text(63,682,'No read pipeline register.',17,color=GRAY)
    s.wire([(880,365),(945,365),(945,580),(1030,580)],width=3)
    s.wire([(880,822),(945,822),(945,660),(1030,660)],width=3)
    s.ctrl([(880,551),(990,551),(990,580),(1030,580)])
    s.ctrl([(880,1011),(990,1011),(990,660),(1030,660)])
    s.mux_right(1030,540,70,160)
    s.text(1065,524,'data + init',17,color=DATA,anchor='middle')
    s.ctrl([(1065,765),(1065,691)]);s.net(1065,795,'rd_bank',anchor='middle')
    s.wire([(1100,620),(1300,620)],width=3);s.bus(1190,620,'D')
    s.comb(1180,315,485,100,'rd_enable & index_ok & selected_init',None,CTRL)
    s.ctrl([(1135,620),(1135,460),(1375,460),(1375,415)])
    s.net(1180,284,'Per-lane read qualification')
    z0,z1,zo,zsel=s.mux_right(1300,580,70,160)
    # First input at y620, lower input is zero at y700.
    s.wire([(1210,700),z1],color=GRAY,width=2);s.text(1185,707,'0',22,color=GRAY)
    s.ctrl([(1423,415),(1423,765),(1335,765),zsel])
    s.wire([zo,(1690,660)],width=3);s.bus(1530,660,'D')
    s.text(1690,639,'rd_data[lane]',20,color=DATA,anchor='end')
    s.text(1180,869,'D = DATA_W; repeat for every lane',18,color=GRAY)
    s.text(1180,899,'Invalid or uninitialized reads select zero.',17,color=GRAY)
    s.text(1180,929,'Bank payload persists until overwritten.',17,color=GRAY)
    # Ownership is explicitly outside this memory module.
    s.rect(65,1070,1600,86,fill='#fbf7ee',stroke=CTRL)
    s.text(85,1100,'In edgegemm_core, before operand_buffer:',18,color=CTRL,bold=True)
    s.text(85,1134,'load_ready = !busy OR (load_bank != active_bank);   accepted write = load_valid & load_ready',19,color=CTRL)
    s.footer(['Bank muxes are combinational; initialized bits reset to zero. Payload storage is register/distributed storage, not a synchronous SRAM macro.'])
    return s.save('banking.svg')


def quant_diagram():
    s=Schematic(2220,950,'Affine requantizer — widened integer datapath','Default widths shown: ACC_W=32, OUT_W=8. All blocks are combinational; per-column configuration is held separately.')
    s.text(60,415,'acc[31:0]',20,color=PURPLE)
    s.wire([(60,460),(175,460)],color=PURPLE,width=3);s.bus(125,460,'32',PURPLE)
    s.comb(175,423,115,74,'SEXT','32 → 33',PURPLE)
    s.wire([(290,460),(316,460)],color=PURPLE,width=3)
    s.op(360,460,'+',44)
    s.text(360,194,'bias[31:0]',19,color=CTRL,anchor='middle')
    s.comb(300,250,120,70,'SEXT','32 → 33',CTRL)
    s.ctrl([(360,205),(360,250)]);s.wire([(360,320),(360,416)],width=3);s.bus(360,365,'33')
    s.wire([(404,460),(605,460)],width=3);s.bus(500,460,'33')
    s.op(650,460,'×',45)
    s.text(650,194,'multiplier[15:0]',19,color=CTRL,anchor='middle')
    s.comb(590,250,120,70,'0 || scale','16 → 17',CTRL)
    s.ctrl([(650,205),(650,250)]);s.wire([(650,320),(650,415)],width=3);s.bus(650,365,'17')
    s.wire([(695,460),(765,460)],width=3);s.bus(725,460,'50');s.dot(765,460)
    # The two branches correspond to the actual rounding flag, not pipeline stages.
    s.comb(845,255,365,135,'ABS → shift → round → sign','51-bit magnitude; nearest ties away',DATA)
    s.comb(845,590,365,100,'Arithmetic right shift','sign-extend to 51 bits, then >>> s',DATA)
    s.wire([(765,460),(765,322),(845,322)],width=3)
    s.wire([(765,460),(765,640),(845,640)],width=3)
    r0,r1,ro,rsel=s.mux_right(1300,365,70,190)
    # High input is nearest; low input is floor; the selection net is explicit.
    s.wire([(1210,322),(1250,322),(1250,r0[1]),r0],width=3)
    s.wire([(1210,640),(1250,640),(1250,r1[1]),r1],width=3)
    s.text(1278,r0[1]+6,'1',16,color=GRAY,anchor='end')
    s.text(1278,r1[1]+6,'0',16,color=GRAY,anchor='end')
    s.net(1335,616,'round_nearest',anchor='middle');s.ctrl([(1335,590),rsel])
    s.net(995,226,'right_shift[5:0]',anchor='middle');s.ctrl([(995,234),(995,255)])
    s.net(995,743,'right_shift[5:0]',anchor='middle');s.ctrl([(995,723),(995,690)])
    s.wire([ro,(1466,460)],width=3);s.bus(1410,460,'51')
    s.op(1510,460,'+',44)
    s.comb(1450,635,120,70,'SEXT','8 → 51',CTRL)
    s.text(1510,773,'zero_point[7:0]',19,color=CTRL,anchor='middle')
    s.ctrl([(1510,746),(1510,705)]);s.wire([(1510,635),(1510,504)],width=3);s.bus(1510,575,'51')
    s.wire([(1554,460),(1625,460)],width=3)
    s.comb(1625,410,210,100,'ReLU mux','relu ? max(x,zp) : x')
    s.net(1730,332,'relu_en',anchor='middle');s.ctrl([(1730,345),(1730,410)])
    s.wire([(1835,460),(1900,460)],width=3);s.bus(1865,460,'51')
    s.comb(1900,410,170,100,'Saturate','−128 … 127')
    s.wire([(2070,460),(2165,460)],width=3);s.bus(2118,460,'8')
    s.text(2165,413,'out_data',20,color=DATA,anchor='end')
    s.footer(['Bias addition is 33 bits, scale multiplication is 50 bits, and shift/round/zero-point operations use 51-bit guarded values.',
              'The final clamp alone reduces precision to OUT_W. ReLU clamps at output zero_point; input zero-point subtraction is outside this datapath.'])
    return s.save('requantization.svg')
