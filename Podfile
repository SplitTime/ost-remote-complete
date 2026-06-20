# Uncomment this line to define a global platform for your project
# platform :ios

platform :ios, '12.0'
inhibit_all_warnings!
use_frameworks!

def used_pods

# Dropped after the Swift migration (now unused): NSDate+Helper, OHAlertView,
# JTObjectMapping, FXKeychain, Reachability (→ NWPathMonitor), DejalActivityView
# (→ OSTSpinner), SimpleKeychain (session manager uses Security framework).
pod 'MagicalRecord', '2.2'
pod 'MFSideMenu','0.5.5'

end

target 'OST Remote' do
    used_pods
end

target 'OST Remote Dev' do
    used_pods
end

target 'OST TrackerTests' do
    used_pods
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
            # Old pods aren't audited for the modern strict checks Xcode 26 enables.
            config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = 'YES'
        end
    end
end
