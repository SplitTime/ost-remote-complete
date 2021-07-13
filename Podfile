# Uncomment this line to define a global platform for your project
# platform :ios

platform :ios, '9.0'
inhibit_all_warnings!
use_frameworks!

def used_pods

pod 'MagicalRecord', '2.2'
pod 'NSDate+Helper', '1.0.0'
pod 'OHAlertView', '3.0.1'
pod 'AFNetworking'
pod 'JTObjectMapping', '1.1.2'
pod 'Fabric'
pod 'Crashlytics'
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

pre_install do |installer|
    puts 'pre_install begin....'
    dir_af = File.join(installer.sandbox.pod_dir('AFNetworking'), 'UIKit+AFNetworking')
    Dir.foreach(dir_af) {|x|
      real_path = File.join(dir_af, x)
      if (!File.directory?(real_path) && File.exists?(real_path))
        if((x.start_with?('UIWebView') || x == 'UIKit+AFNetworking.h'))
          File.delete(real_path)
          puts 'delete:'+ x
        end
      end
    }
    puts 'end pre_install.'
end
