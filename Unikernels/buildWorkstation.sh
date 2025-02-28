#!/bin/bash

# Função para criar e processar os arquivos para Nanos
doprocess_nanos() {
    folder=$1
    config=$2
    
    mkdir -p "$folder"
    cd "$folder"
    
    ops build /home/samuel/Desktop/Apps/Nanos/cyclictestV2.7/cyclictest -c "../$config"
    qemu-img convert -f raw -O vmdk /home/samuel/.ops/images/cyclictest "$folder.vmdk"
    ../getVmx.sh --image "$cyclictest.vmdk" --output "$folder"
    
    cd ..
}

doprocess_osv() {
    folder=$1
    interval=$2
    
    mkdir -p "$folder"
    cd "$folder"
    
    echo "/cyclictest -D 4h -v -i $interval -p99" > /home/samuel/Desktop/Unikernels/OSvOld/build/release/append_cmdline
    /home/samuel/Desktop/Unikernels/OSvOld/scripts/build --append-manifest
    /home/samuel/Desktop/Unikernels/OSvOld/scripts/convert vmdk
    /home/samuel/Desktop/Unikernels/OSvOld/scripts/gen-vmx.sh
    
    cp /home/samuel/Desktop/Unikernels/OSvOld/build/release/osv.vmx "../$folder/"
    cp /home/samuel/Desktop/Unikernels/OSvOld/build/release/osv.vmdk "../$folder/"
    
    cd ..
}

# Build Nanos
doprocess_nanos "Nanos10000" "config10000.json"
doprocess_nanos "Nanos1000" "config1000.json"
doprocess_nanos "Nanos100" "config100.json"

/home/samuel/Desktop/Unikernels/OSvOld/scripts/manifest_from_host.sh -w /home/samuel/Desktop/Apps/Nanos/cyclictestV2.7/cyclictest

# Build OSv
doprocess_osv "OSv10000" 10000
doprocess_osv "OSv1000" 1000
doprocess_osv "OSv100" 100
