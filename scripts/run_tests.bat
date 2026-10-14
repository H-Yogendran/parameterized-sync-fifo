@echo off
setlocal
cd /d "%~dp0.."

echo ========================================
echo   Sync FIFO automated verification
echo ========================================
echo.

if not exist build mkdir build

echo [1/2] Running main self-checking testbench...
iverilog -o build\fifo_sim rtl\sync_fifo.v tb\sync_fifo_tb.v
if errorlevel 1 goto :fail
vvp build\fifo_sim
if errorlevel 1 goto :fail

echo.
echo [2/2] Running parameterization smoke test...
iverilog -o build\parameter_smoke rtl\sync_fifo.v tb\parameter_smoke_tb.v
if errorlevel 1 goto :fail
vvp build\parameter_smoke
if errorlevel 1 goto :fail

echo.
echo ========================================
echo   ALL AUTOMATED TESTS PASSED
echo ========================================
exit /b 0

:fail
echo.
echo ========================================
echo   VERIFICATION FAILED
echo ========================================
exit /b 1
