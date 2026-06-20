# Uncomment this line to define a global platform for your project
# platform :ios

platform :ios, '12.0'
inhibit_all_warnings!
use_frameworks!

def used_pods

# No third-party pods remain — the Swift migration replaced every dependency:
#   AFNetworking → URLSession/APIClient; Reachability → NWPathMonitor;
#   MagicalRecord → native CoreDataStack (+ MagicalRecordShim.swift);
#   OHAlertView/Dejal/IQ*/MFSideMenu/CHCSVParser/Toast/keychains → native equivalents.
# The Podfile is kept (empty) so the workspace stays valid; CocoaPods can be fully
# deintegrated as a final cleanup step.

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
