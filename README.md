# AMXBPMBackup

Susdpend AMX BPM and backup files

Use cmdline interface to suspend AMX for backup, perform backup file systems and unsuspend

Backup:

Binary home directory

Config directory

Shared config directory

Must be run from the admin machine if there are multiple nodes

amxctrl.cfg                 Contains machines and directories info
remote_props.properties     Contains amx admin connection info

=============================================================================

amxBackup.sh [ options ]

-a          Backup AMX TIBCO Home binaries folder
-c	    Backup TIBCO_CONFIG application folder
-s          Backup BPM Configuration (Shared)
-n          Don not perform a backup

-r          Remove all exisiting backup files
-x          Don not try to get/set AMX suspend status

=============================================================================

