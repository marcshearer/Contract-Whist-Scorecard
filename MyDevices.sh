xcrun simctl list | grep 'Custom-' | while read -r line
do
    id=`echo $line | awk '{print substr($2, 2, length($2)-2)}'`
    echo deleting $id
    xcrun simctl delete "${id}"
done

xcrun simctl create Custom-iPhone-7 com.apple.CoreSimulator.SimDeviceType.iPhone-7 com.apple.CoreSimulator.SimRuntime.iOS-12-2
xcrun simctl create Custom-iPhone-SE com.apple.CoreSimulator.SimDeviceType.iPhone-SE com.apple.CoreSimulator.SimRuntime.iOS-12-2
xcrun simctl create Custom-iPhone-Xs com.apple.CoreSimulator.SimDeviceType.iPhone-XS com.apple.CoreSimulator.SimRuntime.iOS-12-2
