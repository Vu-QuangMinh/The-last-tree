@echo off
rem One-time setup after cloning / the first pull that brings Git LFS (wav, pdf, psd go through LFS).
rem Double-click, or run from the project folder. Safe to run again.
cd /d "%~dp0.."
git lfs version >nul 2>&1 || (echo Git LFS is not installed. Get it from https://git-lfs.com then run this file again. & pause & exit /b 1)
git lfs install --local
git lfs pull
echo Done: LFS hooks installed for this repo and LFS files downloaded.
pause
