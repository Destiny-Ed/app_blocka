#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint app_blocka.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'app_blocka'
  s.version          = '1.0.0'
  s.summary          = 'A Flutter plugin to limit app usage and screen time on iOS.'
  s.description      = <<-DESC
A Flutter plugin to manage app restrictions, including time limits, schedules, and usage tracking on iOS.
                       DESC
  s.homepage         = 'https://github.com/Destiny-Ed/app_blocka'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Destiny Ed' => 'talk2destinyed@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.module_name = 'app_blocka'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'app_blocka_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
