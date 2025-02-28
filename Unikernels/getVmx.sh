#!/bin/bash

# Initialize variables
image_name=""
output_folder="."

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --image=*)
            # Extract the image name without the path or extension
            image_name=$(basename "${1#--image=}" .vmdk)
            ;;
        --output=*)
            # Extract the output folder path
            output_folder="${1#--output=}"
            ;;
        *)
            # Invalid argument
            echo "Error: Unknown argument '$1'"
            exit 1
            ;;
    esac
    shift
done

# Check if the --image argument was provided
if [[ -z "$image_name" ]]; then
    echo "Usage: $0 --image=image_name.vmdk [--output=folder]"
    exit 1
fi

# Create the output folder if it does not exist
mkdir -p "$output_folder"

# Create the VMX file in the specified output folder
vmx_file="${output_folder}/${image_name}.vmx"
cat <<EOF > "$vmx_file"
.encoding = "windows-1252"
config.version = "8"
virtualHW.version = "8"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"
vmci0.present = "TRUE"
hpet0.present = "TRUE"
nvram = "${image_name}.nvram"
virtualHW.productCompatibility = "hosted"
powerType.powerOff = "soft"
powerType.powerOn = "soft"
powerType.suspend = "soft"
powerType.reset = "soft"
displayName = "${image_name}"
guestOS = "other"
tools.syncTime = "FALSE"
cpuid.coresPerSocket = "1"
memsize = "1024"
ide0:0.fileName = "${image_name}.vmdk"
ide0:0.present = "TRUE"
ethernet0.virtualDev = "vmxnet3"
ethernet0.connectionType = "nat"
ethernet0.addressType = "generated"
ethernet0.present = "TRUE"
extendedConfigFile = "${image_name}.vmxf"
floppy0.present = "FALSE"
EOF

echo "File $vmx_file created successfully."
