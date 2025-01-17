Pod::Spec.new do |s|
  s.name             = "AEPAudience"
  s.version          = "0.0.1"
  s.summary          = "AEPAudience"
  s.description      = <<-DESC
AEPCore
                        DESC
  s.homepage         = "https://github.com/adobe/aepsdk-audience-ios"
  s.license          = 'Apache V2'
  s.author       = "Adobe Experience Platform SDK Team"
  s.source           = { :git => "https://github.com/adobe/aepsdk-audience-ios", :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'

  s.swift_version = '5.1'

  s.pod_target_xcconfig = { 'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES' }

  s.dependency 'AEPCore'
  s.dependency 'AEPServices'

  s.source_files          = 'AEPAudience/Sources/*.swift'


end
