#!/bin/bash -e

TARGET_RESOLUTION_PER_SINGLE_PHOTO="60x60"

cd static/team-photos

ALL_PNGS=$(ls *.png | sort -n)

# Resize all images to target resolution TARGET_RESOLUTION_PER_SINGLE_PHOTO
for png in  $ALL_PNGS
do
    echo "resizing $png to $TARGET_RESOLUTION_PER_SINGLE_PHOTO"
    convert $png -resize $TARGET_RESOLUTION_PER_SINGLE_PHOTO $png
done

# Now we create the collage
echo "creating collage"
montage -geometry +0+0 -tile 11x $ALL_PNGS ../team.png

# Optional: monochrome
#convert ../team.png  -colorspace Gray -brightness-contrast 10x5 ../team.png