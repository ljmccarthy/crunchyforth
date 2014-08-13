@echo off

echo CrunchyForth by Luke McCarthy
echo Assembling...
nasmw cf.%1%.asm -o cf.img -f bin
if %errorlevel% == 0 goto done

:fail
echo Failed to compile image.
pause
goto end

:done
echo Done.

:end

