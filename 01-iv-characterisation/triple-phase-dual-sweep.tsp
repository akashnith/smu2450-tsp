-- SMU 2450: Triple-Phase Dual-Sweep I-V Measurement
-- Dual sweeps: 0→V→0→-V→0 for three voltage ranges
-- Direct USB data logging without buffering

reset()
errorqueue.clear()

-- CONFIGURATION

-- USB file paths (modify as needed)
local file_phase1 = "/usb1/phase1_ultralow.csv"
local file_phase2 = "/usb1/phase2_standard.csv"
local file_phase3 = "/usb1/phase3_highvoltage.csv"

-- Phase 1: Ultra-Low Voltage (±1mV, ±5mV)
local phase1_ranges = {
    {vstart = 0, vstop = 0.001, compliance = 50e-6},   -- 0 → +1mV
    {vstart = 0.001, vstop = 0, compliance = 50e-6},   -- +1mV → 0
    {vstart = 0, vstop = -0.001, compliance = 50e-6},  -- 0 → -1mV
    {vstart = -0.001, vstop = 0, compliance = 50e-6},  -- -1mV → 0
    {vstart = 0, vstop = 0.005, compliance = 50e-6},   -- 0 → +5mV
    {vstart = 0.005, vstop = 0, compliance = 50e-6},   -- +5mV → 0
    {vstart = 0, vstop = -0.005, compliance = 50e-6},  -- 0 → -5mV
    {vstart = -0.005, vstop = 0, compliance = 50e-6}   -- -5mV → 0
}

-- Phase 2: Standard Range (±5mV to ±1.5V)
local phase2_ranges = {
    {vstart = 0, vstop = 0.005, compliance = 100e-6},   -- 0 → +5mV
    {vstart = 0.005, vstop = 1.5, compliance = 100e-6}, -- +5mV → +1.5V
    {vstart = 1.5, vstop = 0, compliance = 100e-6},     -- +1.5V → 0
    {vstart = 0, vstop = -0.005, compliance = 100e-6},  -- 0 → -5mV
    {vstart = -0.005, vstop = -1.5, compliance = 100e-6}, -- -5mV → -1.5V
    {vstart = -1.5, vstop = 0, compliance = 100e-6}     -- -1.5V → 0
}

-- Phase 3: High Voltage Only (±100mV to ±1.5V)
local phase3_ranges = {
    {vstart = 0, vstop = 0.1, compliance = 500e-6},     -- 0 → +100mV
    {vstart = 0.1, vstop = 1.5, compliance = 500e-6},   -- +100mV → +1.5V
    {vstart = 1.5, vstop = 0, compliance = 500e-6},     -- +1.5V → 0
    {vstart = 0, vstop = -0.1, compliance = 500e-6},    -- 0 → -100mV
    {vstart = -0.1, vstop = -1.5, compliance = 500e-6}, -- -100mV → -1.5V
    {vstart = -1.5, vstop = 0, compliance = 500e-6}     -- -1.5V → 0
}

-- Sweep parameters
local num_points = 101  -- Points per sweep segment
local delay = 0.01      -- 10ms delay between points

-- HELPER FUNCTIONS

-- Open file and write CSV header
local function open_file(filepath)
    local filenum = file.open(filepath, file.MODE_WRITE)
    if filenum == nil then
        print("ERROR: Cannot open file " .. filepath)
        return nil
    end
    -- Write CSV header
    file.write(filenum, "Sweep_Num,Point,Voltage_Set(V),Voltage_Meas(V),Current(A),Resistance(Ohm),Compliance,Timestamp\n")
    return filenum
end

-- Perform single sweep and log data directly to USB
local function perform_sweep(filenum, sweep_num, vstart, vstop, compliance)
    -- Configure SMU
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.source.ilimit.level = compliance
    smu.source.readback = smu.ON
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.measure.nplc = 1
    
    -- Calculate voltage step
    local vstep = (vstop - vstart) / (num_points - 1)
    
    -- Turn output ON
    smu.source.output = smu.ON
    
    -- Perform sweep
    for i = 1, num_points do
        local vset = vstart + (i - 1) * vstep
        
        -- Set voltage
        smu.source.level = vset
        
        -- Wait for settling
        delay(delay)
        
        -- Measure
        local vmeas = smu.measure.readwithtime()
        local imeas = smu.measure.read()
        local timestamp = os.time()
        
        -- Calculate resistance
        local resistance = "N/A"
        if math.abs(imeas) > 1e-12 then
            resistance = string.format("%.6e", vmeas / imeas)
        end
        
        -- Check compliance
        local in_compliance = "No"
        if smu.source.compliance then
            in_compliance = "Yes"
        end
        
        -- Write data directly to file
        local data_line = string.format("%d,%d,%.6e,%.6e,%.6e,%s,%s,%d\n",
            sweep_num, i, vset, vmeas, imeas, resistance, in_compliance, timestamp)
        file.write(filenum, data_line)
        
        -- Optional: Print progress every 20 points
        local remainder = i - math.floor(i / 20) * 20
        if remainder == 0 or i == 1 or i == num_points then
            print(string.format("Sweep %d: Point %d/%d, V=%.4e V, I=%.4e A", 
                sweep_num, i, num_points, vmeas, imeas))
        end
    end
    
    -- Turn output OFF after sweep
    smu.source.output = smu.OFF
end

-- Execute a phase with multiple sweeps
local function execute_phase(phase_name, sweep_configs, filepath)
    print("========================================")
    print("Starting " .. phase_name)
    print("File: " .. filepath)
    print("========================================")
    
    -- Open file
    local filenum = open_file(filepath)
    if filenum == nil then
        return false
    end
    
    -- Execute all sweeps in this phase
    for sweep_num, config in ipairs(sweep_configs) do
        print(string.format("\nSweep %d: %.3e V → %.3e V (Compliance: %.2e A)", 
            sweep_num, config.vstart, config.vstop, config.compliance))
        
        perform_sweep(filenum, sweep_num, config.vstart, config.vstop, config.compliance)
        
        -- Brief pause between sweeps
        delay(0.5)
    end
    
    -- Close file
    file.close(filenum)
    print("\n" .. phase_name .. " completed!")
    print("Data saved to: " .. filepath)
    
    return true
end

-- MAIN EXECUTION

print("========================================")
print("SMU 2450: Triple-Phase Dual-Sweep")
print("========================================")
print("Phase 1: Ultra-Low (±1mV, ±5mV)")
print("Phase 2: Standard (±5mV to ±1.5V)")
print("Phase 3: High Voltage (±100mV to ±1.5V)")
print("========================================\n")

-- Check USB availability
if not file.usbdriveexists() then
    print("ERROR: USB drive not detected!")
    print("Please insert USB drive and try again.")
else
    -- Execute all three phases
    local success = true
    
    success = execute_phase("PHASE 1: Ultra-Low Voltage", phase1_ranges, file_phase1)
    if success then
        delay(2)  -- Pause between phases
        success = execute_phase("PHASE 2: Standard Range", phase2_ranges, file_phase2)
    end
    if success then
        delay(2)
        success = execute_phase("PHASE 3: High Voltage", phase3_ranges, file_phase3)
    end
    
    -- Final summary
    if success then
        print("\n========================================")
        print("ALL MEASUREMENTS COMPLETED SUCCESSFULLY")
        print("========================================")
        print("Phase 1 data: " .. file_phase1)
        print("Phase 2 data: " .. file_phase2)
        print("Phase 3 data: " .. file_phase3)
        print("========================================")
    else
        print("\nMeasurement terminated due to errors.")
    end
end

-- Ensure output is OFF
smu.source.output = smu.OFF
print("\nOutput turned OFF. Measurement complete.")