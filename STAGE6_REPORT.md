# Stage 6 — Multiplayer + APK Export — ✅ COMPLETE

Date: 2026-10-17 | Tests: `test_network.gd` **27/27 PASS** + **two-process ENet integration verified** | APK: `builds/survival_game.apk` (45.7 MB)

## 1. Multiplayer (ENet LAN — friend mode)

`scripts/network/network_manager.gd` (autoload-ish node in Main.tscn, group `network`):
- `host_game(port=47231) -> bool` / `join_game(ip)` / `leave_game()` / `my_id()` (host = 1)
- Peer connect/disconnect → spawns/despawns `RemotePlayer` (layer 32, floating name label)
- 8 Hz position + animation-name sync via `rpc("rpc_state", ...)` (any_peer)
- Signals: `connected_to_game, disconnected_from_game, peer_joined, peer_left, net_message`

`scripts/network/remote_player.gd` — CharacterBody3D (ray-visible, layer 32), `apply_state()`, `on_hit(dmg)`, `set_display_name()`, `is_remote_player() -> true`.

### Combat & the friend-kill rule
- Player shotgun ray mask `1 | 8 | 32` — hits remote players for 34 dmg (3 pellets → 3 hits kill, same as animals)
- Vehicle run-over: `vehicle.gd` physics scan (r 1.6) → `check_run_over()` → detects ANY remote player
- `report_attack(target_peer_id, damage, instant_kill)` → RPC `apply_attack` on the victim's peer
- **friend-killed rule (محقق بالكامل):** victim `money += 1000` + respawn WITHOUT the −1000 death penalty + health reset; killer `money -= 1000`; both sides get HUD notifications (`friend_payment` signal for balance UIs)
- The rule fires whether the kill is by gunshot OR vehicle run-over — locally and over the network

### Loans between friends
- `request_loan_networked(amount)` → target peer gets `loan_request_received(name, amount)` → HUD Arabic loan prompt (موافقة/رفض)
- `respond_to_loan(approve)` → RPC back: **approve** = lender −amount / borrower +amount (`loan_response_received`), deny = message only
- `friend_approves_loan/friend_denies_loan` (single-player friend) untouched and re-tested
- HUD: 📡 شبكة button → panel (host name / IP + join) / leave; loan prompt panel

### Integration verification (two real OS processes)
`tools/net_host.gd` + `tools/net_join.gd` run concurrently (ENet port 47292):
```
HOST:   LOAN_REQUEST  TESTER  700
HOST:   LOAN_APPROVED
HOST:   PAYMENT victim=58349272  amount=1000  (victim money 1500→2500)
CLIENT: LOAN_OK  (client money 1500→2200)
CLIENT: PAYMENT_OK  (client money 2200→1200)
```
Real ENet traffic — join, state sync, loan RPCs, kill payment RPC all verified across processes.

## 2. APK Export — REAL `.apk` produced

| Item | Value |
|---|---|
| File | `builds/survival_game.apk` (+ `.idsig`) |
| Size | **45.7 MB** |
| Package | `com.arena.survivalgame` v1.0 |
| Label | **حياة النجاة** |
| ABI | arm64-v8a (arm64 devices) |
| Min SDK | 24 (Android 7.0+) |
| Permissions | INTERNET (multiplayer) |
| Orientation | landscape, fullscreen immersive |
| Native libs | `libgodot_android.so` + `libterrain.android.debug.arm64.so` ✓ |

### Toolchain (all in workspace, reusable)
- JDK 17: `/home/user/jdk/jdk17` (`JAVA_HOME`)
- Android SDK: `/home/user/android/sdk` (platform-tools, platforms;android-34, build-tools;34.0.0)
- Godot export templates 4.6.3: `~/.local/share/godot/export_templates/4.6.3.stable/`
- Debug keystore: `~/.android/debug.keystore` (alias `androiddebugkey`, pass `android`)
- **Editor settings live at `~/.config/godot/editor_settings-4.6.tres`** — `export/android/android_sdk_path` + `export/android/java_sdk_path` MUST point at the two toolchain dirs (a wrong `Android/Sdk` default breaks export with "Unable to find build-tools").

### Re-export recipe
```bash
export JAVA_HOME=/home/user/jdk/jdk17 && export PATH=$JAVA_HOME/bin:$PATH
cd /home/user/survival_game
/home/user/godot/godot4 --headless --path . --export-debug "Android" builds/survival_game.apk
# signed with the debug keystore → installable via `adb install` / direct APK install
```

## 3. Multiplayer play instructions
1. Both phones on the SAME Wi-Fi network
2. Player 1: 📡 شبكة → استضافة | Player 2: 📡 شبكة → write host IP → انضمام
3. Friend appears with a floating name; both survive together:
   - shoot each other or run over with vehicles — the killer pays 1000 to the friend
   - loan requests pop a real approval dialog on the friend's screen

## 4. Known limitations (honest)
- LAN only (no internet matchmaking) — ENet direct IP; standard for this architecture
- Only the friend's transform syncs (8 Hz) — their vehicle visuals are not synced (they drive their own local vehicles)
- The truck cargo/fish economy is intentionally local per device (each player owns their own money)
- APK is a **debug-signed** build (installable on any device with "unknown sources" allowed); production release needs a release keystore + `--export-release`

## Files (new)
`scripts/network/network_manager.gd`, `scripts/network/remote_player.gd`, `tools/net_host.gd`, `tools/net_join.gd`, `tools/test_network.gd`, `tools/probe_mp.gd`, `export_presets.cfg`, `builds/survival_game.apk`
