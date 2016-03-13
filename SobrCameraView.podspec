Pod::Spec.new do |s|
  s.name             = "SobrCameraView"
  s.version          = "0.2.1"
  s.summary          = "A simple UIView-Subclass which enables border detection of documents."
  s.homepage         = "https://github.com/softwarebrauerei/SobrCameraView-ios"
  s.license          = 'MIT'
  s.authors          = { "Software Brauerei AG" => "contact@software-brauerei.ch"}
  s.source           = { :git => "https://github.com/softwarebrauerei/SobrCameraView-ios.git", :tag => s.version.to_s }

  s.platform     = :ios, '8.0'
  s.ios.deployment_target = '8.0'

  s.source_files = 'SobrCameraView/*.swift'
  s.requires_arc = true
end
