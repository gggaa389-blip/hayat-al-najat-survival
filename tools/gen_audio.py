#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""يولّد صوت محرك حلقي (WAV) للمركبات + أصوات مساعدة للمرحلة الثالثة."""
import numpy as np, wave, os, struct

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")
os.makedirs(OUT, exist_ok=True)
SR = 22050

def save_wav(name, data, sr=SR):
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(data, -1, 1) * 32767).astype("<i2").tobytes())
    print("saved", path, "%.1fKB" % (os.path.getsize(path) / 1024))

def loopable(freq_base, dur, harmonics, noise_amt, mod_hz):
    """نغمة محرك: توافقيات + ضجيج مُنمذج + نبض"""
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for h, amp in harmonics:
        # تأطير التوافقيات على عدد صحيح من الدورات لضمان التكرار السلس
        f = freq_base * h
        cycles = round(f * dur)
        sig += amp * np.sin(2 * np.pi * cycles * t / dur)
    rng = np.random.default_rng(7)
    noise = rng.normal(0, 1, n)
    # تنعيم الضجيج بشكل دوري (لتبقى الحلقة سلسة)
    k = 200
    kernel = np.ones(k) / k
    noise = np.convolve(np.concatenate([noise[-k:], noise, noise[:k]]), kernel, mode="same")[k:-k]
    noise *= noise_amt
    # نبض RPM
    pm = 1.0 + 0.22 * np.sin(2 * np.pi * round(mod_hz * dur) * t / dur)
    sig = (sig + noise) * pm
    sig /= np.max(np.abs(sig)) + 1e-9
    return sig * 0.85

# محرك السيارة/الشاحنة (حلقة 2 ث)
engine = loopable(60, 2.0, [(1, 1.0), (2, 0.55), (3, 0.35), (4, 0.22), (6, 0.12)], 0.28, 13.0)
save_wav("engine_loop.wav", engine)

# احتكاك/انزلاق الإطارات (قصير)
n = int(SR * 0.7)
t = np.arange(n) / SR
skid = np.random.default_rng(3).normal(0, 1, n) * np.exp(-t * 4.0)
skid *= 0.5 * (1 + np.sin(2 * np.pi * 220 * t))
save_wav("tire_skid.wav", skid / (np.max(np.abs(skid)) + 1e-9) * 0.7)

# تعبئة الوقود (نقرات/صفير قصير)
n = int(SR * 0.5)
t = np.arange(n) / SR
beep = np.sin(2 * np.pi * 880 * t) * np.exp(-t * 8) * 0.5 + np.sin(2 * np.pi * 1320 * t) * np.exp(-t * 12) * 0.3
save_wav("refuel.wav", beep)

# باب/ركوب ونزول (قفزة ميكانيكية قصيرة)
n = int(SR * 0.35)
t = np.arange(n) / SR
clunk = np.sin(2 * np.pi * 140 * t) * np.exp(-t * 18) * 0.8 + np.random.default_rng(5).normal(0, 1, n) * np.exp(-t * 30) * 0.35
save_wav("vehicle_enter.wav", clunk / (np.max(np.abs(clunk)) + 1e-9) * 0.7)
print("DONE")

# ============================================================
# أصوات المرحلة الخامسة
# ============================================================
rng5 = np.random.default_rng(2026)

# طلقة بندقية: دوي حاد + اضمحلال سريع + قاع منخفض
n = int(SR * 0.45)
t = np.arange(n) / SR
boom = rng5.normal(0, 1, n) * np.exp(-t * 18.0)
thump = np.sin(2 * np.pi * 70 * t) * np.exp(-t * 9.0) * 0.9
crack = np.sin(2 * np.pi * 1800 * t) * np.exp(-t * 60.0) * 0.5
gunshot = (boom * 0.9 + thump + crack)
save_wav("gunshot.wav", gunshot / (np.max(np.abs(gunshot)) + 1e-9) * 0.95)

# خطوة قدم: نقرة ضجيج قصيرة منخفضة
n = int(SR * 0.12)
t = np.arange(n) / SR
step = rng5.normal(0, 1, n) * np.exp(-t * 30.0)
step = np.convolve(step, np.ones(6) / 6, mode="same")  # تنعيم (تكرر أقل حدة)
step += np.sin(2 * np.pi * 160 * t) * np.exp(-t * 25.0) * 0.35
save_wav("footstep.wav", step / (np.max(np.abs(step)) + 1e-9) * 0.5)

# صياح حيوان: نغمة متحولة + همس ضجيج
n = int(SR * 0.9)
t = np.arange(n) / SR
f_sweep = 320 + 190 * np.sin(2 * np.pi * 1.6 * t)
phase = np.cumsum(2 * np.pi * f_sweep / SR)
cry = np.sin(phase) * np.exp(-t * 2.2) * 0.7
cry += rng5.normal(0, 1, n) * np.exp(-t * 6.0) * 0.12
cry *= 1.0 + 0.12 * np.sin(2 * np.pi * 7.0 * t)
save_wav("animal_cry.wav", cry / (np.max(np.abs(cry)) + 1e-9) * 0.7)

# رش ماء: ضجيج مفكك + فقاعات
n = int(SR * 0.8)
t = np.arange(n) / SR
splash = rng5.normal(0, 1, n) * np.exp(-t * 5.0)
splash = np.convolve(splash, np.ones(10) / 10, mode="same")
for f in (520, 680, 430):
    splash += np.sin(2 * np.pi * f * t + rng5.random() * 6) * np.exp(-t * 7.0) * 0.18
save_wav("water_splash.wav", splash / (np.max(np.abs(splash)) + 1e-9) * 0.65)

# مطر حلقة: ضجيج أبيض مُنمذج بدورة سلسة
n = int(SR * 2.0)
rain = rng5.normal(0, 1, n)
rain = np.convolve(np.concatenate([rain[-400:], rain, rain[:400]]), np.ones(40) / 40, mode="same")[400:-400]
rain += rng5.normal(0, 1, n) * 0.25
rain = np.convolve(np.concatenate([rain[-80:], rain, rain[:80]]), np.ones(8) / 8, mode="same")[80:-80]
save_wav("rain_loop.wav", rain / (np.max(np.abs(rain)) + 1e-9) * 0.5)

# نقرة واجهة: صفير قصير نقي
n = int(SR * 0.07)
t = np.arange(n) / SR
click = np.sin(2 * np.pi * 980 * t) * np.exp(-t * 40.0)
save_wav("ui_click.wav", click * 0.55)

print("== gen_audio: المرحلة 5 مكتملة ==")
