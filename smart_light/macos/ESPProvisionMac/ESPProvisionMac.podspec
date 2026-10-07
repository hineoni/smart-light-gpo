Pod::Spec.new do |s|
  s.name = 'ESPProvisionMac'
  s.version = '3.0.3'
  s.summary = 'Espressif provisioning core for Smart Light macOS BLE setup'
  s.homepage = 'https://github.com/espressif/esp-idf-provisioning-ios'
  s.license = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author = 'Espressif Systems'
  s.source = { :path => '.' }
  s.platform = :osx, '10.15'
  s.source_files = 'Sources/**/*.swift'
  s.dependency 'SwiftProtobuf', '~> 1.22.0'
  s.swift_version = '5.0'
end
