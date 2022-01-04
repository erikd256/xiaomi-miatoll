#! /bin/bash

set -e

SUPER_INPUT="$1"

DEPENDENCIES="lpunpack lpmake simg2img img2simg wget file resize2fs bc"
for DEP in $DEPENDENCIES
do
    if ! command -v "$DEP" > /dev/null ; then
        echo "The '$DEP' command was not found."
        exit 1
    fi
done

if [ ! -f "${SUPER_INPUT}" ]; then
    echo "The dynamic disk image was not found at '${SUPER_INPUT}'"
    exit 1
fi

if file "${SUPER_INPUT}" | grep 'Android sparse image' > /dev/null; then
    echo "The input image is in sparse format; uncompressing it..."
    SUPER_IMG="${SUPER_INPUT}.unsparse"
    simg2img "${SUPER_INPUT}" "${SUPER_IMG}"
    trap "rm ${SUPER_IMG}" HUP INT TERM QUIT EXIT
else
    echo "The input image is already uncompressed."
    SUPER_IMG="${SUPER_INPUT}"
fi
SUPER_SIZE="$(stat -c '%s' "$SUPER_IMG")"

WORKDIR="$(mktemp -d --tmpdir enable-fm.XXXXXX)"
trap "rm --one-file-system -r $WORKDIR" HUP INT TERM QUIT EXIT
SYSTEM_DIR="${WORKDIR}/system_tree"
VENDOR_DIR="${WORKDIR}/vendor_tree"
mkdir -p "${SYSTEM_DIR}"
mkdir -p "${VENDOR_DIR}"

echo "Unpacking ${SUPER_IMG} in temporary directory ${WORKDIR} ..."
lpunpack "${SUPER_IMG}" "${WORKDIR}"

echo "Making some space in the vendor image..."
fallocate -l 2G "${WORKDIR}/vendor.img"
resize2fs "${WORKDIR}/vendor.img" 2G
e2fsck -yE unshare_blocks "${WORKDIR}/vendor.img" > /dev/null

echo "Mounting the system and vendor images..."
echo "(this uses 'sudo', so you might need to enter your password here)"
sudo mount -t ext4 -o ro,loop "${WORKDIR}/system.img" "${SYSTEM_DIR}"
sudo mount -t ext4 -o loop "${WORKDIR}/vendor.img" "${VENDOR_DIR}"

echo "Copying the needed libraries from the system image into the vendor image..."
sudo cp \
    "${SYSTEM_DIR}/system/lib64/fm_helium.so" \
    "${SYSTEM_DIR}/system/lib64/libfm-hci.so" \
    "${VENDOR_DIR}/lib64"

echo "Downloading the fm-bridge program into the vendor image..."
wget -O "${WORKDIR}/fm-bridge" 'https://gitlab.com/ubuntu-touch-xiaomi-violet/fm-bridge/-/jobs/artifacts/master/raw/libs/arm64-v8a/fm-bridge?job=build_bridge'
chmod a+x "${WORKDIR}/fm-bridge"
sudo cp "${WORKDIR}/fm-bridge" "${VENDOR_DIR}/bin"

echo "Unmounting the images..."
sudo umount "${SYSTEM_DIR}"
sudo umount "${VENDOR_DIR}"

echo "Fixing and resizing vendor image..."
e2fsck -yf "${WORKDIR}/vendor.img" > /dev/null
resize2fs -M "${WORKDIR}/vendor.img"
e2fsck -yf "${WORKDIR}/vendor.img" > /dev/null

echo "Rebuilding super.img"
# The system.img is not used by Ubuntu Touch (it's not even mounted), so we
# could leave it out; but unless we find a way to reuse the space, there's
# little point in doing that
PART_OPTIONS=""
ALL_PART_SIZE="0"
for PART in ${WORKDIR}/{system,product,vendor}.img
do
    NAME="$(basename $PART .img)"
    SIZE="$(stat -c '%s' "$PART")"
    img2simg "$PART" "$PART.sparse"
    mv "$PART.sparse" "$PART"
    PART_OPTIONS="$PART_OPTIONS --partition $NAME:readonly:$SIZE --image $NAME=$PART"
    ALL_PART_SIZE=$(echo "${ALL_PART_SIZE} + ${SIZE}" | bc)
done

lpmake --metadata-size 65536 --super-name super --metadata-slots 1 \
    --device super:$SUPER_SIZE \
    --group qti_dynamic_partitions:$ALL_PART_SIZE \
    $PART_OPTIONS \
    --sparse --output ./super.new.img

