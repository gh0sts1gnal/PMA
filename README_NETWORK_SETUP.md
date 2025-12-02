# REMnux Internal Network Setup Guide

## Overview
This script automatically configures your REMnux VM to work on an isolated internal network (10.99.99.0/24) with your Windows VM.

## Prerequisites

### VirtualBox Configuration
1. **Power off both VMs** before making network changes
2. **For REMnux VM:**
   - Settings → Network → Adapter 1
   - Attached to: **Internal Network**
   - Name: `malnet` (or any name you choose)
   - Click OK

3. **For Windows VM:**
   - Settings → Network → Adapter 1
   - Attached to: **Internal Network**
   - Name: `malnet` (must match REMnux)
   - Click OK

## Installation Steps

**IMPORTANT: Configure Windows VM FIRST, then REMnux!**

This order allows you to test immediately after REMnux setup.

### On Windows VM (Configure First):

1. **Open Network Settings:**
   - Control Panel → Network and Sharing Center
   - Click "Change adapter settings"
   - Right-click your network adapter → Properties

2. **Configure IPv4:**
   - Select "Internet Protocol Version 4 (TCP/IPv4)"
   - Click Properties
   - Select "Use the following IP address"
   - Enter:
     - IP address: `10.99.99.20`
     - Subnet mask: `255.255.255.0`
     - Default gateway: (leave blank - no gateway needed)
     - DNS: (leave blank)
   - Click OK

3. **Verify in Command Prompt:**
   ```cmd
   ipconfig
   ```
   You should see IP address 10.99.99.20

### On REMnux (Configure Second):

1. **Copy the script to your REMnux VM**
   - Download `setup_remnux_network.sh`
   - Place it in your home directory or any location

2. **Make the script executable:**
   ```bash
   chmod +x setup_remnux_network.sh
   ```

3. **Run the script with sudo:**
   ```bash
   sudo ./setup_remnux_network.sh
   ```

4. **The script will:**
   - Detect your network interface automatically
   - Configure NetworkManager to manage the interface
   - Set up Netplan with static IP 10.99.99.10/24
   - Apply all configurations

5. **Verify the configuration:**
   ```bash
   ip addr show
   ```
   You should see `10.99.99.10/24` on your network interface

## Testing Connectivity

### From REMnux:
```bash
ping 10.99.99.20
```

### From Windows:
```cmd
ping 10.99.99.10
```

Both should successfully ping each other!

## Network Details

| VM | IP Address | Subnet Mask | Network |
|---|---|---|---|
| REMnux | 10.99.99.10 | 255.255.255.0 (/24) | 10.99.99.0/24 |
| Windows | 10.99.99.20 | 255.255.255.0 (/24) | 10.99.99.0/24 |

**Note:** There is NO gateway/router in this setup - this is an isolated internal network for direct VM-to-VM communication.

## Troubleshooting

### REMnux side:

**Check interface status:**
```bash
ip addr show
nmcli device status
```

**Check if NetworkManager is managing the interface:**
```bash
nmcli device status
```
Should show "connected" not "unmanaged"

**Manually configure if script fails:**
```bash
sudo ip addr add 10.99.99.10/24 dev enp0s3
sudo ip link set enp0s3 up
```
(Replace `enp0s3` with your actual interface name)

**View netplan configuration:**
```bash
cat /etc/netplan/01-netcfg.yaml
```

**Reapply netplan:**
```bash
sudo netplan apply
```

### Windows side:

**Check IP configuration:**
```cmd
ipconfig
```

**Flush DNS (if needed):**
```cmd
ipconfig /flushdns
```

**Reset network adapter:**
```cmd
ipconfig /release
ipconfig /renew
```

### Both VMs can't communicate:

1. **Verify both VMs are on the same Internal Network:**
   - VirtualBox → VM Settings → Network
   - Both should say "Internal Network" with the same name

2. **Check Windows Firewall:**
   - Windows may block ICMP (ping)
   - Temporarily disable to test:
     - Control Panel → Windows Defender Firewall
     - Turn off (just for testing)

3. **Restart both VMs:**
   - Sometimes a fresh start helps

## Customization

### To change the IP address:

Edit the script before running:
```bash
nano setup_remnux_network.sh
```

Change this line:
```bash
IP_ADDRESS="10.99.99.10"
```

To any IP in the 10.99.99.0/24 range (like 10.99.99.50)

### To use a different network:

Change both:
```bash
IP_ADDRESS="192.168.100.10"
SUBNET_MASK="24"
```

And update your Windows VM accordingly.

## Reverting Changes

If you need to go back to DHCP/NAT:

1. **Change VirtualBox network adapter** back to NAT or Bridged

2. **Edit netplan:**
   ```bash
   sudo nano /etc/netplan/01-netcfg.yaml
   ```

3. **Change to DHCP:**
   ```yaml
   network:
     version: 2
     renderer: NetworkManager
     ethernets:
       enp0s3:
         dhcp4: yes
   ```

4. **Apply:**
   ```bash
   sudo netplan apply
   ```

## Important Notes

- ⚠️ **No Internet Access:** Internal networks are isolated - VMs won't have internet
- ⚠️ **Malware Analysis:** This is perfect for analyzing malware safely
- ⚠️ **Backup:** The script automatically backs up your netplan config
- 💡 **Multiple VMs:** You can add more VMs to this network (10.99.99.11, .12, etc.)

## Support

If you encounter issues:
1. Check that both VMs are on the same Internal Network in VirtualBox
2. Verify the script completed without errors
3. Try the manual configuration commands in the troubleshooting section
4. Restart both VMs

## Lab Scenarios

This isolated network is perfect for:
- Malware analysis (safely contained)
- Network traffic analysis with Wireshark
- Penetration testing practice
- Client-server application testing
- CTF challenges
