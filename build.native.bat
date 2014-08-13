@echo off

echo CrunchyForth by Luke McCarthy
echo Assembling...
nasmw -f bin cf.native.asm -o cf.img
if %errorlevel% == 0 goto done

:fail
echo Failed to compile image.
pause
goto end

:done
echo Done.

:end
