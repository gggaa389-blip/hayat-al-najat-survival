#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""يولّد خريطة التحكم (control map) لـ Terrain3D من splat.raw
الصيغة (uint32 لكل بكسل):
  base_id (5 bits) << 27 | overlay(5) << 22 | blend(8) << 14 | angle(4) << 10
  | uv_scale(3) << 7 | hole(1) << 2 | nav(1) << 1 | autoshader(1)
"""
import numpy as np, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N = 1536
splat = np.fromfile(os.path.join(ROOT, "data", "splat.raw"), dtype=np.uint8).reshape(N, N).astype(np.uint32)
# base id من splat، autoshader=1 دائماً، uv_scale=7 (×1.0)
ctrl = (splat & 0x1F) << 27
ctrl |= (7 & 0x7) << 7
ctrl |= 1  # autoshader on
ctrl.astype("<u4").tofile(os.path.join(ROOT, "data", "control.raw"))
print("control.raw OK — عينة:", ctrl[N//2, N//2], hex(int(ctrl[N//2, N//2])))
