"""Synthesise a friendly call for every animal in the game.

    .venv/Scripts/python.exe rainbow-sparkle-squad/tools/make_animal_sounds.py

Output: assets/audio/roar_<name>.wav, mono 22050 Hz 16-bit PCM. Covers Dino
Valley and the Safari Plains from one table - a lion and a T-rex want the same
synth with different numbers, not two scripts.

Why synthesised rather than spoken: SAPI can say "Tyrannosaurus" but it cannot
roar, and the roar is the whole reason a three-year-old walks up to an animal.
These are built from a pitch-swept growl plus filtered noise - not recordings,
but warm rumbles rather than screeches, which is the point. Nothing here is
meant to be frightening: this is a lion a small child is supposed to want to
walk towards.

Each call is pitched to its owner's SIZE, so the sound teaches the same thing
the models do - the elephant rumbles low, the zebra pipes high. That mapping is
why `base_hz` is per-animal rather than one shared voice.

These are the weakest asset in the project and worth knowing about: a synth
approximates a growl well and a whinny badly. The file names are the contract,
so real recordings drop straight in over them with no code change.
"""

import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "audio")

# name -> (base pitch Hz, duration s, growl rate Hz, brightness 0..1)
# Low and long for the heavy ones, short and bright for the small and the
# airborne. Brightness is how much breath-noise rides on the tone: a trumpet and
# a whinny are mostly air, a hippo grunt is almost none.
ROARS = {
    # Dino Valley
    "trex":        (78.0,  1.30, 22.0, 0.55),
    "triceratops": (110.0, 1.05, 18.0, 0.40),
    "stegosaurus": (128.0, 0.95, 15.0, 0.32),
    "pteranodon":  (430.0, 0.70, 34.0, 0.75),
    # Safari Plains
    "lion":        (92.0,  1.20, 20.0, 0.45),
    "elephant":    (165.0, 1.15, 11.0, 0.72),   # trumpet: bright and blaring
    "hippo":       (62.0,  0.85, 26.0, 0.22),   # the lowest grunt in the game
    "giraffe":     (150.0, 0.65, 12.0, 0.38),   # a soft short hum
    "zebra":       (330.0, 0.80, 30.0, 0.70),   # a high wavering whinny
}


def envelope(n: int, attack: float, release: float) -> np.ndarray:
    """Fast in, long out - a roar starts abruptly and dies away."""
    env = np.ones(n)
    a = max(int(n * attack), 1)
    r = max(int(n * release), 1)
    env[:a] = np.linspace(0.0, 1.0, a) ** 0.5
    env[-r:] = np.linspace(1.0, 0.0, r) ** 1.6
    return env


def roar(base_hz: float, seconds: float, growl_hz: float, bright: float,
         seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    n = int(SR * seconds)
    t = np.arange(n) / SR

    # Pitch swoops up then settles - that rise is what reads as a bellow rather
    # than a drone.
    sweep = 1.0 + 0.35 * np.sin(np.pi * np.clip(t / seconds, 0, 1)) \
        - 0.18 * (t / seconds)
    # Growl: a slow wobble on the frequency, the throaty part.
    wobble = 1.0 + 0.16 * np.sin(2 * np.pi * growl_hz * t)
    freq = base_hz * sweep * wobble
    phase = 2 * np.pi * np.cumsum(freq) / SR

    # Sawtooth-ish stack: a few harmonics rolled off, so it has body without
    # turning into a buzz.
    voice = np.zeros(n)
    for k, amp in ((1, 1.0), (2, 0.5), (3, 0.28), (4, 0.15), (5, 0.08)):
        voice += amp * np.sin(phase * k)
    voice /= 2.0

    # Breath: noise low-passed by a simple running mean, mixed in by brightness.
    noise = rng.normal(0.0, 1.0, n)
    width = max(int(SR / (base_hz * 4.0)), 2)
    kernel = np.ones(width) / width
    breath = np.convolve(noise, kernel, mode="same")
    breath /= (np.max(np.abs(breath)) or 1.0)

    out = (1.0 - bright * 0.5) * voice + bright * 0.45 * breath
    out *= envelope(n, 0.05, 0.55)

    peak = np.max(np.abs(out)) or 1.0
    return (out / peak) * 0.85


def write_wav(path: str, samples: np.ndarray) -> None:
    pcm = np.clip(samples, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote %s (%.2fs)" % (path, len(samples) / SR))


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    for i, (name, (hz, secs, growl, bright)) in enumerate(ROARS.items()):
        samples = roar(hz, secs, growl, bright, seed=4200 + i)
        write_wav(os.path.join(OUT, "roar_%s.wav" % name), samples)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
