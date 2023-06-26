# Configure VNC for RHEL 8

1. Install VNC Server

```bash
sudo yum groupinstall 'Server with GUI'
sudo yum install -y pixman pixman-devel libXfont
sudo yum -y install tigervnc-server
sudo passwd ec2-user
```

2. Configure sshd

```bash
# set the following parameter to YES option and comment with NO option
sudo vi /etc/ssh/sshd_config

PasswordAuthentication yes
ChallengeResponseAuthentication yes

sudo systemctl restart sshd
```

3. Setup the VNC password

```bash
vncpasswd
Password:
Verify:
Would you like to enter a view-only password (y/n)? n
```

4. Start the VNC Server

```bash
vncserver :1
```

5. Connect using a VNC client to <server-public-ip>:5901