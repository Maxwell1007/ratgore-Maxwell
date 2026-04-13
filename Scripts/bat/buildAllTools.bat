@echo off
cd ../../

call git submodule sync --recursive
call git submodule update --init --recursive
call dotnet build -c Tools

pause
