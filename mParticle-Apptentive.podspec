Pod::Spec.new do |s|
    s.name             = "mParticle-Apptentive"
    s.version          = "7.3.8"
    s.summary          = "Apptentive integration for mParticle"

    s.description      = <<-DESC
                       This is the Apptentive integration for mParticle.
                       DESC

    s.homepage         = "https://www.mparticle.com"
    s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
    s.author           = { "mParticle" => "support@mparticle.com" }
    s.source           = { :git => "https://github.com/mparticle-integrations/mparticle-apple-integration-apptentive.git", :tag => s.version.to_s }
    s.social_media_url = "https://twitter.com/mparticles"

    s.ios.deployment_target = "8.0"
    s.ios.source_files      = 'mParticle-Apptentive/*.{h,m,mm}'
    s.ios.dependency 'mParticle-Apple-SDK/mParticle', '~> 7.3.0'
    s.ios.dependency 'apptentive-ios', '~> 4.0.7'
end
