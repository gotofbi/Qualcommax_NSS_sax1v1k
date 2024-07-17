#
# This is updated patch the Spectrum SAX1V1K 
# Originally written by MeisterLone (https://github.com/MeisterLone/Askey-RT5010W-D187-REV6/blob/master/Patch/open.sh)
# 1. Removes the requirement of a signed kernel image, enables the bootm command
# 2. Enables TFTP boot
# 3. Initializes network ports in U-Boot (otherwise TFTP boot is impossible)
# 4. Attempts to boot "recovery.img" from 192.168.0.1 via WAN port on every boot
#
#

. /lib/functions.sh

echo "Finding partitions.."
ubootpart=$(find_mmc_part "0:APPSBL")
hlospart=$(find_mmc_part "0:HLOS")
envpart=$(find_mmc_part "0:APPSBLENV")
rootpart=$(find_mmc_part "rootfs")

echo "Printing path locations.."
echo $ubootpart
echo $hlospart
echo $envpart
echo $rootpart

echo "md5 uboot..."
uboot_md5=$(md5sum "$ubootpart" | awk '{ print $1 }')

echo $uboot_md5

# Known MD5 hash values to compare against
hash1="f3066582267c857e24097b4aecd3e9a1"
hash2="ab709449c98f89cfa57e119b0f37b388"
hash3="85ae38d2a62b124f431ba5baba6b42ad"

#verify uboot firmware is as expected
#do not bypass this check or you will brick your device
if [ "$uboot_md5" == "$hash1" ]; then
    echo "Hash matches first known hash! Performing action A."
    fix_uboot="mw 4a910cd0 0a000007 1;mw 4a91dc6c 0a000006 1;setenv loadaddr 44000000;setenv ipaddr 192.168.0.5;setenv serverip 192.168.0.1;go 4a96433c || sleep 3;"
elif [ "$uboot_md5" == "$hash2" ]; then
    echo "Hash matches second known hash! Performing action B."
    fix_uboot="mw 4a911044 0a000007 1;mw 4a91dfdc 0a000006 1;setenv loadaddr 44000000;setenv ipaddr 192.168.0.5;setenv serverip 192.168.0.1;go 4a9647cc || sleep 3;"
elif [ "$uboot_md5" == "$hash3" ]; then
    echo "Hash matches third known hash! Performing action C."
    fix_uboot="mw 4a9115c8 0a000007 1;mw 4a91e534 0a000006 1;setenv loadaddr 44000000;setenv ipaddr 192.168.0.5;setenv serverip 192.168.0.1;go 4a966bc4 || sleep 3;"
else
    echo "Hashes do not match any known hash. dump uboot and submit issue"
    exit 1
fi

echo "Setting up U-Boot environment.."

echo "$envpart 0x0 0x40000 0x40000 1" > /etc/fw_env.config

mmcblk_hlos=$(echo "$hlospart" | sed -e "s/^\/dev\///")
hlos_start=$(cat /sys/class/block/$mmcblk_hlos/start)
hlos_size=$(cat /sys/class/block/$mmcblk_hlos/size)

fw_setenv fix_uboot "$fix_uboot"
fw_setenv read_hlos_emmc "mmc read 44000000 0x8A22 0x4000"
fw_setenv set_custom_bootargs "setenv bootargs console=ttyMSM0,115200n8 mmc_mid=0x15 boot_signedimg mmc_mid=0x15 boot_signedimg mmc_mid=0x15 boot_signedimg root=$rootpart rootwait"
fw_setenv setup_and_boot "run set_custom_bootargs;run fix_uboot; run read_hlos_emmc; bootm"
fw_setenv bootcmd "run fix_uboot; tftpboot recovery.img; bootm || run setup_and_boot"

echo "Done!"

