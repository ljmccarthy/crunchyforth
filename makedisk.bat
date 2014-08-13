@echo off

call build.native
echo Writing Disk...
rawrite cf.img a:
if %errorlevel% == 0 goto done

:fail
echo Failed to write the disk.
pause
goto end

:done
echo Done.

:end
