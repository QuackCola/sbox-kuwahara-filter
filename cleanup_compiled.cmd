@echo off
cls
title Deleting Compiled Assets

pushd "Assets"
del /s *.vmdl_c *.vmat_c *.vtex_c *.generated.vtex_c *.vsnd_c *.sound_c *.vpcf_c *.vpost_c *.shader_c
popd

echo.
echo [92m========== Finished! ==========[37m
echo.


title Command Prompt

pause