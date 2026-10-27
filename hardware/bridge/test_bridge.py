import json
import math
from pathlib import Path
import tempfile
import unittest
from bridge import ControllerState

A="esp32-680947606060"
B="esp32-08d1f9e7279c"

class BridgeTest(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.now=100.0
        self.state=ControllerState(Path(self.tmp.name)/"settings.json",lambda:self.now)
        self.sequences={A:0,B:0}
        for identity,port in ((A,"PORT_A"),(B,"PORT_B")):
            self.assertTrue(self.state.ingest(port,dict(v=1,kind="hello",id=identity,board="ESP32",pins=[21,22])))
        self.state.command(dict(action="assign",player=1,id=A))
        self.state.command(dict(action="assign",player=2,id=B))

    def tearDown(self):self.tmp.cleanup()

    def sample(self,identity=A,roll=0,pitch=0,gyro=None):
        self.sequences[identity]+=1
        frame=dict(v=1,id=identity,seq=self.sequences[identity],ms=int(self.now*1000),ok=True,
                   roll=roll,pitch=pitch,a=[0,0,1],g=gyro or [0,0,0])
        return self.state.ingest("PORT_A" if identity==A else "PORT_B",frame)

    def ready(self):
        for p in self.state.players:p["calibrated"]=True;p["smoothing"]=0
        self.sample(A);self.sample(B)
        self.state.mode="sensor"

    def test_analog_deadzone_saturation_and_independent_axes(self):
        self.ready();self.sample(A,roll=13.75);self.sample(B,pitch=-25)
        a,b=self.state.snapshot()["players"]
        self.assertAlmostEqual(a["value"],.5);self.assertEqual(b["value"],-1)
        self.sample(A,roll=2.4);self.assertEqual(self.state.snapshot()["players"][0]["value"],0)
        self.sample(A,roll=80);self.assertEqual(self.state.snapshot()["players"][0]["value"],1)

    def test_stale_and_single_device_neutral(self):
        self.ready();self.sample(A,roll=25);self.sample(B,pitch=25)
        self.now+=.26;self.sample(A,roll=25)
        a,b=self.state.snapshot()["players"]
        self.assertEqual(a["value"],1);self.assertEqual(b["value"],0);self.assertFalse(b["connected"])

    def test_invalid_sample_and_sensor_fault_neutral(self):
        self.ready();self.sample(A,roll=25)
        self.assertFalse(self.sample(A,roll=math.nan))
        self.assertEqual(self.state.snapshot()["players"][0]["value"],0)
        self.sample(A,roll=25)
        self.state.ingest("PORT_A",dict(v=1,id=A,seq=99,ms=100010,ok=False,error="i2c_read"))
        self.assertEqual(self.state.snapshot()["players"][0]["value"],0)

    def test_replayed_frames_do_not_extend_freshness(self):
        self.ready();before=self.state.devices[A].last_good;self.now+=.15
        self.sequences[A]-=1
        self.assertFalse(self.sample(A,roll=25));self.assertEqual(self.state.devices[A].last_good,before)

    def test_role_persistence_and_reversed_port_order(self):
        self.state.save()
        new=ControllerState(self.state.path,lambda:self.now)
        for identity,port in ((B,"NEW_FIRST"),(A,"NEW_SECOND")):
            new.ingest(port,dict(v=1,kind="hello",id=identity,board="ESP32",pins=[21,22]))
        self.assertEqual([p["id"] for p in new.players],[A,B])
        self.assertEqual(new.mode,"keyboard")

    def test_duplicate_id_is_not_assigned_twice(self):
        self.state.command(dict(action="assign",player=2,id=A))
        self.assertEqual(self.state.players[1]["id"],B)
        self.sample(A)
        self.assertFalse(self.state.ingest("OTHER_PORT",dict(v=1,kind="hello",id=A,board="ESP32",pins=[21,22])))

    def test_calibration_stillness_wrap_and_persistence(self):
        self.sample(A,roll=179.8)
        self.assertEqual(self.state.command(dict(action="calibrate",player=1)),[("PORT_A",b"BIAS\n")])
        for i in range(60):
            self.now+=.02;self.sample(A,roll=179.8 if i%2 else -179.8,pitch=4)
        p=self.state.players[0]
        self.assertTrue(p["calibrated"]);self.assertAlmostEqual(abs(p["zero_roll"]),180)
        restored=ControllerState(self.state.path)
        self.assertFalse(restored.players[0]["calibrated"])
        self.assertAlmostEqual(abs(restored.players[0]["zero_roll"]),180)
        self.assertAlmostEqual(restored.players[0]["zero_pitch"],4)

    def test_movement_does_not_calibrate(self):
        self.sample(A);self.state.command(dict(action="calibrate",player=1))
        for i in range(100):self.now+=.02;self.sample(A,roll=(i%2)*20,gyro=[20,0,0])
        self.assertFalse(self.state.players[0]["calibrated"])
        self.now+=11;self.state.snapshot();self.assertFalse(self.state.devices[A].calibrating)

    def test_inversion_axis_selection_and_disconnect(self):
        self.ready();self.state.command(dict(action="configure",player=1,axis="pitch",invert=True))
        self.sample(A,pitch=25)
        self.assertEqual(self.state.snapshot()["players"][0]["value"],-1)
        self.state.disconnect("PORT_A")
        self.assertEqual(self.state.snapshot()["players"][0]["value"],0)

    def test_malformed_messages_do_not_raise(self):
        for frame in (None,[],42,{},dict(v=1,id="bad"),dict(v=1,id=A,seq=True,ms=1,ok=True)):
            self.assertFalse(self.state.ingest("PORT_A",frame))
        self.state.command(dict(action="configure",player=1,limit=float("inf"),deadzone=100))
        self.assertEqual(self.state.players[0]["limit"],25)

    def steady_samples(self, moving=False):
        for _ in range(20):
            self.now+=.02
            self.sample(A,roll=31,pitch=12,gyro=[20,0,0] if moving else [0,0,0])
            self.sample(B,roll=-42,pitch=-9)

    def test_init_sets_current_pose_without_serial_bias_command(self):
        self.steady_samples()
        self.assertEqual(self.state.command(dict(action="recenter",request="test-init")),[])
        self.assertEqual(self.state.snapshot()["init"],dict(request="test-init",status="ok",players=[1,2],reason=""))
        self.assertEqual([p["zero_roll"] for p in self.state.players],[31,-42])
        self.assertEqual([p["zero_pitch"] for p in self.state.players],[12,-9])
        self.state.mode="sensor"
        self.assertTrue(all(abs(p["value"])<.0001 for p in self.state.snapshot()["players"]))
        saved=json.loads(self.state.path.read_text())
        self.assertEqual(saved["players"][0]["zero_roll"],31)

    def test_init_movement_rejects_every_target_without_changing_zero(self):
        self.steady_samples(moving=True)
        before=[p.copy() for p in self.state.players]
        self.state.command(dict(action="recenter",request="moving"))
        self.assertEqual(self.state.last_init["status"],"error")
        self.assertEqual(self.state.last_init["reason"],"moving")
        self.assertEqual(self.state.players,before)

    def test_init_only_connected_controller_and_no_connection_error(self):
        self.steady_samples();self.state.disconnect("PORT_A")
        self.state.command(dict(action="recenter",request="single"))
        self.assertEqual(self.state.last_init["players"],[2])
        self.assertEqual(self.state.last_init["status"],"ok")
        self.state.disconnect("PORT_B")
        self.state.command(dict(action="recenter",request="offline"))
        self.assertEqual(self.state.last_init["reason"],"not_connected")

    def test_init_will_not_reuse_samples_before_a_sensor_error(self):
        self.steady_samples()
        self.state.ingest("PORT_A",dict(v=1,id=A,seq=100,ms=100500,ok=False,error="i2c_read"))
        self.sequences[A]=100;self.sample(A)
        self.state.command(dict(action="recenter",request="not-ready"))
        self.assertEqual(self.state.last_init["reason"],"no_samples")

    def test_board_reboot_recovers_even_after_initial_three_seconds(self):
        self.sample(A);self.state.devices[A].last_seq=50000;self.state.devices[A].last_ms=1000000
        self.assertTrue(self.state.ingest("PORT_A",dict(v=1,kind="hello",id=A,board="ESP32",pins=[21,22],boot=12345)))
        self.assertEqual(self.state.devices[A].last_seq,-1)
        self.assertTrue(self.state.ingest("PORT_A",dict(v=1,id=A,seq=1,ms=5000,ok=True,roll=0,pitch=0,a=[0,0,1],g=[0,0,0])))
        self.assertTrue(self.state.snapshot()["players"][0]["connected"])

if __name__=="__main__":unittest.main()
