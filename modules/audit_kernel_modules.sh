# audit_kernel_modules
#
# VMware provides digital signatures for kernel modules.
# By default the ESXi host does not permit loading of kernel modules that
# lack a valid digital signature. However, this behavior can be overridden
# allowing unauthorized kernel modules to be loaded. Untested or malicious
# kernel modules loaded on the ESXi host can put the host at risk for
# instability and/or exploitation.
#
# Each ESXi host should be monitored for unsigned kernel modules.
# To list all the loaded kernel modules from the ESXi Shell or vCLI run:
#
# "esxcli system module list".
#
# For each module verify the Signed Status field contains a trusted value,
# for example "VMware Signed", by running
#
# "esxcli system module get -m <module>".
#
# Secure the host by disabling  unsigned modules and removing the offending
# VIBs from the host.  Note:  evacuate VMs and place the host into maintenance
# mode before disabling kernel modules.  Note there are known discrepancies
# with unsigned kernel modules in ESXi 5.0u1 and 5.1,
#
# Refer to http://kb.vmware.com/kb/2042473.
#.

audit_kernel_modules () {
  if [ "$os_name" = "VMkernel" ]; then
    funct_verbose_message "Kernel Module Signing"
    for module in `esxcli system module list |grep '^[a-z]' |awk '($3 == "true") {print $1}'`; do
      total=`expr $total + 1`
      backup_file="$work_dir/kernel_module_$module"
      current_value=`esxcli system module get -m $module |grep 'Signed Status' |awk -F': ' '{print $2}'`
      if [ "$audit_mode" != "2" ]; then
        if [ "$current_value" != "VMware Signed" ]; then
          if [ "$audit_more" = "0" ]; then
            if [ "$syslog_server" != "" ]; then
              echo "true" > $backup_file
              esxcli system module set -e false -m $module
            fi
          fi
          if [ "$audit_mode" = "1" ]; then
            insecure=`expr $insecure + 1`
            echo "Warning:   Kernel module $module is not signed by VMware [$insecure Warnings]"
            funct_verbose_message "" fix
            funct_verbose_message "esxcli system module set -e false -m $module" fix
            funct_verbose_message "" fix
          fi
        else
          if [ "$audit_mode" = "1" ]; then
            secure=`expr $secure + 1`
            echo "Secure:    Kernel module $module is signed by VMware [$secure Passes]"
          fi
        fi
      else
        if [ -f "$backup_file" ]; then
          previous_value=`cat $backup_file`
          if [ "$previous_value" = "true" ]; then
            esxcli system module set -e true -m $module
          fi
        fi
      fi
    done
  fi
}
