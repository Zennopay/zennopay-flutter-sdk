require "yaml"

pubspec = YAML.load_file(File.join(__dir__, "..", "pubspec.yaml"))

Pod::Spec.new do |s|
  s.name             = "zennopay_flutter"
  s.version          = pubspec["version"]
  s.summary          = pubspec["description"]
  s.homepage         = pubspec["homepage"]
  s.license          = { :type => "MIT", :file => "../LICENSE" }
  s.authors          = { "Zennopay" => "sdk@zennopay.in" }
  s.source           = { :path => "." }

  s.source_files     = "Classes/**/*"
  s.platform         = :ios, "16.0"
  s.swift_version    = "5.9"

  # The Flutter plugin host.
  s.dependency "Flutter"

  # The native Zennopay iOS SDK that renders the PaymentSheet + receipt and
  # exposes `Zennopay.presentCheckout(...)` / `Zennopay.presentReceipt(...)`.
  # Pulled transitively so partners never add it by hand. Published separately
  # as the `Zennopay` CocoaPod.
  s.dependency "Zennopay", "~> 0.7.0"

  s.pod_target_xcconfig = { "DEFINES_MODULE" => "YES" }
end
