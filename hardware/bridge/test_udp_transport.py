"""Inject the observed Windows 10054 error; no serial hardware is opened."""
import json
import socket
import sys
import threading
import time
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import Mock, patch

import bridge


def windows_reset(code=10054):
    error = ConnectionResetError("Windows UDP destination is not listening")
    error.winerror = code
    return error


class UdpTransportTest(unittest.TestCase):
    def test_commands_resume_after_windows_peer_reset(self):
        udp = Mock()
        udp.recvfrom.side_effect = [
            windows_reset(),
            (b'{"action":"mode","mode":"sensor"}', ("127.0.0.1", 1234)),
            BlockingIOError(),
        ]
        self.assertEqual(bridge.receive_commands(udp), [{"action":"mode", "mode":"sensor"}])

    def test_repeated_resets_cannot_block_sensor_processing(self):
        udp = Mock()
        udp.recvfrom.side_effect = windows_reset()
        self.assertEqual(bridge.receive_commands(udp), [])
        self.assertEqual(udp.recvfrom.call_count, 64)

    def test_unrelated_receive_errors_are_not_silenced(self):
        for error in (windows_reset(10053), PermissionError("denied"), ConnectionResetError("not Windows 10054")):
            with self.subTest(error=repr(error)):
                udp = Mock()
                udp.recvfrom.side_effect = error
                with self.assertRaises(type(error)):
                    bridge.receive_commands(udp)

    def test_loopback_and_packet_validation_still_apply(self):
        udp = Mock()
        udp.recvfrom.side_effect = [
            (b'{"action":"mode"}', ("192.0.2.1", 1234)),
            (b"x" * 4096, ("127.0.0.1", 1234)),
            (b"invalid json", ("127.0.0.1", 1234)),
            (b"[]", ("127.0.0.1", 1234)),
            (b'{"action":"recenter","request":"check"}', ("127.0.0.1", 1234)),
            BlockingIOError(),
        ]
        self.assertEqual(bridge.receive_commands(udp), [{"action":"recenter", "request":"check"}])

    def test_send_recovers_when_game_reopens(self):
        udp = Mock()
        udp.sendto.side_effect = [windows_reset(), 20]
        self.assertFalse(bridge.send_snapshot(udp, {"seq": 1}, 6171))
        self.assertTrue(bridge.send_snapshot(udp, {"seq": 2}, 6171))
        self.assertEqual(json.loads(udp.sendto.call_args.args[0]), {"seq": 2})
        self.assertEqual(udp.sendto.call_args.args[1], ("127.0.0.1", 6171))

    def test_unrelated_send_errors_are_not_silenced(self):
        udp = Mock()
        udp.sendto.side_effect = PermissionError("denied")
        with self.assertRaises(PermissionError):
            bridge.send_snapshot(udp, {}, 6171)

    def test_main_survives_reset_and_delayed_game_listener(self):
        real_socket = socket.socket
        receiver = real_socket(socket.AF_INET, socket.SOCK_DGRAM)
        receiver.bind(("127.0.0.1", 0))
        game_port = receiver.getsockname()[1]
        receiver.close()  # Godot has not opened its receiving port yet.
        probe = real_socket(socket.AF_INET, socket.SOCK_DGRAM)
        probe.bind(("127.0.0.1", 0))
        command_port = probe.getsockname()[1]
        probe.close()
        ready = threading.Event()
        failures = []

        class ResetOnce:
            def __init__(self, *args, **kwargs):
                self.socket = real_socket(*args, **kwargs)
                self.reset = False

            def __getattr__(self, name):
                return getattr(self.socket, name)

            def sendto(self, *args):
                result = self.socket.sendto(*args)
                ready.set()
                return result

            def recvfrom(self, *args):
                if ready.is_set() and not self.reset:
                    self.reset = True
                    raise windows_reset()
                return self.socket.recvfrom(*args)

        def run():
            try:
                bridge.main()
            except BaseException as exc:
                failures.append(exc)

        with TemporaryDirectory() as folder:
            argv = ["bridge.py", "--config", str(Path(folder) / "settings.json"),
                    "--udp-port", str(game_port), "--command-port", str(command_port),
                    "--duration", "0.8", "--no-console"]
            with patch.object(sys, "argv", argv), patch("bridge.socket.socket", ResetOnce), \
                    patch("serial.tools.list_ports.comports", return_value=[]), patch("builtins.print"):
                thread = threading.Thread(target=run, daemon=True)
                thread.start()
                try:
                    self.assertTrue(ready.wait(1), "bridge sends while Godot is absent")
                    time.sleep(0.1)
                    self.assertTrue(thread.is_alive(), "10054 does not terminate the bridge")
                    receiver = real_socket(socket.AF_INET, socket.SOCK_DGRAM)
                    receiver.bind(("127.0.0.1", game_port))
                    receiver.settimeout(1)
                    try:
                        receiver.sendto(b'{"action":"mode","mode":"sensor"}', ("127.0.0.1", command_port))
                        until = time.monotonic() + 1
                        mode = ""
                        while time.monotonic() < until and mode != "sensor":
                            mode = json.loads(receiver.recvfrom(4096)[0])["mode"]
                        self.assertEqual(mode, "sensor", "real UDP commands and snapshots resume")
                    finally:
                        receiver.close()
                finally:
                    thread.join(2)
        self.assertEqual(failures, [])
        self.assertFalse(thread.is_alive())


if __name__ == "__main__":
    unittest.main()
