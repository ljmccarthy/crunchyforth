@echo off

echo CrunchyForth for Win32 by Luke McCarthy
echo Assembling...
nasmw -f bin cf.win32.asm -o cf.exe
if %errorlevel% == 0 goto done

:fail
echo Failed to compile image.
pause
goto end

:done
echo Done.

:end
