@echo off
echo -------------------------------------------------
echo - %~nx0
echo -
echo - Allows you to change the RDP port
echo - (Note: RDP default is 3389 0xd3d in hex)
echo -
set rdp_port=3366
echo - Continuing will set it to to %rdp_port%
reg add "hklm\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "PortNumber" /t REG_DWORD /d %rdp_port% /f
echo - Here is the new setting (in hex):
reg query "hklm\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "PortNumber"
echo ---------- Next we will add the port to firewall, then disconnect any running terminal services
echo ---------- You should be able to reconnect using the new port (if you get disconnected)
echo -- Adding to firewall rules ...
netsh advfirewall firewall add rule name="RDP Port for QEMU and KASM %rdp_port%" profile=any protocol=TCP action=allow dir=in localport=%rdp_port%
echo -- Stopping and starting services ...
net stop termservice /yes
net start termservice