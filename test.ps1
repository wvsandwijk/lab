New-ISOFile -source C:\Git\GitHub\Personal\lab\ISO -destinationIso c:\iso\Autounattend_2025.iso -title "Autounattent" -force

New-ISOFile -Source c:\isOBUILD\ -destinationIso c:\iso\w2025-test.iso -bootFile C:\ISOBUILD\efi\microsoft\boot\efisys_noprompt.bin -title Server2025STD -force
New-ISOFile .\BuildIso.ps1 -SourceIsoPath C:\ISO\26100.1.240331-1435.ge_release_SERVER_EVAL_x64FRE_en-us.iso -ISOBuildPath C:\ISOBUILD -DestinationIsoPath C:\ISO\W2025-test.iso -UnattendXmlPath .\ISO\Autounattend.xml -customFilesPath .\ISO\CustomFiles -createISO