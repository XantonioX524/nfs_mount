# Key Features:

1. Connectivity Check: Checks if the host is reachable before attempting to connect
2. Resource Auto-Detect: Runs showmount -e and parses the output
3. Interactive Selection: Allows you to choose which resource to mount from a numbered list
4. Fallback Mount: Attempts a standard mount first, then NFSv3 for compatibility
5. Error Handling: Includes checks and informative error messages
6. Colors: Colored output for better readability
7. Mount Information: Displays details of a successful mount

# Additional Features:

Dependency Check: Checks that showmount, mount, and ping are available
Auto-Cleanup: Automatically unmounts if anything is already mounted in /tmp/nfs_mount
Verbose Information: Displays the available space and contents of the mounted directory
Robust Error Handling: Includes multiple checks and informative messages

# How to use nfs_mount:

**With IP only (default port)**
```
./nfs_mount.sh 10.129.155.148
```

**With custom IP and port**
```
./nfs_mount.sh 10.129.155.148:2049
```
**Without parameters (it will ask for the IP and optionally the port)**
```
./nfs_mount.sh
```

Then you can enter: 10.129.155.148 or 10.129.155.148:2049

![nfs_mount1](https://github.com/user-attachments/assets/706bb458-767e-4521-b87b-bdf51fab6efc)
