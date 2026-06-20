# Uncomment this line to define a global platform for your project
# platform :ios

platform :ios, '12.0'
inhibit_all_warnings!
use_frameworks!

def used_pods

pod 'MagicalRecord', '2.2'
pod 'NSDate+Helper', '1.0.0'
pod 'OHAlertView', '3.0.1'
pod 'JTObjectMapping', '1.1.2'
pod 'FXKeychain', '~> 1.5'
pod 'Reachability', '~> 3.2'
pod 'DejalActivityView', '1.2'
pod 'IQDropDownTextField', '1.1.0'
pod 'SimpleKeychain','0.8.0'
pod 'IQKeyboardManager','4.0.10'
pod 'MFSideMenu','0.5.5'
pod 'CHCSVParser','2.1.0'
pod 'Toast', '~> 4.0.0'

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
