Pod::Spec.new do |s|
  s.name             = 'Authgear'
  s.version          = '0.0.1'
  s.summary          = 'Authgear SDK for iOS'
  s.homepage         = 'https://github.com/authgear/authgear-sdk-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Authgear' => 'hello@authgear.com' }
  s.source           = { :git => 'https://github.com/authgear/authgear-sdk-ios.git', :tag => s.version.to_s }
  s.ios.deployment_target = '11.0'
  s.swift_version = ['5.0', '5.1', '5.2']
  s.source_files = 'Sources/**/*.swift'
end
