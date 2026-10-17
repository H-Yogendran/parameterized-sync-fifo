@echo off
rem Runs the self-checking testbench on every WIDTH:DEPTH configuration.
rem The testbench calls $fatal on failure, so vvp exits non-zero and this
rem script reports VERIFICATION FAILED.
setlocal enabledelayedexpansion
cd /d "%~dp0.."

echo ========================================
echo   Sync FIFO automated verification
echo ========================================

if not exist build mkdir build

for %%C in (8:4 8:2 8:3 8:5 8:16 16:16 32:33) do (
    for /f "tokens=1,2 delims=:" %%A in ("%%C") do (
        echo.
        echo === WIDTH=%%A DEPTH=%%B ===
        if not exist build\w%%A_d%%B mkdir build\w%%A_d%%B
        iverilog -g2012 -Wall -o build\w%%A_d%%B\sim.vvp -s sync_fifo_tb -Psync_fifo_tb.WIDTH=%%A -Psync_fifo_tb.DEPTH=%%B rtl\sync_fifo.v tb\sync_fifo_tb.v
        if errorlevel 1 goto :fail
        pushd build\w%%A_d%%B
        vvp -n sim.vvp
        if errorlevel 1 ( popd & goto :fail )
        popd
    )
)

echo.
echo ========================================
echo   ALL CONFIGURATIONS PASSED
echo ========================================
exit /b 0

:fail
echo.
echo ========================================
echo   VERIFICATION FAILED
echo ========================================
exit /b 1
