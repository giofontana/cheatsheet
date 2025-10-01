
# Install TigerVNC Server on RHEL

Install TigerVNC:
```
sudo dnf update -y
sudo dnf install tigervnc-server -y
```

Add a new user (needs to use a regular user - root doesn't work!)
```
sudo adduser test
sudo echo "test     ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers
sudo su - test
```

Add the following content in the vncserver-config-mandatory
```
sudo vi /etc/tigervnc/vncserver-config-mandatory
session=gnome
securitytypes=vncauth,tlsvnc
geometry=1280x720
```

Get the new user id
```
sudo cat /etc/passwd | grep test
test:x:1001:1001::/home/test:/bin/bash
```

Set the vncserver.users
```
sudo vi /etc/tigervnc/vncserver.users
:1001=test
```

Define new service:
```
sudo cp /usr/lib/systemd/system/vncserver@.service /usr/lib/systemd/system/vncserver@:1001.service
```

Set vncpasswd
```
vncpasswd
```

Start the service
```
sudo systemctl start vncserver@:1001.service
sudo systemctl enable vncserver@:1001.service
```

Check service is running
```
sudo systemctl status vncserver@:1001.service
● vncserver@:1001.service - Remote desktop service (VNC)
     Loaded: loaded (/usr/lib/systemd/system/vncserver@:1001.service; enabled; preset: disabled)
     Active: active (running) since Tue 2025-09-30 16:44:58 EDT; 10s ago
   Main PID: 6966 (vncsession)
      Tasks: 0 (limit: 23544)
     Memory: 1.0M
        CPU: 12ms
     CGroup: /system.slice/system-vncserver.slice/vncserver@:1001.service
             ‣ 6966 /usr/sbin/vncsession test :1001

Sep 30 16:44:58 localhost.localdomain systemd[1]: Starting Remote desktop service (VNC)...
Sep 30 16:44:58 localhost.localdomain systemd[1]: Started Remote desktop service (VNC).
```

Check the port (6901 in the example below)
```
sudo ss -tulpn | grep vnc
tcp   LISTEN 0      5            0.0.0.0:6901      0.0.0.0:*    users:(("Xvnc",pid=8278,fd=6))        
tcp   LISTEN 0      5               [::]:6901         [::]:*    users:(("Xvnc",pid=8278,fd=7))        
```

Connect to the server using your VNC viewer using the password and port above
