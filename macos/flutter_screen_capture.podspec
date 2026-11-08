#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_screen_capture.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_screen_capture'
  s.version          = '1.3.0'
  s.summary          = 'Capture the screen, an area of it, or a single pixel color on macOS.'
  s.description      = <<-DESC
Flutter plugin that captures the entire screen, part of it, or a single
pixel color on macOS using CoreGraphics.
                       DESC
  s.homepage         = 'https://github.com/albemala/flutter_screen_capture'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'flutter_screen_capture contributors' => 'https://github.com/albemala/flutter_screen_capture' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
