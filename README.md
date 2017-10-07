# generate-ipa-manifest
Script which generates special link to allow install custom .ipa file onto iOS device.

This is handy script creates all the required files to allow you install .ipa file into your iOS device. Please note that your device's UDUD must be included in provisioning profile of that .ipa file.

Usage:
1. Generate Access Token in https://www.dropbox.com/developers/apps/ with Permission type of "App Folder"
2. Edit script to replace placeholder with your actual token
3. In terminal run command:

./generate_ipa_manifest_url.sh path/to/ipa

This will generate a link which you should click on your iOS device to install file.
