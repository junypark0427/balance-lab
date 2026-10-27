#!/usr/bin/env python3
"""Two independent USB readers -> ID-bound players -> loopback-only UDP.

No game physics or coordinates are controlled here. Run --help for operator commands.
"""
from __future__ import annotations
import argparse
import csv
import json
import math
import os
from pathlib import Path
import queue
import re
import socket
import statistics
import threading
import time
import uuid
from collections import deque
from dataclasses import dataclass, field

PROTOCOL = 1
STALE = 0.25
USB_VIDS = {0x1A86, 0x10C4, 0x303A, 0x0403}
ID_PATTERN = re.compile(r"esp32-[0-9A-Fa-f]{12}\Z")


def circular_delta(angle, zero):
    return (angle - zero + 180.0) % 360.0 - 180.0


def finite_number(value, limit):
    return type(value) in (int, float) and math.isfinite(value) and abs(value) <= limit


@dataclass
class Device:
    identity: str
    port: str
    pins: list = field(default_factory=list)
    last_good: float = 0.0
    last_seq: int = -1
    last_ms: int = -1
    sample: dict = field(default_factory=dict)
    error: str = "waiting"
    calibrating: bool = False
    calibration_started: float = 0.0
    calibration: list = field(default_factory=list)
    boot: int = -1
    recent: deque = field(default_factory=lambda:deque(maxlen=20))


class ControllerState:
    def __init__(self, config_path, clock=time.monotonic):
        self.clock = clock
        self.path = Path(config_path)
        self.devices = {}
        self.players = [self.defaults("roll"), self.defaults("pitch")]
        self.filtered = [0.0, 0.0]
        self.message = "Assign each device ID to a player, then calibrate."
        self.mode = "keyboard"  # Every launch starts safely; enabling is deliberate.
        self.last_init = {}
        if self.path.exists():
            raw = json.loads(self.path.read_text())
            for index, value in enumerate(raw.get("players", [])[:2]):
                self.players[index].update({k: v for k, v in value.items() if k in self.players[index]})
        self.validate_config()
        # Keep role/offset values, but verify the worn neutral pose in each new session.
        for player in self.players:
            player["calibrated"]=False

    @staticmethod
    def defaults(axis):
        return dict(id="", axis=axis, invert=False, zero_roll=0.0, zero_pitch=0.0,
                    deadzone=2.5, limit=25.0, smoothing=0.04, calibrated=False)

    def validate_config(self):
        identities = []
        for p in self.players:
            if p["id"] and not ID_PATTERN.fullmatch(p["id"]): raise ValueError("Invalid saved device ID")
            if p["id"]: identities.append(p["id"])
            if p["axis"] not in ("roll", "pitch"): raise ValueError("Invalid saved sensor axis")
            for key, high in (("zero_roll",180),("zero_pitch",90),("deadzone",10),("limit",75),("smoothing",0.3)):
                if not finite_number(p[key],high): raise ValueError("Invalid saved " + key)
            if not 0 <= p["deadzone"] < p["limit"] or p["smoothing"] < 0: raise ValueError("Invalid angle range/filter")
            if type(p["invert"]) is not bool or type(p["calibrated"]) is not bool: raise ValueError("Invalid boolean setting")
        if len(identities) != len(set(identities)): raise ValueError("A controller cannot control both players")

    def save(self):
        self.validate_config()
        self.path.parent.mkdir(parents=True,exist_ok=True)
        temp=self.path.with_suffix(".tmp")
        temp.write_text(json.dumps({"version":1,"players":self.players},indent=2)+"\n")
        os.replace(temp,self.path)

    def disconnect(self, port):
        for d in self.devices.values():
            if d.port == port:
                d.error="disconnected"; d.last_good=0; d.calibrating=False
                d.recent.clear()

    def ingest(self, port, frame):
        now=self.clock()
        if not isinstance(frame,dict) or frame.get("v") != 1: return False
        identity=frame.get("id","")
        if not isinstance(identity,str) or not ID_PATTERN.fullmatch(identity): return False
        identity=identity.lower()
        existing=self.devices.get(identity)
        # Two live USB endpoints claiming one ID are never assigned by port order.
        if existing and existing.port!=port and now-existing.last_good<STALE:
            self.message="Duplicate device ID rejected"; return False
        if frame.get("kind")=="hello":
            pins=frame.get("pins")
            if frame.get("board")!="ESP32" or not isinstance(pins,list) or len(pins)!=2 or any(type(x)is not int or not 0<=x<=39 for x in pins): return False
            if not existing or existing.port != port or existing.error=="disconnected":
                existing=Device(identity,port); self.devices[identity]=existing
            boot=frame.get("boot",0)
            if type(boot) is not int or not 0<=boot<=0xFFFFFFFF: return False
            if existing.boot != boot:
                existing.boot=boot;existing.last_seq=-1;existing.last_ms=-1
                existing.last_good=0;existing.error="waiting";existing.calibrating=False
                existing.recent.clear()
            existing.pins=pins
            return True
        if not existing or existing.port!=port: return False
        seq=frame.get("seq"); ms=frame.get("ms")
        if type(seq)is not int or type(ms)is not int or not 0<=seq<=0xFFFFFFFF or not 0<=ms<=0xFFFFFFFF: return False
        if seq<=existing.last_seq:
            # A board reboot is accepted only after uptime actually resets.
            if ms < existing.last_ms and ms < 3000:
                existing.last_seq=-1; existing.last_good=0; existing.calibrating=False
            else: return False
        existing.last_seq=seq; existing.last_ms=ms
        if frame.get("ok") is not True:
            existing.error=str(frame.get("error","sensor_error"))[:40]; existing.last_good=0
            existing.recent.clear()
            if existing.error!="calibrating": existing.calibrating=False
            return True
        valid=all(finite_number(frame.get(k),lim) for k,lim in (("roll",180),("pitch",90)))
        for key,limit in (("a",2.1),("g",550)):
            vector=frame.get(key)
            valid &= isinstance(vector,list) and len(vector)==3 and all(finite_number(x,limit) for x in vector)
        if not valid:
            existing.recent.clear()
            existing.error="invalid_sample"; existing.last_good=0; return False
        existing.sample=frame; existing.last_good=now; existing.error=""
        existing.recent.append((now,frame))
        if existing.calibrating:
            norm=math.sqrt(sum(v*v for v in frame["a"]))
            stable=0.85<=norm<=1.15 and max(abs(v) for v in frame["g"])<8.0
            if stable: existing.calibration.append((frame["roll"],frame["pitch"]))
            else: existing.calibration.clear()
            if len(existing.calibration)>=60:
                values=existing.calibration[-60:]
                roll0=values[0][0]
                rolls=[roll0+circular_delta(v[0],roll0) for v in values]
                pitches=[v[1] for v in values]
                if max(statistics.pstdev(rolls),statistics.pstdev(pitches))<=1.5:
                    for index,p in enumerate(self.players):
                        if p["id"]==identity:
                            p.update(zero_roll=circular_delta(statistics.mean(rolls),0),zero_pitch=statistics.mean(pitches),calibrated=True)
                            self.filtered[index]=0.0
                    self.save();existing.calibrating=False
                    self.message="Calibrated " + identity
                else: existing.calibration.clear()
        return True

    def recenter(self, command):
        request=str(command.get("request",uuid.uuid4().hex))[:64]
        targets=[];now=self.clock()
        for index,p in enumerate(self.players):
            d=self.devices.get(p["id"])
            if d and d.last_good and now-d.last_good<STALE and not d.error:
                targets.append((index,d))
        reason="not_connected" if not targets else ""
        offsets={}
        for index,d in targets:
            samples=[(t,s) for t,s in d.recent if now-t<=.4]
            if d.calibrating:reason="busy";break
            if len(samples)<8 or samples[-1][0]-samples[0][0]<.12:reason="no_samples";break
            if any(not .85<=math.sqrt(sum(v*v for v in s["a"]))<=1.15 or max(abs(v) for v in s["g"])>=8 for _,s in samples):
                reason="moving";break
            ref=samples[0][1]["roll"]
            rolls=[ref+circular_delta(s["roll"],ref) for _,s in samples]
            pitches=[s["pitch"] for _,s in samples]
            if max(statistics.pstdev(rolls),statistics.pstdev(pitches))>1.2:reason="moving";break
            offsets[index]=(circular_delta(statistics.mean(rolls),0),statistics.mean(pitches))
        if not reason:
            before=[p.copy() for p in self.players]
            for index,(roll,pitch) in offsets.items():
                self.players[index].update(zero_roll=roll,zero_pitch=pitch,calibrated=True)
            try:self.save()
            except OSError:
                self.players=before;reason="save_failed"
            else:
                for index in offsets:self.filtered[index]=0.0
        players=[index+1 for index,_ in targets]
        self.last_init=dict(request=request,status="error" if reason else "ok",players=players,reason=reason)
        self.message="INIT failed: "+reason if reason else "INIT complete: "+", ".join("P%d"%p for p in players)

    def command(self, command):
        """Returns (port, serial-command) pairs; transport remains separate."""
        sends=[]
        if not isinstance(command,dict): return sends
        action=command.get("action")
        if action=="recenter":
            self.recenter(command)
            return sends
        if action=="mode":
            if command.get("mode") in ("keyboard","sensor"): self.mode=command["mode"]
            return sends
        player=command.get("player")
        if action=="calibrate" and player==0:
            for index in (1,2): sends += self.command({"action":"calibrate","player":index})
            return sends
        if type(player) is not int or player not in (1,2): return sends
        index=player-1; p=self.players[index]
        if action=="assign":
            identity=str(command.get("id","")).lower()
            if identity and identity not in self.devices: self.message="Device is not connected"; return sends
            if identity and any(i!=index and value["id"]==identity for i,value in enumerate(self.players)):
                self.message="That ID already belongs to the other player"; return sends
            p.update(id=identity,calibrated=False);self.filtered[index]=0
            self.message="Player %d registered. Hold neutral and calibrate."%player
        elif action=="configure":
            if command.get("axis") in ("roll","pitch"): p["axis"]=command["axis"]
            if type(command.get("invert")) is bool: p["invert"]=command["invert"]
            for key,high in (("deadzone",10),("limit",75),("smoothing",0.3)):
                if finite_number(command.get(key),high) and command[key]>=0:
                    value=command[key]
                    if key=="deadzone" and value>=p["limit"]: continue
                    if key=="limit" and value<=p["deadzone"]: continue
                    p[key]=value
            self.filtered[index]=0
        elif action=="calibrate":
            d=self.devices.get(p["id"])
            if not d or self.clock()-d.last_good>=STALE:
                self.message="P%d is not receiving valid measurements"%player;return sends
            p["calibrated"]=False;self.filtered[index]=0
            d.calibration.clear();d.calibrating=True;d.calibration_started=self.clock()
            sends.append((d.port,b"BIAS\n")); self.message="Hold neutral and still for 3 seconds"
        else: return sends
        self.save();return sends

    def snapshot(self, dt=0.02):
        now=self.clock(); players=[]; devices=[]
        for d in self.devices.values():
            fresh=bool(d.last_good) and now-d.last_good<STALE
            if d.calibrating and now-d.calibration_started>10:
                d.calibrating=False;d.calibration.clear();self.message="Calibration failed: hold still, then retry"
            devices.append(dict(id=d.identity,port=d.port,pins=d.pins,connected=fresh,error=d.error,boot=d.boot,seq=d.last_seq,ms=d.last_ms,
                                roll=d.sample.get("roll",0),pitch=d.sample.get("pitch",0)))
        for index,p in enumerate(self.players):
            d=self.devices.get(p["id"])
            connected=bool(d and d.last_good and now-d.last_good<STALE and not d.error)
            active=connected and p["calibrated"] and not d.calibrating
            angle=0.0; target=0.0
            if active:
                raw=d.sample[p["axis"]];zero=p["zero_"+p["axis"]]
                angle=circular_delta(raw,zero) if p["axis"]=="roll" else raw-zero
                magnitude=max(0.0, min(abs(angle),p["limit"])-p["deadzone"])/(p["limit"]-p["deadzone"])
                target=math.copysign(magnitude,angle)*(-1 if p["invert"] else 1)
                weight=1.0 if p["smoothing"]==0 else 1-math.exp(-min(dt,0.1)/p["smoothing"])
                self.filtered[index] += weight*(target-self.filtered[index])
            else: self.filtered[index]=0.0 # Disconnect/invalid data are neutral immediately.
            players.append(dict(id=p["id"],axis=p["axis"],invert=p["invert"],deadzone=p["deadzone"],limit=p["limit"],smoothing=p["smoothing"],
                                connected=connected,calibrated=p["calibrated"],calibrating=bool(d and d.calibrating),angle=angle,
                                value=self.filtered[index],age_ms=round((now-d.last_good)*1000) if d and d.last_good else -1))
        return dict(v=1,kind="balance_sensors",mode=self.mode,players=players,devices=devices,message=self.message,init=self.last_init)


def serial_reader(port, events, commands, stop):
    import serial
    connection=None
    try:
        connection=serial.Serial(port=None,baudrate=115200,timeout=0.05,write_timeout=0.1,exclusive=True if os.name=="posix" else None)
        connection.dtr=False;connection.rts=False;connection.port=port;connection.open()
        connection.write(b"HELLO\n")
        buffer=bytearray();discard=False; last_hello=0
        while not stop.is_set():
            try:
                while True: connection.write(commands.get_nowait())
            except queue.Empty: pass
            data=connection.read(min(connection.in_waiting,2048) or 1)
            for byte in data:
                if byte==10:
                    if not discard:
                        try:
                            frame=json.loads(buffer.decode())
                            if isinstance(frame,dict): events.put((port,frame))
                        except (ValueError,UnicodeError): pass
                    buffer.clear();discard=False
                elif len(buffer)<768 and not discard: buffer.append(byte)
                else: buffer.clear();discard=True
            if time.monotonic()-last_hello>1:
                connection.write(b"HELLO\n");last_hello=time.monotonic()
    except (OSError,serial.SerialException) as exc:
        events.put((port,{"transport_error":str(exc)[:160]}))
    finally:
        if connection:
            try: connection.close()
            except OSError: pass
        events.put((port,{"closed":True}))


def parse_console(line):
    parts=line.split()
    if not parts:return {}
    try:
        if parts[0] in ("keyboard","sensor"):return dict(action="mode",mode=parts[0])
        if parts[0]=="assign" and len(parts)==3:return dict(action="assign",player=int(parts[1]),id=parts[2])
        if parts[0]=="calibrate":return dict(action="calibrate",player=0 if len(parts)==1 or parts[1]=="all" else int(parts[1]))
        if parts[0]=="init":return dict(action="recenter",request=uuid.uuid4().hex)
        if parts[0]=="axis" and len(parts)==3:return dict(action="configure",player=int(parts[1]),axis=parts[2])
        if parts[0]=="invert" and len(parts)==3:return dict(action="configure",player=int(parts[1]),invert=parts[2]=="on")
    except ValueError: pass
    return {}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config",type=Path,default=Path(__file__).with_name("controllers.local.json"))
    parser.add_argument("--port",action="append",help="Optional explicit port; normally USB ports are discovered")
    parser.add_argument("--udp-port",type=int,default=6171)
    parser.add_argument("--command-port",type=int,default=6172)
    parser.add_argument("--duration",type=float,default=0)
    parser.add_argument("--log",type=Path)
    parser.add_argument("--no-console",action="store_true")
    args=parser.parse_args()
    try:
        from serial.tools import list_ports
    except ImportError:parser.error("Install requirements.txt in a Python virtual environment first")
    state=ControllerState(args.config)
    udp=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
    try:udp.bind(("127.0.0.1",args.command_port))
    except OSError:parser.error("Sensor bridge is already running, or command port is occupied")
    udp.setblocking(False)
    events=queue.Queue();console=queue.Queue();workers={};queues={};stop=threading.Event()
    session=uuid.uuid4().hex;seq=0;start=last=time.monotonic();scan=printed=0
    log_file=None;writer=None
    if args.log:
        args.log.parent.mkdir(parents=True,exist_ok=True);log_file=args.log.open("w",newline="")
        writer=csv.writer(log_file);writer.writerow(["seconds","p1_id","p2_id","p1_angle","p2_angle","p1_value","p2_value","p1_connected","p2_connected","mode","p1_roll","p1_pitch","p2_roll","p2_pitch","p1_seq","p2_seq"])
    def read_console():
        while not stop.is_set():
            try:line=input()
            except EOFError:return
            console.put(line)
    if not args.no_console:threading.Thread(target=read_console,daemon=True).start()
    print("BALANCE LAB SENSOR BRIDGE | 115200 | UDP 127.0.0.1:%d"%args.udp_port,flush=True)
    print("Godot F4: pair/calibrate/configure. F8: mode. Console: assign 1 ID / axis 1 roll / invert 1 on / calibrate all / sensor / keyboard / quit",flush=True)
    try:
        while not args.duration or time.monotonic()-start<args.duration:
            tick=time.monotonic()
            if tick-scan>1:
                ports=set(args.port or [p.device for p in list_ports.comports() if p.vid in USB_VIDS])
                for port in list(workers):
                    if not workers[port].is_alive():del workers[port];queues.pop(port,None)
                for port in sorted(ports-set(workers)):
                    q=queue.Queue();queues[port]=q
                    thread=threading.Thread(target=serial_reader,args=(port,events,q,stop),daemon=True)
                    workers[port]=thread;thread.start()
                scan=tick
            for _ in range(500):
                try:port,frame=events.get_nowait()
                except queue.Empty:break
                if "closed" in frame or "transport_error" in frame:
                    state.disconnect(port)
                    if "transport_error" in frame:print("[USB]",port,frame["transport_error"],flush=True)
                elif state.ingest(port,frame) and frame.get("kind")=="hello":
                    if port in queues:queues[port].put(b"START\n")
            commands=[]
            for _ in range(64):
                try:data,peer=udp.recvfrom(4096)
                except BlockingIOError:break
                if peer[0]!="127.0.0.1" or len(data)>=4096:continue
                try:command=json.loads(data)
                except (ValueError,UnicodeError):continue
                if isinstance(command,dict):commands.append(command)
            while not console.empty():
                line=console.get_nowait()
                if line.strip()=="quit":stop.set();break
                commands.append(parse_console(line))
            if stop.is_set():break
            for command in commands:
                for port,data in state.command(command):
                    if port in queues:queues[port].put(data)
            snapshot=state.snapshot(tick-last);snapshot.update(session=session,seq=seq,sent_unix_ms=round(time.time()*1000))
            udp.sendto(json.dumps(snapshot,allow_nan=False,separators=(",",":")).encode(),("127.0.0.1",args.udp_port))
            if writer:
                p1,p2=snapshot["players"]
                samples=[state.devices[p["id"]].sample if p["id"] in state.devices else {} for p in (p1,p2)]
                writer.writerow([round(tick-start,3),p1["id"],p2["id"],p1["angle"],p2["angle"],p1["value"],p2["value"],p1["connected"],p2["connected"],state.mode]+[s.get(axis,"") for s in samples for axis in ("roll","pitch")]+[s.get("seq","") for s in samples])
            if tick-printed>=1:
                print(json.dumps(snapshot,separators=(",",":")),flush=True);printed=tick
            seq+=1;last=tick
            stop.wait(max(0,0.02-(time.monotonic()-tick)))
    except KeyboardInterrupt:pass
    finally:
        state.mode="keyboard";stop.set()
        snapshot=state.snapshot();snapshot.update(session=session,seq=seq+1,sent_unix_ms=round(time.time()*1000))
        for p in snapshot["players"]:p["value"]=0;p["connected"]=False
        udp.sendto(json.dumps(snapshot).encode(),("127.0.0.1",args.udp_port));udp.close()
        for thread in workers.values():thread.join(timeout=0.4)
        if log_file:log_file.close()


if __name__=="__main__":main()
