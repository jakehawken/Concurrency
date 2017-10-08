platform :ios, '10.0'
inhibit_all_warnings!

target 'Concurrency' do
  use_frameworks!

  pod 'RxSwift'

  target 'ConcurrencyTests' do
    inherit! :search_paths
    pod 'Nimble'
    pod 'Quick'
    pod 'RxSwift'
  end

end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        if target.name == 'Concurrency'
            target.build_configurations.each do |config|
                config.build_settings['SWIFT_VERSION'] = '3.2'
            end
        end
    end
end
