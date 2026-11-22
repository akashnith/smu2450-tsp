# smu2450-tsp

**TSP-Lua scripts** for the **Keithley 2450 SourceMeter® SMU**. Scripts run on the instrument's Test Script Processor (TSP®), so sweeps, pulse sequences and triggered measurements execute with on-instrument timing instead of PC-limited command latency.

32 working scripts for **DC and pulsed I-V**, **resistive switching**, and the **synapse and neuron protocols that fit a millisecond timescale** -- kept as a **reference for the syntax**, so you can write your own for whatever you need to measure.

![TSP-Lua](https://img.shields.io/badge/TSP--Lua-on--instrument-blue) ![instrument](https://img.shields.io/badge/instrument-Keithley%202450-orange) ![scripts](https://img.shields.io/badge/scripts-32-blueviolet) ![reference](https://img.shields.io/badge/use-reference%20%2B%20runnable-informational) ![license](https://img.shields.io/badge/license-MIT-green)

Device under test in most of these: **Mo / Hf(Sr,Ti)O₂ / TiN** on Si.

### What a 2450 can and cannot measure here

It is a **DC source measure unit**. Everything in this repository is built
from stepping a level, waiting, and taking a reading, so the floor on any
pulse or interval is set by how fast the instrument can settle and measure
-- **a few milliseconds**. The shortest pulse used anywhere here is 5 ms;
most synapse and neuron protocols run at **10-20 ms**.

That is enough for resistive switching, conductance update, retention and
the slow end of neuron-like dynamics. It is **not** enough for:

- **Ferroelectric polarization measurements** -- P-V loops, PUND, switching
  speed. These need a fast triangular or pulse drive at kilohertz rates with
  the displacement current integrated over the ramp. A DC SMU cannot
  generate that waveform or integrate charge against it, so no script here
  attempts one. That work needs a dedicated ferroelectric tester, or a
  waveform generator and fast measurement unit such as a B1530A WGFMU.
- **Sub-microsecond switching kinetics**, for the same reason.

If a measurement needs an edge faster than a few milliseconds, it does not
belong on this instrument, and a script that appears to do it is really
measuring the SMU's own settling.

---

## What this is for

A **reference collection**, as much as a set of runnable measurements. Each
script is a worked example of the TSP-Lua idioms you need in order to write
your own: configuring source and measure functions, setting compliance,
choosing terminals, building loops and pulse trains, reading a value back,
and getting the data off the instrument.

Read two or three of these and you can write a script for almost any
measurement the 2450 is capable of. The grammar is small; what takes time is
knowing which `smu.*` attribute does what, and in what order they have to be
set. That is what these are here to show.

### Using them on other Keithley instruments

TSP is the scripting language across much of Keithley's range, so the
structure here carries over. **How much of the code carries over depends on
the family:**

| instrument | what transfers |
|---|---|
| **2450, 2460, 2461, 2470** touchscreen SourceMeters | Nearly all of it. These share the same `smu.source.*` / `smu.measure.*` command set, so most scripts run after changing only the voltage and current values. |
| **Series 2600B** SourceMeters | The language, the trigger-model concepts, the buffer handling and the script structure. **Not the command names** — the 2600B addresses channels as `smua.*` / `smub.*` with a different attribute set (`smua.source.levelv`, `smua.measure.i()`). |
| **DMM6500, DAQ6510, 3706A** | The same again: Lua, buffers, trigger model and the general shape of a script. Measurement commands live under `dmm.*` and there is no source, so sourcing scripts have no direct equivalent. |

Every one of these scripts uses only `smu.*`, `trigger.*` and `display.*`,
which is why the 2450/2460/2461/2470 family is close to a drop-in.

### The limits are not the same instrument to instrument

A script that is safe on one model can destroy a device on another. The 2450
is 200 V / 1 A / 20 W; the 2460 and 2461 trade voltage for current, and the
2470 goes to much higher voltage at lower current. Before running anything
here on a different model, check **both** against that instrument's
datasheet:

- the **voltage and current levels** the script sources, and
- the **compliance limit**, which is what actually protects the device.

A compliance value that is conservative on one model can be far above what
your device survives on another. Set it for the device, not for the
instrument.

---

## Instrument

| | |
|---|---|
| **Model** | Keithley 2450 Graphical SourceMeter® SMU (Tektronix / Keithley) |
| **Type** | 1-channel, 4-quadrant source measure unit, 200 V, 1 A, 20 W |
| **Resolution / accuracy** | 6½-digit, 0.012 % basic measure accuracy; 20 mV and 10 nA source/measure ranges |
| **Programming modes** | Native 2450 SCPI, 2400-compatible SCPI, and **TSP® scripting** (Lua-based) |
| **Interfaces** | USB, GPIB, Ethernet (LXI); TSP-Link® for multi-unit setups |
| **Triggering** | TriggerFlow, built-in trigger model and digital I/O |

The Test Script Processor lets complete test programs be stored in non-volatile memory and executed on the instrument, and keeps TSP-based legacy and multi-unit workflows possible through TSP-Link.

**Links**
- Keithley / Tektronix product family: <https://www.tek.com/keithley>
- TSP Toolkit for VS Code: <https://www.tek.com/en/datasheet/tsp-toolkit-visual-studio-code-extension>
- KickStart control software: <https://www.tek.com/en/products/keithley/keithley-control-software-bench-instruments/kickstart>
- Tektronix software & firmware downloads: <https://www.tek.com/en/products/software>
- 2450 Reference Manual (TSP command reference) and datasheet: search "2450" on the Tektronix Keithley page above.

---

## Requirements

- A Keithley 2450 with the command set set to **TSP** — front panel: *System → Settings → Command Set*. These scripts will not run under either SCPI mode.
- A connection by USB (USB-TMC), LAN or GPIB.
- **[TSP Toolkit for Visual Studio Code](https://www.tek.com/en/datasheet/tsp-toolkit-visual-studio-code-extension)** to edit and send them.

Nothing else. These are instrument-side scripts: there is no host program, no Python and no VISA layer to install. The instrument does the measuring and prints its results back to whatever terminal sent the script.

---

## Working in VS Code

The TSP Toolkit extension gives you autocomplete and inline help across the
whole `smu.*`, `buffer.*` and `trigger.*` command set, syntax checking
against the instrument's own Lua dialect, and a terminal that connects
directly to the 2450.

`.vscode/settings.json` here is already configured for it: it points the Lua
language server at the 2450 command libraries and declares the TSP-Link node
layout. If autocomplete stops working, check `Lua.workspace.library` first —
those paths contain the extension's version number and go stale when it
updates.

### Running a script

1. Connect the 2450. Over USB it appears as `USB0::0x05E6::0x2450::<serial>::INSTR`.
2. **TSP: Connect** from the command palette, then pick the instrument.
3. Send the open file to the instrument. Whatever the script `print()`s comes back in the terminal — that is how most of these return their data.

Without VS Code: copy a script to a USB drive and run it from the front panel, or paste it into KickStart's script editor.

---

## Two things that will bite you

**TSP runs Lua 5.0, not 5.1.** The `%` modulo operator does not exist — it
arrived in Lua 5.1. Use `math.mod(a, b)` or `a - math.floor(a / b) * b`.
This fails when the script is *compiled* on the instrument, so a script
using `%` never starts at all.

**`io.*` and `file.*` go to different places.** `io.open` writes to the
controlling PC through the TSP Toolkit terminal; `file.open` writes to a USB
stick in the instrument's front panel. Most scripts here use `io`, so the
data lands on whichever machine is running VS Code.

---

## What is here

```
smu2450-tsp/
├── 00-setup/                 contact checks, before you measure anything
├── 01-iv-characterisation/   DC and pulsed I-V
├── 02-synapse/               plasticity protocols
├── 03-neuron/                neuron-like dynamics
├── 04-suites/                unattended all-in-one runs
├── .vscode/settings.json     TSP Toolkit configuration
└── README.md
```

### `00-setup` — before anything else

| script | what it does |
|---|---|
| `contact-check-2wire.tsp` | apply a small bias, compare the current against a threshold, report a bad contact |
| `contact-check-4wire.tsp` | the same check in four-wire (Kelvin) sense |

Every script calls `reset()` on its first line, so there is no separate reset script.

### `01-iv-characterisation`

| script | what it does |
|---|---|
| `dc-sweep-basic.tsp` | the simplest working DC sweep; start here |
| `dual-sweep.tsp` | 0 → +V → 0 → −V → 0 |
| `triple-phase-dual-sweep.tsp` | dual sweeps at three voltage ranges, logging to a USB stick |
| `multi-range-dual-sweep.tsp` | several ranges in one run |
| `multi-range-dual-sweep-cycles.tsp` | the same, repeated for *n* cycles |
| `ultralow-current-sweep.tsp` | for devices in the high-resistance state |
| `low-voltage-sweep.tsp` | small-signal sweeps below the switching threshold, for reading state without disturbing it |
| `interactive-sweep.tsp` | prompts for parameters, writes to a USB stick |
| `pulsed-iv.tsp` | 10 ms pulses over a fixed voltage sequence |
| `pulse-train-trigger-model.tsp` | a pulse train built from trigger-model blocks rather than a software loop, so the instrument runs it unattended |
| `dc-sweep-primary.tsp`, `nvm-sweep.tsp` | non-volatile memory sweep patterns |
| `smart-scan-short-characterisation.tsp` | high-resolution short-device characterisation |
| `memristor-sweep-error-protected.tsp` | two-wire rear-terminal sweep with error handling, using `smu.source.sweeplinear` |

### `02-synapse`

| script | what it does |
|---|---|
| `ltp-ltd-rear-terminal.tsp` | potentiation/depression trains with data saving |
| `potentiation-depression-protocol.tsp` | the basic protocol |
| `potentiation-depression-multicycle.tsp` | repeated cycles |
| `potentiation-depression-full.tsp` | the longest version, with analysis |
| `potentiation-32-state-retention.tsp` | 32 conductance states, 10 s retention each |
| `ltp-stp-multistate.tsp` | long- and short-term plasticity in one run |
| `conductance-linearity.tsp` | how linear the weight update is |
| `paired-pulse-facilitation.tsp` | PPF against pulse interval |
| `stdp.tsp`, `stdp-extended.tsp` | spike-timing-dependent plasticity |

### `03-neuron`

| script | what it does |
|---|---|
| `leaky-integrate-and-fire.tsp` | LIF dynamics from a threshold-switching device |
| `hodgkin-huxley-inspired.tsp` | Hodgkin–Huxley-style excitability |
| `refractory-period.tsp` | recovery after firing, across a set of inter-stimulus intervals |

### `04-suites`

Run a whole characterisation unattended. Read the configuration block at the top of each before using it.

| script | what it does |
|---|---|
| `hzo-characterisation-suite.tsp` | I-V characterisation followed by potentiation and depression, in one run |
| `memristor-suite-rear-terminal.tsp` | rear-terminal variant |
| `hsto-memristor-suite.tsp` | Hf(Sr,Ti)O₂ synapse suite: switching, conductance update and retention |

---

## A script, end to end

`01-iv-characterisation/dc-sweep-basic.tsp`, trimmed:

```lua
reset()
smu.measure.terminals = smu.TERMINALS_REAR

smu.source.func         = smu.FUNC_DC_VOLTAGE
smu.source.autorange    = smu.ON
smu.source.ilimit.level = 1e-4            -- compliance: set this for the device
smu.measure.func        = smu.FUNC_DC_CURRENT
smu.measure.autorange   = smu.ON
smu.source.output       = smu.ON

for v = 0, 1.0, 0.1 do
    smu.source.level = v
    delay(0.01)
    local i = smu.measure.read()
    print(string.format("%.3f,%.6e", v, i))
end

smu.source.level  = 0
smu.source.output = smu.OFF
```

Parameter names follow the 2450 TSP command set; confirm against the Reference Manual for your firmware version.

---

## Safety

Set the source **limit** before enabling the output, and set it for the
device rather than for the measurement you hope to get. Forming is not
reversible.

Check which terminals a script selects. Most of these switch to the **rear**
terminals in their first lines, and a script expecting rear terminals while
your probes are on the front measures an open circuit.

Every script here ends by driving the source to zero and turning the output
off. Keep it that way: **a script running on the instrument keeps executing
if the PC disconnects.**

The suites in `04-suites/` cycle devices thousands of times. Run them on a
device you are prepared to wear out.

---

## Roadmap

- [ ] Pulse sequences with finer timing through TriggerFlow
- [ ] Multi-unit scripts over TSP-Link
- [ ] A PyVISA host layer to upload scripts, fetch buffers and save CSV
- [ ] Hooks so a GUI can launch these scripts directly

---

## AI assistance

Parts of this project were developed with help from AI tools (Google Gemini and Anthropic Claude) for initial scaffolding, debugging, and drafting this README.


## License

MIT. See `LICENSE`.

*Keithley, SourceMeter, TSP and TSP-Link are trademarks of Tektronix / Keithley Instruments. This project is independent and not affiliated with or endorsed by Tektronix.*
