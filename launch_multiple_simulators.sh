# xcrun simctl shutdown all

project_name="Contract_Whist_Scorecard"
app_name="Contract Whist Scorecard"
bundle_identifier="MarcShearer.Contract-Whist-Scorecard"

path=$(find ~/Library/Developer/Xcode/DerivedData/${project_name}-*/Build/Products/Debug-iphonesimulator -name "${app_name}.app" | head -n 1)

# Boot all devices
xcrun simctl list | grep 'Custom-' | grep -v "(Booted)" | while read -r line
do
    echo "Booting ${line}..."
    id=`echo "${line}" | awk '{print substr($2, 2, length($2)-2)}'`
    xcrun simctl boot "${id}"
done

# Install and launch all devices
export SIMCTL_CHILD_MULTISIM=TRUE
xcrun simctl list | grep 'Custom-' | while read -r line
do
    echo "Launching ${app_name} on ${line}..."
    id=`echo $line | awk '{print substr($2, 2, length($2)-2)}'`
    device=`echo $line | awk '{print $1}'`
    open `xcode-select -p`/Applications/Simulator.app
    xcrun simctl install "${id}" "${path}"
    xcrun simctl launch ${id} ${bundle_identifier}
done
