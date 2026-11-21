# TSP scripts — Keithley 2450 SourceMeter

Lua (TSP) measurement scripts for a **Keithley 2450 SourceMeter**, used to
characterise memristive and ferroelectric devices: DC and pulsed I-V,
synaptic plasticity (LTP/LTD, STDP, PPF), neuron-like dynamics, and the
leakage and tunnelling measurements that go with them.

Device under test in most of these: **Mo / Hf(Sr,Ti)O₂ / TiN** on Si.

---

## Working with TSP Lua in VS Code

Install the **[TSP Toolkit extension for Visual Studio Code](https://www.tek.com/en/datasheet/tsp-toolkit-visual-studio-code-extension)**
from Tektronix/Keithley. It gives you:

- autocomplete and inline help for the whole `smu.*`, `buffer.*`,
  `trigger.*` command set, driven by the instrument libraries it ships
- syntax checking against the instrument's own Lua dialect
- a terminal that connects straight to the 2450 over USB or LAN, so you can
  send a script and watch its `print()` output without any other software

`.vscode/settings.json` here is already configured for it — it points the
Lua language server at the 2450 command libraries and declares the TSP-Link
node layout. If autocomplete stops working, the paths in
`Lua.workspace.library` are the first thing to check: they contain the
extension's version number and go stale when it updates.

### Running a script

1. Connect the 2450 over USB. It appears as
   `USB0::0x05E6::0x2450::<serial>::INSTR`.
2. Open the script, then **TSP: Connect** from the command palette and pick
   the instrument.
3. Send the file to the instrument and run it. Anything the script
   `print()`s comes back in the terminal; that is how most of these report
   their data.

---

## Two things that will bite you

**TSP runs Lua 5.0, not 5.1.** The `%` modulo operator does not exist — it
was added in Lua 5.1. Use `math.mod(a, b)` or
`a - math.floor(a / b) * b` instead. This fails at *compile* time on the
instrument, so a script using `%` never starts at all.

**`io.*` and `file.*` are different things.** `io.open` writes to the
controlling PC through the TSP Toolkit terminal; `file.open` writes to a USB
stick in the instrument's front panel. Most scripts here use `io`, so the
data arrives on whichever machine is running VS Code.

---

## Layout

| folder | what is in it |
|---|---|
| `00-setup/` | reset the SMU, check probe contact, four-wire configuration |
| `01-iv-characterisation/` | DC and pulsed I-V sweeps, from a basic sweep to multi-range cycling |
| `02-synapse/` | potentiation and depression, multilevel states, STDP, paired-pulse facilitation |
| `03-neuron/` | leaky integrate-and-fire, Hodgkin–Huxley-inspired, refractory period |
| `04-materials/` | leakage, insulation resistance, tunnelling transport, FET I-V |
| `05-suites/` | all-in-one scripts that run a full characterisation in one go |
| `archive/` | earlier iterations kept for reference; not maintained |

### `00-setup`

| script | what it does |
|---|---|
| `contact-check-2wire.tsp` | apply a small bias and confirm the probes are landed; two-wire |
| `contact-check-4wire.tsp` | the same check in four-wire (Kelvin) sense |

Both compare the measured current against a `min_threshold` and report a bad
contact rather than letting you measure an open circuit all afternoon.
There is no plain reset script: every script here calls `reset()` on its
first line.

### `01-iv-characterisation`

| script | what it does |
|---|---|
| `dc-sweep-basic.tsp` | the simplest working DC sweep; start here |
| `dual-sweep.tsp` | 0 → +V → 0 → −V → 0 |
| `triple-phase-dual-sweep.tsp` | dual sweeps at three voltage ranges, logging straight to the PC |
| `multi-range-dual-sweep.tsp` | several ranges in one run |
| `multi-range-dual-sweep-cycles.tsp` | the same, repeated for *n* cycles |
| `ultralow-current-sweep.tsp` | for devices in the high-resistance state |
| `low-voltage-sweep.tsp` | sub-coercive sweeps |
| `interactive-sweep.tsp` | prompts for parameters, writes to a USB stick |
| `pulsed-iv.tsp` | 10 ms pulsed I-V over a fixed voltage sequence |
| `pulse-train-trigger-model.tsp` | a pulse train built from trigger-model blocks rather than a software loop -- the instrument runs it unattended |
| `dc-sweep-primary.tsp`, `nvm-sweep.tsp` | non-volatile memory sweep patterns |
| `smart-scan-short-characterisation.tsp` | high-resolution short-device characterisation |
| `memristor-sweep-error-protected.tsp` | two-wire rear-terminal sweep with error handling |

### `02-synapse`

| script | what it does |
|---|---|
| `ltp-ltd-rear-terminal.tsp` | potentiation/depression trains with data saving |
| `potentiation-depression-protocol.tsp` | the basic protocol |
| `potentiation-depression-multicycle.tsp` | repeated cycles |
| `potentiation-depression-full.tsp` | the longest version, with analysis |
| `potentiation-32-state-retention.tsp` | 32 conductance states, 10 s retention per state |
| `ltp-stp-multistate.tsp` | long- and short-term plasticity in one run |
| `conductance-linearity.tsp` | how linear the weight update is |
| `paired-pulse-facilitation.tsp` | PPF against pulse interval |
| `stdp.tsp`, `stdp-extended.tsp` | spike-timing-dependent plasticity |

### `03-neuron`

| script | what it does |
|---|---|
| `leaky-integrate-and-fire.tsp` | LIF dynamics from a threshold-switching device |
| `hodgkin-huxley-inspired.tsp` | Hodgkin–Huxley-style excitability |
| `refractory-period.tsp` | recovery time after firing |

### `04-materials`

| script | what it does |
|---|---|
| `leakage-current.tsp` | leakage at fixed bias |
| `insulation-resistance.tsp` | insulation resistance |
| `low-resistance-100-readings.tsp` | 100 low-resistance readings, sourcing current |
| `tunnelling-transport.tsp` | tunnelling transport study |
| `fet-iv-characteristics.tsp` | FET I-V, uses TSP-Link with a second instrument |

### `05-suites`

Run a whole characterisation unattended. Read the configuration block at the
top of each before using it — they apply a lot of stress to a device.

| script | what it does |
|---|---|
| `hzo-characterisation-suite.tsp` | the full HZO memristor suite |
| `memristor-suite-rear-terminal.tsp` | rear-terminal variant |
| `hsto-memristor-suite.tsp` | Hf(Sr,Ti)O₂ synapse suite |
| `hzo-ferroelectric-neuromorphic-suite.tsp` | ferroelectric + neuromorphic combined |
| `hsto-laptop-capture-suite.tsp` | logs to the PC rather than a USB stick |

---

## Before you run anything

Set the **current compliance** for the device, not for the measurement you
hope to get. These scripts drive real voltage into a real stack, and a
forming step is not reversible.

Check which terminals a script selects — several switch to the **rear**
terminals in their first lines, and a script expecting rear terminals while
your probes are on the front measures an open circuit.

The suites in `05-suites/` cycle devices thousands of times. Run them on a
device you are prepared to wear out.
