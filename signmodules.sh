#!/bin/bash
secure_crypto_dir="/private/"
if (($EUID != 0)); then
    echo "Must be run with root privs"
    exit
fi
#Getting the sig_key for vmnet
VMNetSigner="$(modinfo -F sig_key vmnet |  tr '[:upper:]' '[:lower:]')"

#Getting the sig_key for vmmon
VMMonSigner="$(modinfo -F sig_key vmmon |  tr '[:upper:]' '[:lower:]')"

#Checking if vmmon key is trusted
mokutil -l | grep -w "$VMMonSigner"
VMMonSigned=$?

#Checking if vmnet key is trusted
mokutil -l | grep -w "$VMNetSigner"
VMNetSigned=$?

#if both are signed by trusted key we are good and can exit
if [ $VMMonSigned -eq 0 ] && [ $VMNetSigned -eq 0 ]; then
    echo "Both modules are signed by a trusted MOK Key"
    echo "Leaving"
    exit
    
fi

#install module if missing
if [[ -z "$VMMonSigner" && -z "$VMNetSigner" ]]; then
    vmware-modconfig --console --install-all
fi


#check if dir exists and create it if not 
if ([ ! -d $secure_crypto_dir ]); then
    mkdir $secure_crypto_dir
    cd $secure_crypto_dir
    #generate certificate (this is lazy and should be fixed to something trustworthy ) 
    openssl req -new -x509 -newkey rsa:2048 -keyout MOK.priv -outform DER -out MOK.der -nodes -days 36500 -subj "/CN=My_MOK"
    mokutil --import MOK.der
fi
#sign the modules
cd $secure_crypto_dir
/usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./MOK.priv ./MOK.der $(modinfo -n vmmon)
/usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./MOK.priv ./MOK.der $(modinfo -n vmnet)
