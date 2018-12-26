Pod::Spec.new do |s|
    s.name = 'SwiftNIOMock'
    s.version = '0.0.1'
    s.license = { :type => 'MIT', :file => 'LICENSE' }
    s.summary = 'A web server based on SwiftNIO designed to be used as a mock server in UI automation tests'
    s.homepage = 'https://github.com/ilyapuchka/SwiftNIOMock'
    s.author = 'Ilya Puchka'
    s.source = { :git => 'https://github.com/ilyapuchka/SwiftNIOMock.git', :tag => s.version.to_s }
    s.module_name = 'SwiftNIOMock'
    s.swift_version = '4.2'
    s.cocoapods_version = '>=1.1.0'
    s.ios.deployment_target = '10.0'
    s.osx.deployment_target = '10.10'
    s.tvos.deployment_target = '10.0'
    s.source_files = 'Sources/SwiftNIOMock/**/*.{swift}'
    s.dependency 'SwiftNIO', '~> 1.11.0'
    s.dependency 'SwiftNIOHTTP1', '~> 1.11.0'
end
