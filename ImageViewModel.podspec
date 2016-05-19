Pod::Spec.new do |s|

  s.name         = "ImageViewModel"
  s.version      = "0.0.2"
  s.summary      = "RAC-based lightweight ViewModel to handle images via given URL."

  s.description  = <<-DESC
RAC-based µ-ViewModel for managing images represented as URLs. Simplifies routine tasks of laoding images from the nethwork, caching, resizing, post-processing. Written purely in swift.
swift 2.2 compatible  
                 DESC

  s.homepage     = "https://github.com/gavrix/ImageViewModel"
  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author             = { "Sergey Gavrilyuk" => "sergey.gavrilyuk@gmail.com" }
  s.social_media_url   = "http://twitter.com/octogavrix"

  s.platform     = :ios, "8.0"
  s.framework  = "Foundation"

  s.source       = { :git => "https://github.com/gavrix/ImageViewModel.git", :tag => "#{s.version}" }
  s.source_files  = "ImageViewModel/**/*.swift"


  s.dependency "Result", "~> 2.0"
  s.dependency "ReactiveCocoa", "~> 4.1"

end
