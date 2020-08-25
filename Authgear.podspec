Pod::Spec.new do |s|
  s.name             = 'Authgear'
  s.version          = '0.0.1'
  s.summary          = 'Authgear SDK for iOS'
  s.homepage         = 'https://github.com/Peter-ChengTszTung/authgear-sdk-ios-draft.git'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Peter-ChengTszTung' => 'chengtsztung.peter@gmail.com' }
  s.source           = { :git => 'https://github.com/Peter-ChengTszTung/authgear-sdk-ios-draft.git', :tag => s.version.to_s }
  s.ios.deployment_target = '11.0'
  s.swift_version = ['5.0', '5.1', '5.2']
  s.source_files = 'Source/**/*.swift'
end
