#!/usr/bin/env python3
"""Real USB bench checks. No human gestures, no game input synthesis, no saved calibration changes.

Close the normal bridge first. This sends STOP/START and resets one verified ESP32 via RTS.
It does not emulate a physical USB unplug and does not verify wrist directions.
"""
import collections
import json
from pathlib import Path
import time
import serial
from serial.tools import list_ports
from bridge import ControllerState, USB_VIDS


class Rig:
    def __init__(self):
        self.state=ControllerState(Path(__file__).with_name("controllers.local.json"))
        self.expected={p["id"] for p in self.state.players if p["id"]}
        self.connections={};self.buffers={};self.stopped=set()
        self.counts=collections.Counter();self.failures=[];self.passed=[]

    def open(self, reverse=False):
        ports=sorted([p.device for p in list_ports.comports() if p.vid in USB_VIDS],reverse=reverse)
        for port in ports:
            connection=serial.Serial(port=None,baudrate=115200,timeout=0,write_timeout=.2,exclusive=True)
            connection.dtr=False;connection.rts=False;connection.port=port;connection.open()
            self.connections[port]=connection;self.buffers[port]=bytearray()
            connection.write(b"HELLO\n")

    def close(self):
        for port,connection in self.connections.items():
            connection.close();self.state.disconnect(port)
        self.connections.clear();self.buffers.clear()

    def pump(self, seconds):
        end=time.monotonic()+seconds
        while time.monotonic()<end:
            for port,connection in self.connections.items():
                data=connection.read(min(connection.in_waiting,4096))
                buffer=self.buffers[port];buffer.extend(data)
                if len(buffer)>16000:buffer.clear()
                while b"\n" in buffer:
                    line,_,remaining=buffer.partition(b"\n");buffer[:]=remaining
                    try:frame=json.loads(line)
                    except (ValueError,UnicodeError):continue
                    if not isinstance(frame,dict) or str(frame.get("id","")).lower() not in self.expected:continue
                    accepted=self.state.ingest(port,frame)
                    if accepted and frame.get("kind")=="hello" and port not in self.stopped:
                        connection.write(b"START\n")
                    elif accepted and frame.get("ok") is True:
                        self.counts[str(frame["id"]).lower()]+=1
            time.sleep(.002)

    def check(self, condition, label):
        (self.passed if condition else self.failures).append(label)
        print(("PASS " if condition else "FAIL ")+label,flush=True)

    def run(self):
        self.open();self.pump(3)
        snapshot=self.state.snapshot()
        self.check(len(self.expected)==2 and all(p["connected"] for p in snapshot["players"]),"Both physical USB sensors stream with saved player IDs")
        self.check(all(d.pins==[21,22] and d.boot>0 for d in self.state.devices.values()),"Both boards report verified pins and reboot ID firmware")
        self.check(all(self.counts[identity]>60 for identity in self.expected),"Both boards provide more than 60 valid measured frames")
        if not self.expected.issubset(self.state.devices):
            print("Missing expected hardware IDs:",sorted(self.expected-set(self.state.devices)),flush=True)
            return 1
        target=self.state.devices[self.state.players[0]["id"]]
        other_id=self.state.players[1]["id"]
        print("Detected role ports:",[(p["id"],self.state.devices[p["id"]].port) for p in self.state.players],flush=True)
        self.stopped.add(target.port)
        before=self.counts[other_id]
        self.connections[target.port].write(b"STOP\n");self.pump(.7)
        players=self.state.snapshot()["players"]
        self.check(not players[0]["connected"] and players[0]["value"]==0,"Real STOP frame/data interruption neutralizes Player 1")
        self.check(players[1]["connected"] and self.counts[other_id]-before>15,"Other USB sensor continues independently during interruption")
        self.stopped.remove(target.port);self.connections[target.port].write(b"START\n");self.pump(2)
        self.check(self.state.snapshot()["players"][0]["connected"],"Actual sensor stream resumes after START")
        old_boot=target.boot;old_seq=target.last_seq
        self.stopped.add(target.port)
        connection=self.connections[target.port]
        connection.rts=True;time.sleep(.12);connection.rts=False
        self.pump(4.2) # Intentionally start later than the previous 3-second recovery window.
        self.check(target.boot!=old_boot and not self.state.snapshot()["players"][0]["connected"],"Actual hardware reboot changes boot ID and returns input to neutral")
        self.stopped.remove(target.port);connection.write(b"START\n");self.pump(1.5)
        self.check(self.state.snapshot()["players"][0]["connected"],"Delayed START after actual reboot restores measurements")
        print("Reboot evidence:",dict(previous_boot=old_boot,boot=target.boot,previous_seq=old_seq,seq=target.last_seq,ms=target.last_ms),flush=True)
        previous_ids=[p["id"] for p in self.state.players]
        self.close();self.open(reverse=True);self.pump(3)
        self.check([p["id"] for p in self.state.players]==previous_ids and all(p["connected"] for p in self.state.snapshot()["players"]),"Reopening real USB ports in reversed order preserves both roles")
        print("REAL USB BENCH: %d passed, %d failed"%(len(self.passed),len(self.failures)),flush=True)
        print("Not tested here: physical unplug, worn wrist axes, human game clear.",flush=True)
        return 1 if self.failures else 0


if __name__=="__main__":
    rig=Rig()
    try:result=rig.run()
    finally:rig.close()
    raise SystemExit(result)
